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

const HL_KEYWORD1 = [_][]const u8{ "return ", "var ", "fn ", "for ", "while ", "if ", "else " };
const HL_KEYWORD2 = [_][]const u8{"#include"};
const COMMENT_START = "//";
const STRING_START = "\"";

pub const EditorData = struct {
    const Self = @This();

    buffer: std.ArrayList(u8),
    menubar: sp.Sprite,
    numLeft: sp.Sprite,
    numRight: sp.Sprite,
    icons: [2]sp.Sprite,
    shader: *shd.Shader,

    cursor: vecs.Vector2 = .{ .x = 0, .y = 0 },
    clickPos: ?vecs.Vector2 = null,
    cursorIdx: usize = 0,
    prevIdx: usize = 0,
    modified: bool = false,
    file: ?*files.File = null,

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
            if (self.clickPos) |clicked| {
                self.cursor.y = @divFloor(clicked.y - 40 + props.scroll.?.value, font.size);
                self.cursor.x = @round((clicked.x - 82) / font.sizeText(.{
                    .text = "A",
                }).x);
                self.clickPos = null;
            }

            // draw lines
            var y = bnds.y + 40 - props.scroll.?.value;
            var nr: usize = 1;

            if (self.cursor.x < 0) self.cursor.x = 0;
            self.cursorIdx = @as(usize, @intFromFloat(self.cursor.x));
            self.prevIdx = 0;

            props.scroll.?.maxy = -bnds.h + 40;

            var splitIter = std.mem.split(u8, self.buffer.items, "\n");

            while (splitIter.next()) |rawLine| {
                var line = try allocator.alloc.dupe(u8, rawLine);
                defer allocator.alloc.free(line);

                if (line.len != 0) {
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
                }

                if (nr - 1 < @as(usize, @intFromFloat(self.cursor.y))) {
                    self.cursorIdx += rawLine.len + 1;
                    self.prevIdx += rawLine.len + 1;
                }

                if (nr - 1 == @as(usize, @intFromFloat(self.cursor.y))) {
                    self.cursor.x = @min(self.cursor.x, @as(f32, @floatFromInt(rawLine.len)));
                }

                if (y > bnds.y - font.size and y < bnds.y + bnds.h) {
                    try font.draw(.{
                        .batch = batch,
                        .shader = shader,
                        .text = line,
                        .pos = vecs.newVec2(bnds.x + 82, y),
                    });
                    const linenr = try std.fmt.allocPrint(allocator.alloc, "{}", .{nr});
                    defer allocator.alloc.free(linenr);
                    try font.draw(.{
                        .batch = batch,
                        .shader = shader,
                        .text = linenr,
                        .pos = vecs.newVec2(bnds.x + 6, y),
                    });

                    if (nr - 1 == @as(i32, @intFromFloat(self.cursor.y))) {
                        const posx = font.sizeText(.{
                            .text = rawLine[0..@as(usize, @intFromFloat(self.cursor.x))],
                        }).x;
                        try font.draw(.{
                            .batch = batch,
                            .shader = shader,
                            .text = "|",
                            .pos = vecs.newVec2(bnds.x + 82 + posx - 6, y),
                        });
                    }
                }

                y += font.size;
                props.scroll.?.maxy += font.size;

                nr += 1;
            }

            if (self.cursor.y > @as(f32, @floatFromInt(nr - 2))) {
                self.cursor.y = @as(f32, @floatFromInt(nr - 2));
            }
        }

        if (self.cursorIdx > self.buffer.items.len) self.cursorIdx = self.buffer.items.len - 1;

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
                if (self.buffer.items.len != 0) {
                    if (mousepos.y > 32) {
                        self.clickPos = mousepos;
                    }
                }
            },
            else => {},
        }

        return;
    }

    pub fn save(self: *Self) !void {
        if (self.file != null) {
            allocator.alloc.free(self.file.?.contents);
            const buff = try allocator.alloc.alloc(u8, self.buffer.items.len);
            std.mem.copy(u8, buff, self.buffer.items);
            self.file.?.contents = buff;
            self.modified = false;
        }
    }

    pub fn submit(file: ?*files.File, data: *anyopaque) !void {
        if (file) |target| {
            const self: *Self = @ptrCast(@alignCast(data));
            self.file = target;

            self.buffer.clearAndFree();
            try self.buffer.appendSlice(try self.file.?.read(null));
        }
    }

    pub fn move(_: *Self, _: f32, _: f32) !void {}

    pub fn focus(self: *Self) !void {
        if (!self.modified and self.file != null) {
            self.buffer.clearAndFree();
            try self.buffer.appendSlice(try self.file.?.read(null));

            return;
        }
    }

    pub fn deinit(self: *Self) !void {
        self.buffer.deinit();
        allocator.alloc.destroy(self);
    }

    pub fn char(self: *Self, code: u32, _: i32) !void {
        if (code == '\n') return;

        try self.buffer.insert(self.cursorIdx, @as(u8, @intCast(code)));
        self.cursor.x += 1;
        self.modified = true;
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        if (self.file == null) return;
        if (!down) return;

        switch (keycode) {
            c.GLFW_KEY_S => {
                if ((mods & c.GLFW_MOD_CONTROL) != 0) {
                    try self.save();

                    return;
                }
            },
            c.GLFW_KEY_TAB => {
                try self.buffer.insertSlice(self.cursorIdx, "  ");
                self.cursor.x += 2;
                self.modified = true;
            },
            c.GLFW_KEY_ENTER => {
                try self.buffer.insert(self.cursorIdx, '\n');
                self.cursor.x = 0;
                self.cursor.y += 1;
                self.modified = true;
            },
            c.GLFW_KEY_DELETE => {
                if (self.cursorIdx < self.buffer.items.len) {
                    _ = self.buffer.orderedRemove(self.cursorIdx);
                }
                self.modified = true;
            },
            c.GLFW_KEY_BACKSPACE => {
                if (self.cursorIdx > 0) {
                    const ch = self.buffer.orderedRemove(self.cursorIdx - 1);
                    self.cursor.x -= 1;
                    if (ch == '\n') {
                        self.cursor.y -= 1;
                        self.cursor.x = @as(f32, @floatFromInt(self.prevIdx - 1));
                    }
                }
                self.modified = true;
            },
            c.GLFW_KEY_LEFT => {
                self.cursor.x -= 1;
                if (self.cursor.x < 0) self.cursor.x = 0;
            },
            c.GLFW_KEY_RIGHT => {
                self.cursor.x += 1;
            },
            c.GLFW_KEY_UP => {
                self.cursor.y -= 1;
                if (self.cursor.y < 0) self.cursor.y = 0;
            },
            c.GLFW_KEY_DOWN => {
                self.cursor.y += 1;
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
        .buffer = std.ArrayList(u8).init(allocator.alloc),
    };

    return win.WindowContents.init(self, "editor", "\x82\x82\x82DT", col.newColor(1, 1, 1, 1));
}
