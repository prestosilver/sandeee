const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const batch = @import("../util/spritebatch.zig");
const tex = @import("../util/texture.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const sp = @import("../drawers/sprite2d.zig");
const c = @import("../c.zig");
const popups = @import("../drawers/popup2d.zig");
const winEvs = @import("../events/window.zig");
const systemEvs = @import("../events/system.zig");
const events = @import("../util/events.zig");

const HL_KEYWORD1 = [_][]const u8{ "return ", "var ", "fn ", "for ", "while ", "if ", "else ", "asm " };
const HL_KEYWORD2 = [_][]const u8{"#include "};
const COMMENT_START = "//";
const STRING_START = '\"';
const ESCAPE_CHAR = '\\';
const STRING_ERROR = fnt.COLOR_BLACK ++ fnt.LEFT;

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

    buffer: ?[]Row = null,
    menubar: sp.Sprite,
    numLeft: sp.Sprite,
    numRight: sp.Sprite,
    sel: sp.Sprite,
    icons: [3]sp.Sprite,
    shader: *shd.Shader,

    clickPos: ?vecs.Vector2 = null,
    clickDone: ?vecs.Vector2 = null,
    clickDown: bool = false,

    cursorx: usize = 0,
    cursory: usize = 0,
    cursor_len: i32 = 0,
    linex: usize = 0,

    modified: bool = false,
    file: ?*files.File = null,
    bnds: rect.Rectangle = undefined,

    pub fn hlLine(rawLine: []const u8) ![]const u8 {
        var line = try allocator.alloc.dupe(u8, rawLine);

        if (line.len == 0) return line;

        for (line) |*ch| {
            if (ch.* >= 0xF0) {
                ch.* = 0x8F;
            }
        }

        for (HL_KEYWORD1) |keyword| {
            const comment = std.mem.indexOf(u8, line, COMMENT_START) orelse line.len;

            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                fnt.COLOR_BLUE,
                keyword,
                fnt.COLOR_BLACK,
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
                fnt.COLOR_DARK_CYAN,
                keyword,
                fnt.COLOR_BLACK,
            });
            defer allocator.alloc.free(replacement);

            const oldLine = line;
            defer allocator.alloc.free(oldLine);

            line = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, line, keyword, replacement));
            _ = std.mem.replace(u8, oldLine, keyword, replacement, line);
        }

        {
            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                fnt.COLOR_WHITE,
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

            var count: usize = 0;

            {
                var inString = false;

                for (oldLine, 0..) |ch, idx| {
                    if (ch == STRING_START) {
                        if (inString) {
                            if (oldLine[idx - 1] == ESCAPE_CHAR)
                                continue;

                            inString = !inString;
                            count += 1;
                        }
                    }
                }

                if (inString) {
                    count += STRING_ERROR.len;
                }

                line = try allocator.alloc.alloc(u8, line.len + count);

                if (inString) {
                    @memcpy(
                        line[line.len - STRING_ERROR.len .. line.len],
                        STRING_ERROR,
                    );
                }
            }

            var idx: usize = 0;
            var inString = false;

            for (oldLine) |ch| {
                if (ch == STRING_START and !inString) {
                    inString = !inString;
                    line[idx] = fnt.COLOR_DARK_GREEN[0];
                    idx = idx + 1;
                    line[idx] = ch;
                    idx = idx + 1;
                    continue;
                }
                line[idx] = ch;
                idx = idx + 1;
                if (ch == STRING_START and inString) {
                    inString = !inString;
                    line[idx] = fnt.COLOR_BLACK[0];
                    idx = idx + 1;
                }
            }
        }

        return line;
    }

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 40,
            };
        }

        self.bnds = bnds.*;

        const charSize = font.sizeText(.{
            .text = "A",
        }).x;

        if (self.buffer) |_| {
            const file_name = if (self.file) |file| file.name else "[New File]";

            const idx = if (std.mem.lastIndexOf(u8, file_name, "/")) |idx| idx + 1 else 0;
            const title = try std.fmt.allocPrint(allocator.alloc, fnt.EEE ++ "DT-{s}{s}", .{ file_name[idx..], if (self.modified) "*" else "" });
            defer allocator.alloc.free(title);

            try props.setTitle(title);
        }

        self.menubar.data.size.x = bnds.w;

        self.numLeft.data.size.y = bnds.h - 40;
        self.numRight.data.size.y = bnds.h - 40;

        // draw number sidebar
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.numLeft, self.shader, vecs.newVec3(bnds.x, bnds.y + 40, 0));

        // draw number sidebar
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.numRight, self.shader, vecs.newVec3(bnds.x + 40, bnds.y + 40, 0));

        // draw file text
        if (self.buffer) |buffer| {
            if (self.clickDone) |clickDone| blk: {
                defer self.clickDone = null;

                if (clickDone.x > bnds.w) break :blk;
                if (clickDone.y - props.scroll.?.value > bnds.h) break :blk;
                if (clickDone.x < 0) break :blk;
                if (clickDone.y - props.scroll.?.value < 0) break :blk;

                const clickPos = self.clickPos.?;

                const doneBig = if (@abs(@round(clickPos.y / font.size) - @round((clickDone.y - props.scroll.?.value) / font.size)) < 1)
                    @round(clickPos.x / charSize) < @round(clickDone.x / charSize)
                else
                    @round(clickPos.y / font.size) < @round((clickDone.y - props.scroll.?.value) / font.size);

                const start = if (doneBig) clickPos else clickDone.sub(.{ .x = 0, .y = props.scroll.?.value });
                const end = if (doneBig) clickDone.sub(.{ .x = 0, .y = props.scroll.?.value }) else clickPos;

                self.cursory = @as(usize, @intFromFloat((start.y + props.scroll.?.value) / font.size));
                self.cursorx = @as(usize, @intFromFloat(start.x / font.chars[0].ax));

                if (self.cursory >= buffer.len) {
                    self.cursory = buffer.len - 1;
                }

                if (self.cursorx >= buffer[self.cursory].text.len) {
                    self.cursorx = buffer[self.cursory].text.len;
                }

                const endy = @min(@as(usize, @intFromFloat((end.y + props.scroll.?.value) / font.size)), buffer.len - 1);
                const endx = @as(usize, @intFromFloat(end.x / font.chars[0].ax));

                self.cursor_len = 0;
                if (self.cursorx != endx or self.cursory != endy) {
                    for (buffer[self.cursory .. endy + 1], self.cursory..endy + 1) |line, y| {
                        for (0..line.text.len) |x| {
                            if (!((y == self.cursory and x < self.cursorx) or
                                y == endy and x > endx))
                            {
                                self.cursor_len += 1;
                            }
                        }
                        if (y > self.cursory and y < endy)
                            self.cursor_len += 1;
                    }
                }

                if (doneBig) {
                    self.cursor_len *= -1;
                }
            }

            if (self.cursory >= buffer.len) {
                self.cursory = buffer.len - 1;
            }

            if (self.cursorx >= buffer[self.cursory].text.len) {
                self.cursorx = buffer[self.cursory].text.len;
            }

            // draw lines
            var y = bnds.y + 40 - props.scroll.?.value;

            props.scroll.?.maxy = -bnds.h + 40;

            var selRemaining: usize = @intCast(@abs(self.cursor_len));

            for (buffer, 0..) |*line, lineidx| {
                if (line.render == null) {
                    line.render = try hlLine(line.text);
                }
                try font.draw(.{
                    .shader = shader,
                    .text = line.render.?,
                    .pos = vecs.newVec2(bnds.x + 82, y),
                    .wrap = bnds.w - 82,
                    .maxlines = 1,
                });

                const linenr = try std.fmt.allocPrint(allocator.alloc, "{}", .{lineidx + 1});
                defer allocator.alloc.free(linenr);
                try font.draw(.{
                    .shader = shader,
                    .text = linenr,
                    .pos = vecs.newVec2(bnds.x + 6, y),
                });

                if (self.cursory == lineidx) {
                    const posx = font.sizeText(.{
                        .text = line.getRender(self.cursorx),
                        .cursor = true,
                    }).x;

                    const width = @min(selRemaining, line.text.len - self.cursorx + 1);

                    self.sel.data.size.x = charSize * @as(f32, @floatFromInt(width));
                    self.sel.data.size.y = font.size;

                    selRemaining -= width;

                    try batch.SpriteBatch.instance.draw(sp.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x + 82 + posx, y, 0));

                    if (self.cursor_len >= 0) {
                        try font.draw(.{
                            .shader = shader,
                            .text = "|",
                            .pos = vecs.newVec2(bnds.x + 82 + posx - 6, y),
                        });
                    }
                } else if (selRemaining > 0 and self.cursory < lineidx) {
                    const width = @min(selRemaining, line.text.len + 1);
                    self.sel.data.size.x = charSize * @as(f32, @floatFromInt(width));
                    self.sel.data.size.y = font.size;

                    selRemaining -= width;

                    try batch.SpriteBatch.instance.draw(sp.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x + 82, y, 0));
                    if (self.cursor_len < 0 and selRemaining == 0) {
                        const posx = font.sizeText(.{
                            .text = line.getRender(width),
                            .cursor = true,
                        }).x;

                        try font.draw(.{
                            .shader = shader,
                            .text = "|",
                            .pos = vecs.newVec2(bnds.x + 82 + posx - 6, y),
                        });
                    }
                }

                y += font.size;
                props.scroll.?.maxy += font.size;
            }
        }

        // draw toolbar
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        // draw toolbar icons
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 2, bnds.y + 4, 0));
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x + 38, bnds.y + 4, 0));
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.icons[2], self.shader, vecs.newVec3(bnds.x + 74, bnds.y + 4, 0));
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        self.clickDown = self.clickDown and btn != null;

        if (btn == null) return;

        switch (btn.?) {
            0 => {
                const open = rect.newRect(0, 0, 36, 36);
                if (open.contains(mousepos)) {
                    const adds = try allocator.alloc.create(popups.all.filepick.PopupFilePick);
                    adds.* = .{
                        .path = try allocator.alloc.dupe(u8, files.home.name),
                        .data = self,
                        .submit = &submitOpen,
                    };

                    try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
                        .popup = .{
                            .texture = "win",
                            .data = .{
                                .title = "Open",
                                .source = rect.newRect(0, 0, 1, 1),
                                .pos = rect.newRectCentered(self.bnds, 350, 125),
                                .contents = popups.PopupData.PopupContents.init(adds),
                            },
                        },
                    });
                }

                const saveBnds = rect.newRect(36, 0, 36, 36);
                if (saveBnds.contains(mousepos)) {
                    try self.save();
                }

                const newBnds = rect.newRect(72, 0, 36, 36);
                if (newBnds.contains(mousepos)) {
                    try self.newFile();
                }

                if (self.buffer != null and self.buffer.?.len != 0) {
                    if (mousepos.y > 40 and mousepos.x > 82) {
                        self.clickPos = mousepos.sub(.{
                            .y = 40,
                            .x = 82,
                        });
                        self.clickDone = self.clickPos;
                        self.clickDown = true;
                    }
                }
            },
            else => {},
        }

        return;
    }

    pub fn deleteSel(self: *Self) !void {
        if (self.cursor_len == 0) return;

        var idx: usize = 0;

        if (self.buffer) |buffer| {
            var new_buffer = std.ArrayList(Row).init(allocator.alloc);
            defer new_buffer.deinit();

            const abs_sel: usize = @intCast(@abs(self.cursor_len));

            for (buffer[self.cursory..]) |line| {
                var new_line = Row{
                    .text = try allocator.alloc.alloc(u8, 0),
                };

                for (line.text) |ch| {
                    if (!(idx >= self.cursorx and idx < self.cursorx + abs_sel)) {
                        new_line.text = try allocator.alloc.realloc(new_line.text, new_line.text.len + 1);
                        new_line.text[new_line.text.len - 1] = ch;
                    }
                    idx += 1;
                }

                // new line
                idx += 1;

                if ((!(idx >= self.cursorx and idx < self.cursorx + abs_sel)) or new_line.text.len != 0) {
                    try new_buffer.append(new_line);
                } else {
                    allocator.alloc.free(new_line.text);
                }
            }

            try self.clearBuffer();

            if (self.buffer) |_| {
                self.buffer = try allocator.alloc.realloc(self.buffer.?, new_buffer.items.len);
            } else {
                self.buffer = try allocator.alloc.alloc(Row, new_buffer.items.len);
            }

            @memcpy(self.buffer.?, new_buffer.items);
        }

        self.cursor_len = 0;
    }

    pub fn getSel(self: *Self) ![]const u8 {
        const absSel: usize = @intCast(@abs(self.cursor_len));

        var result = try std.ArrayList(u8).initCapacity(allocator.alloc, absSel);
        defer result.deinit();

        var idx: usize = 0;

        if (self.buffer) |buffer| {
            for (buffer[self.cursory..]) |line| {
                for (line.text) |ch| {
                    if (idx >= self.cursorx and idx < self.cursorx + absSel) {
                        result.appendAssumeCapacity(ch);
                    }

                    idx += 1;
                }

                // new line
                if (idx >= self.cursorx and idx < self.cursorx + absSel) {
                    result.appendAssumeCapacity('\n');
                }

                idx += 1;
            }
        }

        return try allocator.alloc.dupe(u8, result.items);
    }

    pub fn save(self: *Self) !void {
        if (self.buffer) |buffer| {
            if (self.file != null) {
                var buff = std.ArrayList(u8).init(allocator.alloc);
                defer buff.deinit();

                for (buffer) |line| {
                    try buff.appendSlice(line.text);
                    try buff.append('\n');
                }

                _ = buff.pop();

                try self.file.?.write(try allocator.alloc.dupe(u8, buff.items), null);
                self.modified = false;
            } else {
                const adds = try allocator.alloc.create(popups.all.textpick.PopupTextPick);
                adds.* = .{
                    .text = try allocator.alloc.dupe(u8, files.home.name),
                    .submit = &submitSave,
                    .prompt = "Enter the file path",
                    .data = self,
                };

                try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
                    .popup = .{
                        .texture = "win",
                        .data = .{
                            .title = "Save As",
                            .source = rect.newRect(0, 0, 1, 1),
                            .pos = rect.newRectCentered(self.bnds, 350, 125),
                            .contents = popups.PopupData.PopupContents.init(adds),
                        },
                    },
                });
            }
        }
    }

    pub fn submitSave(path: []const u8, data: *anyopaque) !void {
        try files.root.newFile(path);

        const file = try files.root.getFile(path);

        const self: *Self = @ptrCast(@alignCast(data));

        self.file = file;

        try self.save();
    }

    pub fn submitOpen(file: ?*files.File, data: *anyopaque) !void {
        if (file) |target| {
            const self: *Self = @ptrCast(@alignCast(data));
            self.file = target;

            const fileConts = try self.file.?.read(null);
            const lines = std.mem.count(u8, fileConts, "\n") + 1;

            try self.clearBuffer();
            if (self.buffer) |buffer| {
                self.buffer = try allocator.alloc.realloc(buffer, lines);
            } else {
                self.buffer = try allocator.alloc.alloc(Row, lines);
            }

            var iter = std.mem.split(u8, fileConts, "\n");
            var idx: usize = 0;
            while (iter.next()) |line| {
                self.buffer.?[idx] = .{
                    .text = try allocator.alloc.dupe(u8, line),
                    .render = null,
                };

                idx += 1;
            }
        }
    }

    pub fn move(self: *Self, x: f32, y: f32) !void {
        if (!self.clickDown) return;

        self.clickDone = .{
            .x = x - 82,
            .y = y - 40,
        };
    }

    pub fn focus(self: *Self) !void {
        if (!self.modified and self.file != null) {
            try submitOpen(self.file, self);

            return;
        }
    }

    pub fn clearBuffer(self: *Self) !void {
        if (self.buffer) |buffer| {
            for (buffer) |*line| {
                if (line.render) |render| {
                    allocator.alloc.free(render);
                }

                allocator.alloc.free(line.text);
            }

            allocator.alloc.free(self.buffer.?);

            self.buffer = null;
        }
    }

    pub fn newFile(self: *Self) !void {
        if (self.modified) return;

        try self.clearBuffer();

        self.buffer = try allocator.alloc.alloc(Row, 1);
        self.buffer.?[0] = .{
            .text = try allocator.alloc.alloc(u8, 0),
        };

        self.file = null;
    }

    pub fn deinit(self: *Self) !void {
        try self.clearBuffer();
        if (self.buffer) |buffer|
            allocator.alloc.free(buffer);

        allocator.alloc.destroy(self);
    }

    pub fn char(self: *Self, code: u32, _: i32) !void {
        if (code == '\n') return;

        try self.deleteSel();

        if (self.buffer) |buffer| {
            const line = &buffer[self.cursory];

            line.text = try allocator.alloc.realloc(line.text, line.text.len + 1);

            std.mem.copyBackwards(u8, line.text[self.cursorx + 1 ..], line.text[self.cursorx .. line.text.len - 1]);
            line.text[self.cursorx] = @intCast(@rem(code, 255));

            line.clearRender();

            self.cursorx += 1;
            self.cursor_len = 0;
            self.modified = true;
        }
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        if (!down) return;
        if (keycode == c.GLFW_KEY_N and mods == (c.GLFW_MOD_CONTROL)) {
            try self.newFile();
            return;
        }

        if (self.buffer == null) return;

        switch (keycode) {
            c.GLFW_KEY_A => {
                if (mods == (c.GLFW_MOD_CONTROL)) {
                    self.cursorx = 0;
                    self.cursory = 0;
                    self.cursor_len = 0;
                    if (self.buffer) |buffer|
                        for (buffer) |line| {
                            self.cursor_len -= @intCast(line.text.len + 1);
                        };

                    return;
                }
            },
            c.GLFW_KEY_C => {
                if (mods == (c.GLFW_MOD_CONTROL)) {
                    const sel = try self.getSel();
                    defer allocator.alloc.free(sel);

                    try events.EventManager.instance.sendEvent(systemEvs.EventCopy{
                        .value = sel,
                    });

                    return;
                }
            },
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
                if (self.buffer) |buffer| {
                    self.buffer = try allocator.alloc.realloc(buffer, buffer.len + 1);
                    std.mem.copyBackwards(Row, self.buffer.?[self.cursory + 1 ..], self.buffer.?[self.cursory .. self.buffer.?.len - 1]);

                    const line = &self.buffer.?[self.cursory];
                    self.buffer.?[self.cursory + 1] = .{
                        .text = try allocator.alloc.dupe(u8, line.text[self.cursorx..]),
                    };

                    line.text = try allocator.alloc.realloc(line.text, self.cursorx);

                    line.clearRender();

                    self.cursorx = 0;
                    self.cursory += 1;

                    self.modified = true;
                }
            },
            c.GLFW_KEY_DELETE => {
                if (self.buffer) |buffer| {
                    if (self.cursor_len != 0) {
                        try self.deleteSel();

                        return;
                    }

                    const line = &buffer[self.cursory];

                    if (self.cursorx < line.text.len) {
                        std.mem.copyForwards(u8, line.text[self.cursorx .. line.text.len - 1], line.text[self.cursorx + 1 ..]);
                        line.text = try allocator.alloc.realloc(line.text, line.text.len - 1);

                        line.clearRender();

                        self.modified = true;
                    }
                }
            },
            c.GLFW_KEY_BACKSPACE => {
                if (self.buffer) |buffer| {
                    if (self.cursor_len != 0) {
                        try self.deleteSel();

                        return;
                    }

                    if (self.cursorx > 0) {
                        const line = &buffer[self.cursory];

                        std.mem.copyForwards(u8, line.text[self.cursorx - 1 .. line.text.len - 1], line.text[self.cursorx..]);
                        line.text = try allocator.alloc.realloc(line.text, line.text.len - 1);

                        line.clearRender();

                        self.modified = true;

                        self.cursorx -= 1;
                    } else if (self.cursory > 0) {
                        const oldLine = buffer[self.cursory - 1].text;
                        defer allocator.alloc.free(oldLine);

                        buffer[self.cursory - 1].text = try std.mem.concat(allocator.alloc, u8, &.{
                            buffer[self.cursory - 1].text,
                            buffer[self.cursory].text,
                        });
                        std.mem.copyForwards(Row, buffer[self.cursory .. buffer.len - 1], buffer[self.cursory + 1 ..]);

                        buffer[self.cursory - 1].clearRender();

                        self.buffer = try allocator.alloc.realloc(buffer, buffer.len - 1);

                        self.modified = true;

                        self.cursorx = oldLine.len;
                        self.cursory -= 1;
                    }
                }
            },
            c.GLFW_KEY_LEFT => {
                if (self.buffer) |buffer| {
                    if (mods == c.GLFW_MOD_SHIFT and self.cursor_len < 0) {
                        self.cursor_len += 1;
                    } else if (mods == c.GLFW_MOD_SHIFT and self.cursor_len > 0) {
                        if (self.cursorx > 0) {
                            self.cursorx -= 1;
                            self.cursor_len += 1;
                        }
                    } else if (mods == c.GLFW_MOD_SHIFT) {
                        if (self.cursorx > 0) {
                            self.cursorx -= 1;
                            self.cursor_len += 1;
                        }
                    } else {
                        if (self.cursor_len == 0) {
                            if (self.cursorx == 0) {
                                if (self.cursory != 0) {
                                    self.cursory -= 1;
                                    self.cursorx = buffer[self.cursory].text.len;
                                }
                            } else {
                                self.cursorx -= 1;
                            }
                        } else {
                            self.cursor_len = 0;
                        }
                    }
                }
            },
            c.GLFW_KEY_RIGHT => {
                if (self.buffer) |buffer| {
                    if (mods == c.GLFW_MOD_SHIFT and self.cursor_len > 0) {
                        if (self.cursorx < buffer[self.cursory].text.len) {
                            self.cursorx += 1;
                            self.cursor_len -= 1;
                        }
                    } else if (mods == c.GLFW_MOD_SHIFT and self.cursor_len < 0) {
                        self.cursor_len -= 1;
                    } else if (mods == c.GLFW_MOD_SHIFT) {
                        self.cursor_len -= 1;
                    } else {
                        if (self.cursor_len == 0) {
                            if (self.cursorx >= buffer[self.cursory].text.len) {
                                if (self.cursory < buffer.len) {
                                    self.cursory += 1;
                                    self.cursorx = 0;
                                }
                            } else {
                                self.cursorx += 1;
                            }
                        } else {
                            if (self.cursor_len < 0) {
                                self.cursorx += @intCast(-self.cursor_len);
                                self.cursor_len = 0;
                            } else {
                                self.cursor_len = 0;
                            }
                        }
                    }
                }
            },
            c.GLFW_KEY_UP => {
                if (self.cursory > 0)
                    self.cursory -= 1;
                self.cursor_len = 0;
            },
            c.GLFW_KEY_DOWN => {
                if (self.buffer) |buffer| {
                    if (self.cursory < buffer.len - 1)
                        self.cursory += 1;
                    self.cursor_len = 0;
                }
            },
            else => {},
        }
    }
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
                rect.newRect(1.0 / 8.0, 0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(32, 32),
            )),
            sp.Sprite.new("icons", sp.SpriteData.new(
                rect.newRect(0, 0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(32, 32),
            )),
            sp.Sprite.new("icons", sp.SpriteData.new(
                rect.newRect(2.0 / 8.0, 0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(32, 32),
            )),
        },
        .sel = sp.Sprite.new("ui", sp.SpriteData.new(
            rect.newRect(3.0 / 8.0, 4.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(100, 6),
        )),
        .shader = shader,
    };

    self.sel.data.color = col.newColorRGBA(255, 0, 0, 255);

    return win.WindowContents.init(self, "editor", fnt.EEE ++ "DT", col.newColor(1, 1, 1, 1));
}
