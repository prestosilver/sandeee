const std = @import("std");
const glfw = @import("glfw");

const windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const IVec2 = math.IVec2;
const Color = math.Color;

const popups = windows.popups;

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

const TAB_WIDTH = 2;

pub const EditorData = struct {
    const Self = @This();

    pub const Row = struct {
        text: std.array_list.Managed(u8),
        render: ?[]const u8 = null,
        err: ?[]const u8 = null,

        pub fn clearRender(self: *Row) void {
            if (self.render) |r| {
                allocator.free(r);
                self.render = null;
            }

            if (self.err) |e| {
                allocator.free(e);
                self.err = null;
            }
        }

        pub fn deinit(self: Row) void {
            if (self.render) |r|
                allocator.free(r);
            if (self.err) |e|
                allocator.free(e);

            self.text.deinit();
        }

        pub fn getRenderLine(self: *const Row) ![]const u8 {
            return if (self.render) |render|
                if (self.err) |e|
                    try std.fmt.allocPrint(allocator, STRING_ERROR, .{ render, e })
                else
                    try allocator.dupe(u8, render)
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

    buffer: ?std.array_list.Managed(Row) = null,
    menubar: Sprite,
    num_left: Sprite,
    num_right: Sprite,
    sel: Sprite,
    icons: [3]Sprite,
    shader: *Shader,

    click_down: bool = false,
    click_done: Vec2 = .{},
    click_pos: Vec2 = .{},

    abs_cursor_pos: IVec2 = .{},
    abs_cursor_end: IVec2 = .{},

    modified: bool = false,
    file: ?*files.File = null,
    bnds: Rect = .{ .w = 0, .h = 0 },

    pub fn hlLine(row: *Row) !void {
        var line: std.array_list.Managed(u8) = try row.text.clone();
        defer line.deinit();
        var line_b: std.array_list.Managed(u8) = .init(allocator);
        defer line_b.deinit();

        var err: ?[]u8 = null;

        if (line.items.len == 0) {
            row.render = try line.toOwnedSlice();

            return;
        }

        for (line.items) |*ch| {
            if (ch.* >= 0xF0) {
                ch.* = 0x8F;
            }
        }

        inline for (HL_KEYWORD1) |keyword| {
            const comment_start = std.mem.indexOf(u8, line.items, COMMENT_START) orelse line.items.len;

            const replacement = strings.COLOR_BLUE ++ keyword ++ strings.COLOR_BLACK;

            const replacement_size = std.mem.replacementSize(u8, line.items[0..comment_start], keyword, replacement);
            try line_b.resize(replacement_size);
            _ = std.mem.replace(u8, line.items[0..comment_start], keyword, replacement, line_b.items);
            try line_b.appendSlice(line.items[comment_start..]);

            {
                const tmp = line;
                line = line_b;
                line_b = tmp;

                line_b.clearRetainingCapacity();
            }
        }

        inline for (HL_KEYWORD2) |keyword| {
            if (std.mem.startsWith(u8, line.items, keyword)) {
                try line.insertSlice(keyword.len, strings.COLOR_BLACK);
                try line.insertSlice(0, strings.COLOR_DARK_CYAN);
            }
        }

        if (std.mem.indexOf(u8, line.items, COMMENT_START)) |idx|
            try line.insertSlice(idx, strings.COLOR_GRAY);

        {
            var in_string = false;
            var prev: u8 = 0;

            for (line.items, 0..) |ch, idx| {
                defer prev = ch;

                if (ch == STRING_START and !in_string) {
                    in_string = !in_string;
                    try line_b.appendSlice(strings.COLOR_DARK_GREEN);
                    try line_b.append(ch);
                    continue;
                }
                try line_b.append(ch);

                if (ch == STRING_START and in_string) {
                    if (idx < 2 or prev == ESCAPE_CHAR)
                        continue;

                    in_string = !in_string;
                    try line_b.appendSlice(strings.COLOR_BLACK);
                }
            }

            {
                const tmp = line;
                line = line_b;
                line_b = tmp;

                line_b.clearRetainingCapacity();
            }

            if (in_string)
                err = try allocator.dupe(u8, "missing \"");
        }

        row.render = try line.toOwnedSlice();
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
            const title = try std.fmt.allocPrint(allocator, strings.EEE ++ "DT-{s}{s}", .{ file_name[idx..], if (self.modified) "*" else "" });
            defer allocator.free(title);

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
            if (self.click_down) {
                var y = bnds.y + 40 - props.scroll.?.value;

                var click_start: bool = false;
                var click_stop: bool = false;

                for (buffer.items, 0..) |*line, lineidx| {
                    if (self.click_pos.y < y + font.size - bnds.y - 40 and !click_start) {
                        self.abs_cursor_pos.y = lineidx;

                        const x_pos: usize = @intFromFloat(@max(0, self.click_pos.x - 0.5 * char_size) / char_size);
                        self.abs_cursor_pos.x = @min(x_pos, line.text.items.len);

                        click_start = true;
                    }

                    if (self.click_done.y < y + font.size - bnds.y - 40 + props.scroll.?.value and !click_stop) {
                        self.abs_cursor_end.y = lineidx;

                        const x_pos: usize = @intFromFloat(@max(0, self.click_done.x - 0.5 * char_size) / char_size);
                        self.abs_cursor_end.x = @min(x_pos, line.text.items.len);

                        click_stop = true;
                    }

                    y += font.size;
                }
            }

            if (self.abs_cursor_pos.y >= buffer.items.len)
                self.abs_cursor_pos.y = buffer.items.len - 1;
            if (self.abs_cursor_end.y >= buffer.items.len)
                self.abs_cursor_end.y = buffer.items.len - 1;

            var cursor_pos = self.abs_cursor_pos;
            var cursor_end = self.abs_cursor_end;

            if (cursor_pos.x >= buffer.items[cursor_pos.y].text.items.len)
                cursor_pos.x = buffer.items[cursor_pos.y].text.items.len;
            if (cursor_end.x >= buffer.items[cursor_end.y].text.items.len)
                cursor_end.x = buffer.items[cursor_end.y].text.items.len;

            // draw lines
            var y = bnds.y + 40 - props.scroll.?.value;

            props.scroll.?.maxy = -bnds.h + 40;

            var sel: bool = false;

            for (buffer.items, 0..) |*line, lineidx| {
                if (line.render == null)
                    try hlLine(line);

                const render_text = try line.getRenderLine();
                defer allocator.free(render_text);

                try font.draw(.{
                    .shader = shader,
                    .text = render_text,
                    .pos = .{ .x = bnds.x + 82, .y = y },
                    .wrap = bnds.w - 82,
                    .maxlines = 1,
                });

                const linenr = try std.fmt.allocPrint(allocator, "{}", .{lineidx + 1});
                defer allocator.free(linenr);
                try font.draw(.{
                    .shader = shader,
                    .text = linenr,
                    .pos = .{ .x = bnds.x + 6, .y = y },
                });

                const min = @min(cursor_pos.x, cursor_end.x);
                const max = @max(cursor_pos.x, cursor_end.x);

                if (cursor_end.y == lineidx) {
                    const end_render_len = try Row.getRenderLen(render_text, cursor_end.x);

                    if (cursor_pos.y != lineidx) {
                        if (sel) {
                            // case 1: it started in a previous line
                            self.sel.data.size.x = char_size * @as(f32, @floatFromInt(cursor_end.x));
                            self.sel.data.size.y = font.size;

                            try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82, .y = y });
                        } else {
                            // case 2: it started this line
                            self.sel.data.size.x = char_size * @as(f32, @floatFromInt(render_text.len - cursor_end.x + 1));
                            self.sel.data.size.y = font.size;

                            const end_posx = font.sizeText(.{
                                .text = render_text[0..end_render_len],
                                .cursor = true,
                            }).x;

                            try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82 + end_posx, .y = y });
                        }
                    }

                    sel = !sel;
                }

                if (cursor_pos.y == lineidx) {
                    const start_render_len = try Row.getRenderLen(render_text, cursor_pos.x);
                    const min_render_len = try Row.getRenderLen(render_text, min);

                    if (cursor_end.y == lineidx) {
                        // case 1: it started and ended this line
                        const width = max - min;
                        self.sel.data.size.x = char_size * @as(f32, @floatFromInt(width));
                        self.sel.data.size.y = font.size;

                        const min_posx = font.sizeText(.{
                            .text = render_text[0..min_render_len],
                            .cursor = true,
                        }).x;

                        try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82 + min_posx, .y = y });
                    } else if (sel) {
                        // case 2: it started in a previous line
                        self.sel.data.size.x = char_size * @as(f32, @floatFromInt(cursor_pos.x));
                        self.sel.data.size.y = font.size;

                        try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82, .y = y });
                    } else {
                        // case 3: it started this line
                        self.sel.data.size.x = char_size * @as(f32, @floatFromInt(line.text.items.len - cursor_pos.x + 1));
                        self.sel.data.size.y = font.size;

                        const end_posx = font.sizeText(.{
                            .text = render_text[0..start_render_len],
                            .cursor = true,
                        }).x;

                        try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82 + end_posx, .y = y });
                    }

                    sel = !sel;
                }

                if (cursor_end.y == lineidx) {
                    const end_render_len = try Row.getRenderLen(render_text, cursor_end.x);

                    const posx = font.sizeText(.{
                        .text = render_text[0..end_render_len],
                        .cursor = true,
                    }).x;

                    try font.draw(.{
                        .shader = shader,
                        .text = "|",
                        .pos = .{ .x = bnds.x + 82 + posx - 6, .y = y },
                    });
                }

                if (sel and cursor_pos.y != lineidx and cursor_end.y != lineidx) {
                    self.sel.data.size.x = char_size * @as(f32, @floatFromInt(line.text.items.len + 1));
                    self.sel.data.size.y = font.size;

                    try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 82, .y = y });
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

    pub fn click(self: *Self, _: Vec2, mousepos: Vec2, btn: i32, kind: events.input.ClickKind) !void {
        if (kind == .up)
            self.click_down = false;

        switch (btn) {
            0 => {
                if (kind == .single) {
                    const open = Rect{ .w = 36, .h = 36 };
                    if (open.contains(mousepos)) {
                        const home = try files.FolderLink.resolve(.home);

                        const adds = try allocator.create(popups.filepick.PopupFilePick);
                        adds.* = .{
                            .path = .fromOwnedSlice(allocator, try allocator.dupe(u8, home.name)),
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
                }

                if (self.buffer) |buffer| {
                    if (buffer.items.len != 0 and
                        mousepos.y > 40 and mousepos.x > 82)
                    {
                        if (kind == .down) {
                            self.click_pos = mousepos.sub(.{
                                .y = 40,
                                .x = 82,
                            });
                            self.click_down = true;
                        }
                    }
                }
            },
            else => {},
        }
    }

    pub fn deleteSel(self: *Self) !void {
        if (self.buffer) |*buffer| {
            var start = self.abs_cursor_pos;
            var end = self.abs_cursor_end;

            if (start.x >= buffer.items[start.y].text.items.len)
                start.x = buffer.items[start.y].text.items.len;
            if (end.x >= buffer.items[end.y].text.items.len)
                end.x = buffer.items[end.y].text.items.len;

            if (start.y > end.y) {
                const temp = end;
                end = start;
                start = temp;
            } else if (start.y == end.y) {
                if (start.x == end.x)
                    return;

                if (start.x > end.x) {
                    const temp = end;
                    end = start;
                    start = temp;
                }

                const removal_len = end.x - start.x;

                const line = &buffer.items[start.y];
                line.text.replaceRangeAssumeCapacity(start.x, removal_len, "");
                line.clearRender();
            } else {
                const new_text = try std.mem.concat(allocator, u8, &.{
                    buffer.items[start.y].text.items[0..start.x],
                    buffer.items[end.y].text.items[end.x..],
                });
                for (buffer.items[start.y .. end.y + 1]) |line|
                    line.deinit();

                buffer.replaceRangeAssumeCapacity(start.y, end.y - start.y + 1, &.{.{
                    .text = .fromOwnedSlice(allocator, new_text),
                }});
            }

            self.abs_cursor_pos = start;
            self.abs_cursor_end = start;

            self.modified = true;
        }
    }

    pub fn getSel(self: *Self) ![]const u8 {
        var result: std.array_list.Managed(u8) = .init(allocator);
        defer result.deinit();

        if (self.buffer) |buffer| sel_block: {
            var start = self.abs_cursor_pos;
            var end = self.abs_cursor_end;

            if (start.x >= buffer.items[start.y].text.items.len)
                start.x = buffer.items[start.y].text.items.len;
            if (end.x >= buffer.items[end.y].text.items.len)
                end.x = buffer.items[end.y].text.items.len;

            if (start.y > end.y) {
                const temp = end;
                end = start;
                start = temp;
            } else if (start.y == end.y) {
                try result.appendSlice(buffer.items[start.y].text.items[@min(start.x, end.x)..@max(start.x, end.x)]);
                break :sel_block;
            }

            for (start.y..end.y) |line_idx| {
                const line = buffer.items[line_idx];
                if (line_idx == start.y)
                    try result.appendSlice(line.text.items[start.x..])
                else
                    try result.appendSlice(line.text.items);

                try result.append('\n');
            }

            try result.appendSlice(buffer.items[end.y].text.items[0..end.x]);
        }

        return try result.toOwnedSlice();
    }

    pub fn save(self: *Self) !void {
        if (self.buffer) |buffer| {
            if (self.file) |file| {
                var buff = std.array_list.Managed(u8).init(allocator);
                defer buff.deinit();

                for (buffer.items) |line| {
                    try buff.appendSlice(line.text.items);
                    try buff.append('\n');
                }

                _ = buff.pop();

                try file.write(buff.items, null);
                self.modified = false;
            } else {
                const home = try files.FolderLink.resolve(.home);

                const adds = try allocator.create(popups.textpick.PopupTextPick);
                adds.* = .{
                    .text = .fromOwnedSlice(allocator, try allocator.dupe(u8, home.name)),
                    .submit = &submitSave,
                    .prompt = try allocator.dupe(u8, "Enter the file path"),
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

            if (self.buffer == null)
                self.buffer = try .initCapacity(allocator, lines);
            try self.buffer.?.resize(lines);

            var iter = std.mem.splitScalar(u8, file_conts, '\n');
            var idx: usize = 0;
            while (iter.next()) |line| {
                self.buffer.?.items[idx] = .{
                    .text = .fromOwnedSlice(allocator, try allocator.dupe(u8, line)),
                    .render = null,
                };

                idx += 1;
            }
        }
    }

    pub fn move(self: *Self, x: f32, y: f32) !void {
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
            for (buffer.items) |line|
                line.deinit();

            buffer.deinit();

            self.buffer = null;
        }
    }

    pub fn newFile(self: *Self) !void {
        if (self.modified) return;

        self.clearBuffer();
        self.buffer = .init(allocator);

        try self.buffer.?.append(.{
            .text = .init(allocator),
        });

        self.file = null;
    }

    pub fn deinit(self: *Self) void {
        self.clearBuffer();

        allocator.destroy(self);
    }

    pub fn char(self: *Self, char_string: []const u8, _: i32) !void {
        if (std.mem.eql(u8, char_string, "\n")) return;

        // TODO: figure out support for this
        if (char_string.len > 1) return;

        if (self.buffer) |buffer| {
            try self.deleteSel();

            var cursor_pos = self.abs_cursor_pos;
            var cursor_end = self.abs_cursor_end;

            if (cursor_pos.y >= buffer.items.len)
                cursor_pos.y = buffer.items.len;
            if (cursor_end.y >= buffer.items.len)
                cursor_end.y = buffer.items.len;

            if (cursor_pos.x >= buffer.items[cursor_pos.y].text.items.len)
                cursor_pos.x = buffer.items[cursor_pos.y].text.items.len;
            if (cursor_end.x >= buffer.items[cursor_end.y].text.items.len)
                cursor_end.x = buffer.items[cursor_end.y].text.items.len;

            const line = &buffer.items[cursor_pos.y];

            try line.text.insertSlice(cursor_pos.x, char_string);
            line.clearRender();

            cursor_pos.x += 1;
            cursor_end = cursor_pos;

            self.abs_cursor_pos = cursor_pos;
            self.abs_cursor_end = cursor_end;

            self.modified = true;
        }
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        if (!down) return;
        if (keycode == glfw.KeyN and mods == (glfw.ModifierControl)) {
            try self.newFile();
            return;
        }

        if (self.buffer == null) return;

        switch (keycode) {
            glfw.KeyA => {
                if (self.buffer) |buffer| {
                    if (mods == glfw.ModifierControl) {
                        self.abs_cursor_pos = .{};
                        self.abs_cursor_end = .{
                            .y = buffer.items.len,
                            .x = buffer.getLast().text.items.len,
                        };
                    }
                }
            },
            glfw.KeyC => {
                if (mods == glfw.ModifierControl) {
                    const sel = try self.getSel();
                    defer allocator.free(sel);

                    try events.EventManager.instance.sendEvent(system_events.EventCopy{
                        .value = sel,
                    });

                    return;
                }
            },
            glfw.KeyS => {
                if (mods == glfw.ModifierControl) {
                    try self.save();

                    return;
                }
            },
            glfw.KeyTab => {
                inline for (0..TAB_WIDTH) |_| {
                    try self.char(" ", mods);
                }
            },
            glfw.KeyEnter => {
                if (self.buffer) |*buffer| {
                    try self.deleteSel();

                    var cursor_pos = self.abs_cursor_pos;
                    var cursor_end = self.abs_cursor_end;

                    if (cursor_pos.x >= buffer.items[cursor_pos.y].text.items.len)
                        cursor_pos.x = buffer.items[cursor_pos.y].text.items.len;
                    if (cursor_end.x >= buffer.items[cursor_end.y].text.items.len)
                        cursor_end.x = buffer.items[cursor_end.y].text.items.len;

                    if (cursor_pos.y > cursor_end.y or (cursor_pos.y == cursor_end.y and cursor_pos.x > cursor_pos.x)) {
                        const temp = cursor_pos;
                        cursor_pos = cursor_end;
                        cursor_end = temp;
                    }

                    try buffer.insert(cursor_pos.y + 1, .{
                        .text = .fromOwnedSlice(
                            allocator,
                            try allocator.dupe(u8, buffer.items[cursor_pos.y].text.items[cursor_pos.x..]),
                        ),
                    });

                    buffer.items[cursor_pos.y].text.shrinkRetainingCapacity(cursor_pos.x);
                    buffer.items[cursor_pos.y].clearRender();

                    cursor_pos.x = 0;
                    cursor_pos.y += 1;
                    cursor_end = cursor_pos;

                    self.abs_cursor_pos = cursor_pos;
                    self.abs_cursor_end = cursor_pos;

                    self.modified = true;
                }
            },
            glfw.KeyDelete => {
                if (self.buffer) |*buffer| {
                    if (self.abs_cursor_pos.y != self.abs_cursor_end.y or
                        self.abs_cursor_pos.x != self.abs_cursor_end.x)
                    {
                        try self.deleteSel();

                        return;
                    }

                    var cursor_pos = self.abs_cursor_pos;

                    if (cursor_pos.x >= buffer.items[cursor_pos.y].text.items.len)
                        cursor_pos.x = buffer.items[cursor_pos.y].text.items.len;

                    const line = &buffer.items[cursor_pos.y];

                    if (cursor_pos.x < line.text.items.len) {
                        _ = line.text.orderedRemove(cursor_pos.x);
                        line.clearRender();

                        self.modified = true;
                    } else if (cursor_pos.y < buffer.items.len - 1) {
                        try buffer.items[cursor_pos.y].text.appendSlice(buffer.items[cursor_pos.y + 1].text.items);
                        buffer.items[cursor_pos.y].clearRender();

                        var old_line = buffer.orderedRemove(cursor_pos.y + 1);
                        old_line.deinit();
                    }
                }
            },
            glfw.KeyBackspace => {
                if (self.buffer) |*buffer| {
                    if (self.abs_cursor_pos.y != self.abs_cursor_end.y or
                        self.abs_cursor_pos.x != self.abs_cursor_end.x)
                    {
                        try self.deleteSel();

                        return;
                    }

                    var cursor_pos = self.abs_cursor_pos;

                    if (cursor_pos.x >= buffer.items[cursor_pos.y].text.items.len)
                        cursor_pos.x = buffer.items[cursor_pos.y].text.items.len;

                    const line = &buffer.items[cursor_pos.y];

                    if (cursor_pos.x > 0) {
                        _ = line.text.orderedRemove(cursor_pos.x - 1);
                        line.clearRender();

                        self.modified = true;

                        self.abs_cursor_pos.x = cursor_pos.x - 1;
                        self.abs_cursor_end.x = cursor_pos.x - 1;
                    } else if (cursor_pos.y > 0) {
                        self.abs_cursor_pos.x = buffer.items[cursor_pos.y - 1].text.items.len;
                        self.abs_cursor_end.x = buffer.items[cursor_pos.y - 1].text.items.len;
                        self.abs_cursor_pos.y -= 1;
                        self.abs_cursor_end.y -= 1;

                        try buffer.items[cursor_pos.y - 1].text.appendSlice(buffer.items[cursor_pos.y].text.items);
                        buffer.items[cursor_pos.y - 1].clearRender();

                        const old_line = buffer.orderedRemove(cursor_pos.y);
                        old_line.deinit();
                    }
                }
            },
            glfw.KeyLeft => {
                if (self.buffer) |buffer| {
                    if (mods == glfw.ModifierShift) {
                        if (self.abs_cursor_end.x > 0) {
                            self.abs_cursor_end.x -= 1;
                        } else if (self.abs_cursor_end.y != 0) {
                            self.abs_cursor_end.y -= 1;
                            self.abs_cursor_end.x = buffer.items[self.abs_cursor_end.y].text.items.len;
                        }
                    } else {
                        if (self.abs_cursor_pos.x > 0) {
                            self.abs_cursor_pos.x -= 1;
                        } else if (self.abs_cursor_pos.y != 0) {
                            self.abs_cursor_pos.y -= 1;
                            self.abs_cursor_pos.x = buffer.items[self.abs_cursor_pos.y].text.items.len;
                        }

                        self.abs_cursor_end = self.abs_cursor_pos;
                    }
                }
            },
            glfw.KeyRight => {
                if (self.buffer) |buffer| {
                    if (mods == glfw.ModifierShift) {
                        if (self.abs_cursor_end.x >= buffer.items[self.abs_cursor_end.y].text.items.len) {
                            if (self.abs_cursor_end.y < buffer.items.len - 1) {
                                self.abs_cursor_end.y += 1;
                                self.abs_cursor_end.x = 0;
                            }
                        } else {
                            self.abs_cursor_end.x += 1;
                        }
                    } else {
                        if (self.abs_cursor_pos.x >= buffer.items[self.abs_cursor_pos.y].text.items.len) {
                            if (self.abs_cursor_pos.y < buffer.items.len - 1) {
                                self.abs_cursor_pos.y += 1;
                                self.abs_cursor_pos.x = 0;
                            }
                        } else {
                            self.abs_cursor_pos.x += 1;
                        }

                        self.abs_cursor_end = self.abs_cursor_pos;
                    }
                }
            },
            glfw.KeyUp => {
                if (self.buffer) |_| {
                    if (mods == glfw.ModifierShift) {
                        if (self.abs_cursor_end.y > 0)
                            self.abs_cursor_end.y -= 1;
                    } else {
                        if (self.abs_cursor_pos.y > 0)
                            self.abs_cursor_pos.y -= 1;
                        self.abs_cursor_end = self.abs_cursor_pos;
                    }
                }
            },
            glfw.KeyDown => {
                if (self.buffer) |buffer| {
                    if (mods == glfw.ModifierShift) {
                        if (self.abs_cursor_end.y < buffer.items.len - 1)
                            self.abs_cursor_end.y += 1;
                    } else {
                        if (self.abs_cursor_pos.y < buffer.items.len - 1)
                            self.abs_cursor_pos.y += 1;
                        self.abs_cursor_end = self.abs_cursor_pos;
                    }
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
    const self = try allocator.create(EditorData);

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
                .source = .{ .x = 1.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
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
