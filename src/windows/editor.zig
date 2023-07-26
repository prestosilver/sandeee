const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../util/spritebatch.zig");
const tex = @import("../util/texture.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const sp = @import("../drawers/sprite2d.zig");
const c = @import("../c.zig");
const popups = @import("../drawers/popup2d.zig");
const winEvs = @import("../events/window.zig");
const events = @import("../util/events.zig");

const HL_KEYWORD1 = [_][]const u8{ "return ", "var ", "fn ", "for ", "while ", "if ", "else ", "asm " };
const HL_KEYWORD2 = [_][]const u8{"#include "};
const COMMENT_START = "//";
const STRING_START = "\"";

pub const EditorData = struct {
    const Self = @This();

    pub const Row = struct {
        text: []u8,
        render: ?[]const u8 = null,

        pub fn clearRender(self: *Row) void {
            if (self.render) |r| {
                allocator.alloc.free(r);
                self.render = null;
            }
        }

        pub fn getRender(self: *const Row, targIdx: usize) []const u8 {
            var idx: usize = 0;
            var aidx: usize = 0;
            for (self.render.?) |ch| {
                if (ch < 0xf0) {
                    if (idx >= targIdx) break;
                    idx += 1;
                }
                aidx += 1;
            }

            return self.render.?[0..aidx];
        }
    };

    buffer: []Row,
    menubar: sp.Sprite,
    numLeft: sp.Sprite,
    numRight: sp.Sprite,
    icons: [2]sp.Sprite,
    shader: *shd.Shader,

    clickPos: ?vecs.Vector2 = null,
    cursorx: usize = 0,
    cursory: usize = 0,
    // TODO: implement
    curosrLen: usize = 0,
    linex: usize = 0,

    modified: bool = false,
    file: ?*files.File = null,

    pub fn hlLine(rawLine: []const u8) ![]const u8 {
        var line = try allocator.alloc.dupe(u8, rawLine);

        if (line.len == 0) return line;

        for (HL_KEYWORD1) |keyword| {
            const comment = std.mem.indexOf(u8, line, COMMENT_START) orelse line.len;

            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                &.{0xFE},
                keyword,
                &.{0xF8},
            });
            defer allocator.alloc.free(replacement);

            const oldLine = line;
            defer allocator.alloc.free(oldLine);

            const repSize = std.mem.replacementSize(u8, line[0..comment], keyword, replacement);

            line = try allocator.alloc.alloc(u8, repSize + (line.len - comment));
            _ = std.mem.replace(u8, oldLine[0..comment], keyword, replacement, line);
            @memcpy(line[repSize..], oldLine[comment..]);
        }

        for (HL_KEYWORD2) |keyword| {
            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                &.{0xF5},
                keyword,
                &.{0xF8},
            });
            defer allocator.alloc.free(replacement);

            const oldLine = line;
            defer allocator.alloc.free(oldLine);

            line = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, line, keyword, replacement));
            _ = std.mem.replace(u8, oldLine, keyword, replacement, line);
        }

        {
            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                &.{0xF1},
                COMMENT_START,
            });
            defer allocator.alloc.free(replacement);

            const oldLine = line;
            defer allocator.alloc.free(oldLine);

            line = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, line, COMMENT_START, replacement));
            _ = std.mem.replace(u8, oldLine, COMMENT_START, replacement, line);
        }

        {
            // TODO: spaces???

            const oldLine = line;
            defer allocator.alloc.free(oldLine);

            const count = std.mem.count(u8, line, STRING_START);

            line = try allocator.alloc.alloc(u8, line.len + count);

            var idx: usize = 0;
            var inString = false;

            for (oldLine) |ch| {
                if (ch == STRING_START[0] and !inString) {
                    inString = !inString;
                    line[idx] = '\xf4';
                    idx = idx + 1;
                    line[idx] = ch;
                    idx = idx + 1;
                    continue;
                }
                line[idx] = ch;
                idx = idx + 1;
                if (ch == STRING_START[0] and inString) {
                    inString = !inString;
                    line[idx] = '\xf8';
                    idx = idx + 1;
                }
            }
        }

        return line;
    }

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 40,
            };
        }

        if (self.file) |file| {
            const idx = std.mem.lastIndexOf(u8, file.name, "/") orelse 0;
            const title = try std.fmt.allocPrint(allocator.alloc, "\x82\x82\x82DT-{s}{s}", .{ file.name[idx + 1 ..], if (self.modified) "*" else "" });
            defer allocator.alloc.free(title);

            try props.setTitle(title);
        }

        self.menubar.data.size.x = bnds.w;

        self.numLeft.data.size.y = bnds.h - 40;
        self.numRight.data.size.y = bnds.h - 40;

        // draw number sidebar
        try batch.draw(sp.Sprite, &self.numLeft, self.shader, vecs.newVec3(bnds.x, bnds.y + 40, 0));

        // draw number sidebar
        try batch.draw(sp.Sprite, &self.numRight, self.shader, vecs.newVec3(bnds.x + 40, bnds.y + 40, 0));

        // draw file text
        if (self.file != null) {
            if (self.clickPos) |clickPos| {
                self.cursory = @as(usize, @intFromFloat((clickPos.y + props.scroll.?.value) / font.size));
                self.cursorx = @as(usize, @intFromFloat(clickPos.x / font.chars[0].ax));
                self.clickPos = null;
            }

            if (self.cursory >= self.buffer.len) {
                self.cursory = self.buffer.len - 1;
            }

            if (self.cursorx >= self.buffer[self.cursory].text.len) {
                self.cursorx = self.buffer[self.cursory].text.len;
            }

            // draw lines
            var y = bnds.y + 40 - props.scroll.?.value;

            props.scroll.?.maxy = -bnds.h + 40;

            for (self.buffer, 0..) |*line, lineidx| {
                if (line.render == null) {
                    line.render = try hlLine(line.text);
                }
                try font.draw(.{
                    .batch = batch,
                    .shader = shader,
                    .text = line.render.?,
                    .pos = vecs.newVec2(bnds.x + 82, y),
                    .wrap = bnds.w - 82,
                    .maxlines = 1,
                });

                const linenr = try std.fmt.allocPrint(allocator.alloc, "{}", .{lineidx + 1});
                defer allocator.alloc.free(linenr);
                try font.draw(.{
                    .batch = batch,
                    .shader = shader,
                    .text = linenr,
                    .pos = vecs.newVec2(bnds.x + 6, y),
                });

                if (self.cursory == lineidx) {
                    const posx = font.sizeText(.{
                        .text = line.getRender(self.cursorx),
                        .cursor = true,
                    }).x;
                    try font.draw(.{
                        .batch = batch,
                        .shader = shader,
                        .text = "|",
                        .pos = vecs.newVec2(bnds.x + 82 + posx - 6, y),
                    });
                }

                y += font.size;
                props.scroll.?.maxy += font.size;
            }
        }

        // draw toolbar
        try batch.draw(sp.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        // draw toolbar icons
        try batch.draw(sp.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 38, bnds.y + 4, 0));
        try batch.draw(sp.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x + 2, bnds.y + 4, 0));
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (btn == null) return;

        switch (btn.?) {
            0 => {
                const open = rect.newRect(0, 0, 32, 32);
                if (open.contains(mousepos)) {
                    const adds = try allocator.alloc.create(popups.all.filepick.PopupFilePick);
                    adds.* = .{
                        .path = try allocator.alloc.dupe(u8, files.home.name),
                        .data = self,
                        .submit = &submit,
                    };

                    try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
                        .popup = .{
                            .texture = "win",
                            .data = .{
                                .title = "File Picker",
                                .source = rect.newRect(0, 0, 1, 1),
                                .size = vecs.newVec2(350, 125),
                                .parentPos = undefined,
                                .contents = popups.PopupData.PopupContents.init(adds),
                            },
                        },
                    });
                }

                const saveBnds = rect.newRect(32, 0, 32, 32);
                if (saveBnds.contains(mousepos)) {
                    try self.save();
                }
                if (self.buffer.len != 0) {
                    if (mousepos.y > 40 and mousepos.x > 82) {
                        self.clickPos = mousepos.sub(.{
                            .y = 40,
                            .x = 82,
                        });
                    }
                }
            },
            else => {},
        }

        return;
    }

    pub fn save(self: *Self) !void {
        if (self.file != null) {
            var buff = std.ArrayList(u8).init(allocator.alloc);
            defer buff.deinit();

            for (self.buffer) |line| {
                try buff.appendSlice(line.text);
                try buff.append('\n');
            }

            _ = buff.pop();

            try self.file.?.write(try allocator.alloc.dupe(u8, buff.items), null);
            self.modified = false;
        }
    }

    pub fn submit(file: ?*files.File, data: *anyopaque) !void {
        if (file) |target| {
            const self: *Self = @ptrCast(@alignCast(data));
            self.file = target;

            const fileConts = try self.file.?.read(null);
            const lines = std.mem.count(u8, fileConts, "\n") + 1;

            self.buffer = try allocator.alloc.realloc(self.buffer, lines);

            var iter = std.mem.split(u8, fileConts, "\n");
            var idx: usize = 0;
            while (iter.next()) |line| {
                self.buffer[idx] = .{
                    .text = try allocator.alloc.dupe(u8, line),
                    .render = null,
                };

                idx += 1;
            }
        }
    }

    pub fn move(_: *Self, _: f32, _: f32) !void {}

    pub fn focus(self: *Self) !void {
        if (!self.modified and self.file != null) {
            try submit(self.file, self);

            return;
        }
    }

    pub fn deinit(self: *Self) !void {
        for (self.buffer) |*line| {
            line.clearRender();
            allocator.alloc.free(line.text);
        }

        allocator.alloc.free(self.buffer);
        allocator.alloc.destroy(self);
    }

    pub fn char(self: *Self, code: u32, _: i32) !void {
        if (code == '\n') return;

        const line = &self.buffer[self.cursory];

        line.text = try allocator.alloc.realloc(line.text, line.text.len + 1);

        std.mem.copyBackwards(u8, line.text[self.cursorx + 1 ..], line.text[self.cursorx .. line.text.len - 1]);
        line.text[self.cursorx] = @intCast(code);

        line.clearRender();

        self.cursorx += 1;
        self.modified = true;
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        if (self.file == null) return;
        if (!down) return;

        switch (keycode) {
            c.GLFW_KEY_S => {
                if (mods == (c.GLFW_MOD_CONTROL)) {
                    try self.save();

                    return;
                }
            },
            c.GLFW_KEY_TAB => {
                try self.char(' ', mods);
                try self.char(' ', mods);
            },
            c.GLFW_KEY_ENTER => {
                self.buffer = try allocator.alloc.realloc(self.buffer, self.buffer.len + 1);
                std.mem.copyBackwards(Row, self.buffer[self.cursory + 1 ..], self.buffer[self.cursory .. self.buffer.len - 1]);

                const line = &self.buffer[self.cursory];
                self.buffer[self.cursory + 1] = .{
                    .text = try allocator.alloc.dupe(u8, line.text[self.cursorx..]),
                };

                line.text = try allocator.alloc.realloc(line.text, self.cursorx);

                line.clearRender();

                self.cursorx = 0;
                self.cursory += 1;

                self.modified = true;
            },
            c.GLFW_KEY_DELETE => {
                const line = &self.buffer[self.cursory];

                if (self.cursorx < line.text.len) {
                    std.mem.copyForwards(u8, line.text[self.cursorx .. line.text.len - 1], line.text[self.cursorx + 1 ..]);
                    line.text = try allocator.alloc.realloc(line.text, line.text.len - 1);

                    line.clearRender();

                    self.modified = true;
                }
            },
            c.GLFW_KEY_BACKSPACE => {
                if (self.cursorx > 0) {
                    const line = &self.buffer[self.cursory];

                    std.mem.copyForwards(u8, line.text[self.cursorx - 1 .. line.text.len - 1], line.text[self.cursorx..]);
                    line.text = try allocator.alloc.realloc(line.text, line.text.len - 1);

                    line.clearRender();

                    self.modified = true;

                    self.cursorx -= 1;
                } else if (self.cursory > 0) {
                    const oldLine = self.buffer[self.cursory - 1].text;
                    defer allocator.alloc.free(oldLine);

                    self.buffer[self.cursory - 1].text = try std.mem.concat(allocator.alloc, u8, &.{
                        self.buffer[self.cursory - 1].text,
                        self.buffer[self.cursory].text,
                    });
                    std.mem.copyForwards(Row, self.buffer[self.cursory .. self.buffer.len - 1], self.buffer[self.cursory + 1 ..]);

                    self.buffer[self.cursory - 1].clearRender();

                    self.buffer = try allocator.alloc.realloc(self.buffer, self.buffer.len - 1);
                    self.cursorx = oldLine.len;
                    self.cursory -= 1;
                }
            },
            c.GLFW_KEY_LEFT => {
                if (self.cursorx > 0)
                    self.cursorx -= 1;
            },
            c.GLFW_KEY_RIGHT => {
                if (self.cursorx < self.buffer[self.cursory].text.len)
                    self.cursorx += 1;
            },
            c.GLFW_KEY_UP => {
                if (self.cursory > 0)
                    self.cursory -= 1;
            },
            c.GLFW_KEY_DOWN => {
                if (self.cursory < self.buffer.len - 1)
                    self.cursory += 1;
            },
            else => {},
        }
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}
    pub fn moveResize(_: *Self, _: *rect.Rectangle) !void {}
};

pub fn new(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(EditorData);

    self.* = .{
        .menubar = sp.Sprite.new("ui", sp.SpriteData.new(
            rect.newRect(4.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 4.0 / 8.0),
            vecs.newVec2(0, 40.0),
        )),
        .numLeft = sp.Sprite.new("ui", sp.SpriteData.new(
            rect.newRect(4.0 / 8.0, 4.0 / 8.0, 2.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(40, 0),
        )),
        .numRight = sp.Sprite.new("ui", sp.SpriteData.new(
            rect.newRect(4.0 / 8.0, 4.0 / 8.0, 4.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(40, 0),
        )),
        .icons = .{
            sp.Sprite.new("icons", sp.SpriteData.new(
                rect.newRect(0, 0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(32, 32),
            )),
            sp.Sprite.new("icons", sp.SpriteData.new(
                rect.newRect(1.0 / 8.0, 0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(32, 32),
            )),
        },
        .shader = shader,
        .buffer = try allocator.alloc.alloc(EditorData.Row, 0),
    };

    return win.WindowContents.init(self, "editor", "\x82\x82\x82DT", col.newColor(1, 1, 1, 1));
}
