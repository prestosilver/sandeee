const std = @import("std");
const c = @import("../c.zig");

const windows = @import("mod.zig");

const drawers = @import("../drawers/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const log = util.log;

const config = system.config;
const files = system.files;

const EventManager = events.EventManager;
const system_events = events.system;
const window_events = events.windows;

const strings = data.strings;

// TODO: unhardcode, make into file format
const HL_KEYWORD1 = [_][]const u8{ "return ", "var ", "fn ", "for ", "while ", "if ", "else ", "asm " };
const HL_KEYWORD2 = [_][]const u8{"#include "};
const COMMENT_START = "//";
const STRING_START = '\"';
const ESCAPE_CHAR = '\\';

const STRING_ERROR = "{s}  " ++ strings.COLOR_RED ++ strings.LEFT ++ " {s}";

pub const EditorData = struct {
    const Self = @This();

    pub const Row = struct {
        text: []u8,
        render: ?[]const u8 = null,
        err: ?[]const u8 = null,

        pub fn clearRender(self: *Row) void {
            if (self.render) |r| {
                allocator.alloc.free(r);
                self.render = null;
            }

            if (self.err) |e| {
                allocator.alloc.free(e);
                self.err = null;
            }
        }

        pub fn getRenderLine(self: *const Row) ![]const u8 {
            return if (self.render) |render|
                if (self.err) |e|
                    try std.fmt.allocPrint(allocator.alloc, STRING_ERROR, .{ render, e })
                else
                    try allocator.alloc.dupe(u8, render)
            else
                &.{};
        }

        pub fn getRenderLen(line: []const u8, targetIdx: usize) !usize {
            var idx: usize = 0;
            var aidx: usize = 0;

            for (line) |ch| {
                if (ch < 0xf0) {
                    if (idx >= targetIdx) break;

                    idx += 1;
                }
                aidx += 1;
            }

            return aidx;
        }
    };

    buffer: ?[]Row = null,
    menubar: Sprite,
    num_left: Sprite,
    num_right: Sprite,
    sel: Sprite,
    icons: [3]Sprite,
    shader: *Shader,

    click_pos: ?Vec2 = null,
    click_done: ?Vec2 = null,
    click_down: bool = false,

    cursorx: usize = 0,
    cursory: usize = 0,
    cursor_len: i32 = 0,
    linex: usize = 0,

    modified: bool = false,
    file: ?*files.File = null,
    bnds: Rect = .{ .w = 0, .h = 0 },

    pub fn hlLine(row: *Row) !void {
        var line = try allocator.alloc.dupe(u8, row.text);
        var err: ?[]u8 = null;

        if (line.len == 0) {
            row.render = line;

            return;
        }

        for (line) |*ch| {
            if (ch.* >= 0xF0) {
                ch.* = 0x8F;
            }
        }

        for (HL_KEYWORD1) |keyword| {
            const comment = std.mem.indexOf(u8, line, COMMENT_START) orelse line.len;

            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                strings.COLOR_BLUE,
                keyword,
                strings.COLOR_BLACK,
            });
            defer allocator.alloc.free(replacement);

            const old_line = line;
            defer allocator.alloc.free(old_line);

            const rep_size = std.mem.replacementSize(u8, line[0..comment], keyword, replacement);

            line = try allocator.alloc.alloc(u8, rep_size + (line.len - comment));
            _ = std.mem.replace(u8, old_line[0..comment], keyword, replacement, line);
            @memcpy(line[rep_size..], old_line[comment..]);
        }

        for (HL_KEYWORD2) |keyword| {
            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                strings.COLOR_DARK_CYAN,
                keyword,
                strings.COLOR_BLACK,
            });
            defer allocator.alloc.free(replacement);

            const old_line = line;
            defer allocator.alloc.free(old_line);

            line = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, line, keyword, replacement));
            _ = std.mem.replace(u8, old_line, keyword, replacement, line);
        }

        {
            const replacement = try std.mem.concat(allocator.alloc, u8, &.{
                strings.COLOR_WHITE,
                COMMENT_START,
            });
            defer allocator.alloc.free(replacement);

            const old_line = line;
            defer allocator.alloc.free(old_line);

            line = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, line, COMMENT_START, replacement));
            _ = std.mem.replace(u8, old_line, COMMENT_START, replacement, line);
        }

        {
            const old_line = line;
            defer allocator.alloc.free(old_line);

            var count: usize = 0;

            {
                var in_string = false;
                var idx: usize = 0;

                for (old_line) |ch| {
                    if (ch == STRING_START and !in_string) {
                        in_string = !in_string;
                        count += 2;
                        idx += 1;
                        continue;
                    }
                    count += 1;
                    idx += 1;
                    if (ch == STRING_START and in_string) {
                        if (idx < 2 or old_line[idx - 2] == ESCAPE_CHAR)
                            continue;

                        in_string = !in_string;
                        count += 1;
                        idx += 1;
                    }
                }

                if (in_string) {
                    err = try allocator.alloc.dupe(u8, "missing \"");
                }

                line = try allocator.alloc.alloc(u8, count);
            }

            var idx: usize = 0;
            var in_string = false;
            var prev: u8 = 0;

            for (old_line) |ch| {
                defer prev = ch;
                if (ch == STRING_START and !in_string) {
                    in_string = !in_string;
                    line[idx] = strings.COLOR_DARK_GREEN[0];
                    idx = idx + 1;
                    line[idx] = ch;
                    idx = idx + 1;
                    continue;
                }
                line[idx] = ch;
                idx = idx + 1;
                if (ch == STRING_START and in_string) {
                    if (idx < 2 or prev == ESCAPE_CHAR)
                        continue;

                    in_string = !in_string;
                    line[idx] = strings.COLOR_BLACK[0];
                    idx = idx + 1;
                }
            }
        }

        row.render = line;
        row.err = err;
    }

    pub fn draw(self: *Self, shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 40,
            };
        }

        self.bnds = bnds.*;

        const char_size = font.sizeText(.{
            .text = "A",
        }).x;

        if (self.buffer) |_| {
            const file_name = if (self.file) |file| file.name else "[New File]";

            const idx = if (std.mem.lastIndexOf(u8, file_name, "/")) |idx| idx + 1 else 0;
            const title = try std.fmt.allocPrint(allocator.alloc, strings.EEE ++ "DT-{s}{s}", .{ file_name[idx..], if (self.modified) "*" else "" });
            defer allocator.alloc.free(title);

            try props.setTitle(title);
        }

        self.menubar.data.size.x = bnds.w;

        self.num_left.data.size.y = bnds.h - 40;
        self.num_right.data.size.y = bnds.h - 40;

        // draw number sidebar
        try SpriteBatch.global.draw(Sprite, &self.num_left, self.shader, .{ .x = bnds.x, .y = bnds.y + 40 });

        // draw number sidebar
        try SpriteBatch.global.draw(Sprite, &self.num_right, self.shader, .{ .x = bnds.x + 40, .y = bnds.y + 40 });

        // draw file text
        if (self.buffer) |buffer| {
            if (self.click_done) |click_done| blk: {
                defer self.click_done = null;

                if (click_done.x > bnds.w) break :blk;
                if (click_done.y - props.scroll.?.value > bnds.h) break :blk;
                if (click_done.x < 0) break :blk;
                if (click_done.y - props.scroll.?.value < 0) break :blk;

                const click_pos = self.click_pos.?;

                const done_big = if (@abs(@round(click_pos.y / font.size) - @round((click_done.y - props.scroll.?.value) / font.size)) < 1)
                    @round(click_pos.x / char_size) < @round(click_done.x / char_size)
                else
                    @round(click_pos.y / font.size) < @round((click_done.y - props.scroll.?.value) / font.size);

                const start = if (done_big) click_pos else click_done.sub(.{ .x = 0, .y = props.scroll.?.value });
                const end = if (done_big) click_done.sub(.{ .x = 0, .y = props.scroll.?.value }) else click_pos;

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

                if (done_big) {
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

            var sel_remaining: usize = @intCast(@abs(self.cursor_len));

            for (buffer, 0..) |*line, lineidx| {
                if (line.render == null)
                    try hlLine(line);

                const render_text = try line.getRenderLine();
                defer allocator.alloc.free(render_text);

                try font.draw(.{
                    .shader = shader,
                    .text = render_text,
                    .pos = .{ .x = bnds.x + 82, .y = y },
                    .wrap = bnds.w - 82,
                    .maxlines = 1,
                });

                const linenr = try std.fmt.allocPrint(allocator.alloc, "{}", .{lineidx + 1});
                defer allocator.alloc.free(linenr);
                try font.draw(.{
                    .shader = shader,
                    .text = linenr,
                    .pos = .{ .x = bnds.x + 6, .y = y },
                });

                if (self.cursory == lineidx) {
                    const render_len = try Row.getRenderLen(render_text, self.cursorx);

                    const posx = font.sizeText(.{
                        .text = render_text[0..render_len],
                        .cursor = true,
                    }).x;

                    const width = @min(sel_remaining, line.text.len - self.cursorx + 1);

                    self.sel.data.size.x = char_size * @as(f32, @floatFromInt(width));
                    self.sel.data.size.y = font.size;

                    sel_remaining -= width;

                    try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82 + posx, .y = y });

                    if (self.cursor_len >= 0) {
                        try font.draw(.{
                            .shader = shader,
                            .text = "|",
                            .pos = .{ .x = bnds.x + 82 + posx - 6, .y = y },
                        });
                    }
                } else if (sel_remaining > 0 and self.cursory < lineidx) {
                    const width = @min(sel_remaining, line.text.len + 1);
                    self.sel.data.size.x = char_size * @as(f32, @floatFromInt(width));
                    self.sel.data.size.y = font.size;

                    sel_remaining -= width;

                    try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82, .y = y });
                    if (self.cursor_len < 0 and sel_remaining == 0) {
                        const render_len = try Row.getRenderLen(render_text, width);

                        const posx = font.sizeText(.{
                            .text = render_text[0..render_len],
                            .cursor = true,
                        }).x;

                        try font.draw(.{
                            .shader = shader,
                            .text = "|",
                            .pos = .{ .x = bnds.x + 82 + posx - 6, .y = y },
                        });
                    }
                }

                y += font.size;
                props.scroll.?.maxy += font.size;
            }
        }

        // draw toolbar
        try SpriteBatch.global.draw(Sprite, &self.menubar, self.shader, .{ .x = bnds.x, .y = bnds.y });

        // draw toolbar icons
        try SpriteBatch.global.draw(Sprite, &self.icons[0], self.shader, .{ .x = bnds.x + 2, .y = bnds.y + 4 });
        try SpriteBatch.global.draw(Sprite, &self.icons[1], self.shader, .{ .x = bnds.x + 38, .y = bnds.y + 4 });
        try SpriteBatch.global.draw(Sprite, &self.icons[2], self.shader, .{ .x = bnds.x + 74, .y = bnds.y + 4 });
    }

    pub fn click(self: *Self, _: Vec2, mousepos: Vec2, btn: ?i32) !void {
        self.click_down = self.click_down and btn != null;

        if (btn) |button|
            switch (button) {
                0 => {
                    const open = Rect{ .w = 36, .h = 36 };
                    if (open.contains(mousepos)) {
                        const home = try files.FolderLink.resolve(.home);

                        const adds = try allocator.alloc.create(Popup.Data.filepick.PopupFilePick);
                        adds.* = .{
                            .path = try allocator.alloc.dupe(u8, home.name),
                            .data = self,
                            .submit = &submitOpen,
                        };

                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                            .popup = .atlas("win", .{
                                .title = "Open",
                                .source = .{ .w = 1, .h = 1 },
                                .pos = .initCentered(self.bnds, 350, 125),
                                .contents = .init(adds),
                            }),
                        });
                    }

                    const save_bnds = Rect{ .x = 36, .w = 36, .h = 36 };
                    if (save_bnds.contains(mousepos)) {
                        try self.save();
                    }

                    const new_bnds = Rect{ .x = 72, .w = 36, .h = 36 };
                    if (new_bnds.contains(mousepos)) {
                        try self.newFile();
                    }

                    if (self.buffer) |buffer| {
                        if (buffer.len != 0) {
                            if (mousepos.y > 40 and mousepos.x > 82) {
                                self.click_pos = mousepos.sub(.{
                                    .y = 40,
                                    .x = 82,
                                });
                                self.click_done = self.click_pos;
                                self.click_down = true;
                            }
                        }
                    }
                },
                else => {},
            };
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
                    .text = &.{},
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

            self.clearBuffer();

            self.buffer = if (self.buffer) |old_buffer|
                try allocator.alloc.realloc(old_buffer, new_buffer.items.len)
            else
                try allocator.alloc.alloc(Row, new_buffer.items.len);

            @memcpy(self.buffer.?, new_buffer.items);
        }

        self.cursor_len = 0;
    }

    pub fn getSel(self: *Self) ![]const u8 {
        const abs_sel: usize = @intCast(@abs(self.cursor_len));

        var result = try std.ArrayList(u8).initCapacity(allocator.alloc, abs_sel);
        defer result.deinit();

        var idx: usize = 0;

        if (self.buffer) |buffer| {
            for (buffer[self.cursory..]) |line| {
                for (line.text) |ch| {
                    if (idx >= self.cursorx and idx < self.cursorx + abs_sel) {
                        result.appendAssumeCapacity(ch);
                    }

                    idx += 1;
                }

                // new line
                if (idx >= self.cursorx and idx < self.cursorx + abs_sel) {
                    result.appendAssumeCapacity('\n');
                }

                idx += 1;
            }
        }

        return try allocator.alloc.dupe(u8, result.items);
    }

    pub fn save(self: *Self) !void {
        if (self.buffer) |buffer| {
            if (self.file) |file| {
                var buff = std.ArrayList(u8).init(allocator.alloc);
                defer buff.deinit();

                for (buffer) |line| {
                    try buff.appendSlice(line.text);
                    try buff.append('\n');
                }

                _ = buff.pop();

                try file.write(buff.items, null);
                self.modified = false;
            } else {
                const home = try files.FolderLink.resolve(.home);

                const adds = try allocator.alloc.create(Popup.Data.textpick.PopupTextPick);
                adds.* = .{
                    .text = try allocator.alloc.dupe(u8, home.name),
                    .submit = &submitSave,
                    .prompt = try allocator.alloc.dupe(u8, "Enter the file path"),
                    .data = self,
                };

                try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                    .popup = .atlas("win", .{
                        .title = "Save As",
                        .source = .{ .w = 1, .h = 1 },
                        .pos = .initCentered(self.bnds, 350, 125),
                        .contents = .init(adds),
                    }),
                });
            }
        }
    }

    pub fn submitSave(path: []const u8, popup_data: *anyopaque) !void {
        const root = try files.FolderLink.resolve(.root);
        try root.newFile(path);

        const file = try root.getFile(path);
        const self: *Self = @ptrCast(@alignCast(popup_data));
        self.file = file;

        try self.save();
    }

    pub fn submitOpen(file: ?*files.File, popup_data: *anyopaque) !void {
        if (file) |target| {
            const self: *Self = @ptrCast(@alignCast(popup_data));
            self.file = target;

            const file_conts = try self.file.?.read(null);
            const lines = std.mem.count(u8, file_conts, "\n") + 1;

            self.clearBuffer();

            if (self.buffer) |buffer| {
                self.buffer = try allocator.alloc.realloc(buffer, lines);
            } else {
                self.buffer = try allocator.alloc.alloc(Row, lines);
            }

            var iter = std.mem.splitScalar(u8, file_conts, '\n');
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
        if (!self.click_down) return;

        self.click_done = .{
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

    pub fn clearBuffer(self: *Self) void {
        if (self.buffer) |buffer| {
            for (buffer) |*line| {
                if (line.render) |render| {
                    allocator.alloc.free(render);
                }

                allocator.alloc.free(line.text);
            }

            allocator.alloc.free(buffer);

            self.buffer = null;
        }
    }

    pub fn newFile(self: *Self) !void {
        if (self.modified) return;

        self.clearBuffer();

        self.buffer = try allocator.alloc.dupe(Row, &[_]Row{Row{
            .text = &.{},
        }});

        self.file = null;
    }

    pub fn deinit(self: *Self) void {
        self.clearBuffer();
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

                    try events.EventManager.instance.sendEvent(system_events.EventCopy{
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
                if (self.buffer) |*buffer| {
                    buffer.* = try allocator.alloc.realloc(buffer.*, buffer.len + 1);
                    std.mem.copyBackwards(Row, buffer.*[self.cursory + 1 ..], buffer.*[self.cursory .. buffer.len - 1]);

                    const line = &buffer.*[self.cursory];
                    buffer.*[self.cursory + 1] = .{
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
                        const old_line = buffer[self.cursory - 1].text;
                        defer allocator.alloc.free(old_line);

                        buffer[self.cursory - 1].text = try std.mem.concat(allocator.alloc, u8, &.{
                            buffer[self.cursory - 1].text,
                            buffer[self.cursory].text,
                        });
                        std.mem.copyForwards(Row, buffer[self.cursory .. buffer.len - 1], buffer[self.cursory + 1 ..]);

                        buffer[self.cursory - 1].clearRender();

                        self.buffer = try allocator.alloc.realloc(buffer, buffer.len - 1);

                        self.modified = true;

                        self.cursorx = old_line.len;
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

    pub fn refresh(self: *Self) !void {
        if (config.SettingManager.instance.get("accent_color")) |accent| {
            if (accent.len != 6) {
                self.sel.data.color.r = 1.0;
                self.sel.data.color.g = 1.0;
                self.sel.data.color.b = 1.0;
            } else {
                self.sel.data.color.r = @as(f32, @floatFromInt(std.fmt.parseInt(u8, accent[0..2], 16) catch 0)) / 255;
                self.sel.data.color.g = @as(f32, @floatFromInt(std.fmt.parseInt(u8, accent[2..4], 16) catch 0)) / 255;
                self.sel.data.color.b = @as(f32, @floatFromInt(std.fmt.parseInt(u8, accent[4..6], 16) catch 0)) / 255;
            }
        }
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.alloc.create(EditorData);

    self.* = .{
        .menubar = .atlas("ui", .{
            .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
            .size = .{ .y = 40 },
        }),
        .num_left = .atlas("ui", .{
            .source = .{ .x = 4.0 / 8.0, .y = 4.0 / 8.0, .w = 2.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 40 },
        }),
        .num_right = .atlas("ui", .{
            .source = .{ .x = 4.0 / 8.0, .y = 4.0 / 8.0, .w = 4.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 40 },
        }),
        .icons = .{
            .atlas("icons", .{
                .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 32, .y = 32 },
            }),
            .atlas("icons", .{
                .source = .{ .x = 0.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 32, .y = 32 },
            }),
            .atlas("icons", .{
                .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 32, .y = 32 },
            }),
        },
        .sel = .atlas("ui", .{
            .color = .{ .r = 1, .g = 1, .b = 1 },
            .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .y = 6 },
        }),
        .shader = shader,
    };

    return Window.Data.WindowContents.init(self, "editor", strings.EEE ++ "DT", .{ .r = 1, .g = 1, .b = 1 });
}
