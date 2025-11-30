const std = @import("std");
const c = @import("../c.zig");

const Windows = @import("mod.zig");

const drawers = @import("../drawers/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Window = drawers.Window;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const log = util.log;

const Shell = system.Shell;
const files = system.files;

const EventManager = events.EventManager;
const system_events = events.system;

const strings = data.strings;

// TODO: unhardcode, move to settings
const MAX_SIZE = 100000;

pub const CMDData = struct {
    const Self = @This();

    bt: []u8,
    input_buffer: [256]u8 = undefined,
    input_len: u8 = 0,
    input_idx: u8 = 0,

    history: std.ArrayList([]const u8),
    history_idx: usize = 0,
    shell: Shell,
    bot: bool = false,
    close: bool = false,

    pub fn processBT(self: *Self) !void {
        const oldbt = self.bt;
        defer allocator.alloc.free(oldbt);

        self.bt = try allocator.alloc.alloc(u8, self.bt.len);
        var idx: usize = 0;

        for (oldbt) |ch| {
            switch (ch) {
                '\x08' => {
                    if (self.bt.len >= 0)
                        idx -= 1;
                },
                '\x01' => {
                    idx = 0;
                },
                '\r' => {
                    if (std.mem.lastIndexOf(u8, self.bt[0..idx], "\n")) |newidx|
                        idx = newidx + 1
                    else
                        idx = 0;
                },
                else => {
                    self.bt[idx] = ch;
                    idx += 1;
                },
            }
        }

        self.bt = try allocator.alloc.realloc(self.bt, idx);
    }

    pub fn draw(self: *Self, shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 0,
            };
        }

        props.close = self.close;

        if (self.bt.len > MAX_SIZE) {
            const newbt = try allocator.alloc.dupe(u8, self.bt[self.bt.len - MAX_SIZE ..]);
            allocator.alloc.free(self.bt);
            self.bt = newbt;
        }

        var idx: usize = 0;
        const offset = if (self.bot) 0 else props.scroll.?.maxy - props.scroll.?.value;

        if (self.shell.vm == null) {
            const shell_prompt = try self.shell.getPrompt();

            defer allocator.alloc.free(shell_prompt);

            const prompt = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ shell_prompt, self.input_buffer[0..self.input_len] });
            defer allocator.alloc.free(prompt);
            try font.draw(.{
                .shader = shader,
                .text = prompt,
                .pos = .{
                    .x = bnds.x + 6,
                    .y = bnds.y + bnds.h - font.size - 6 + offset,
                },
                .color = .{ .r = 1, .g = 1, .b = 1 },
            });
            try font.draw(.{
                .shader = shader,
                .text = "|",
                .pos = .{
                    .x = bnds.x + font.sizeText(.{
                        .text = prompt[0 .. shell_prompt.len + self.input_idx],
                    }).x,
                    .y = bnds.y + bnds.h - font.size - 6 + offset,
                },
                .color = .{ .r = 1, .g = 1, .b = 1 },
            });
            idx += 1;
        } else {
            const result = try self.shell.getVMResult();
            if (result) |result_data| {
                defer result_data.deinit();

                const start = self.bt.len;
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + result_data.data.len);

                @memcpy(self.bt[start..], result_data.data);
                try self.processBT();

                idx += 1;

                self.bot = true;
            }
        }

        var lines = std.mem.splitBackwardsScalar(u8, self.bt, '\n');

        var y = bnds.y + bnds.h - @as(f32, @floatFromInt(idx)) * font.size - 6 + offset;

        var height: f32 = @as(f32, @floatFromInt(idx)) * font.size;

        while (lines.next()) |line| {
            height += font.sizeText(.{ .text = line, .wrap = bnds.w - 30 }).y;
            if (y < bnds.y) continue;
            y -= font.sizeText(.{ .text = line, .wrap = bnds.w - 30 }).y;

            try font.draw(.{
                .shader = shader,
                .text = line,
                .pos = .{ .x = bnds.x + 6, .y = y },
                .color = .{ .r = 1, .g = 1, .b = 1 },
                .wrap = bnds.w - 30,
            });
        }

        props.scroll.?.maxy = @max(height, bnds.h) - bnds.h;
        if (self.bot) {
            self.bot = false;
            props.scroll.?.value = props.scroll.?.maxy;
        }

        return;
    }

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        if (self.shell.vm != null) {
            try self.shell.appendVMIn(@as(u8, @intCast(code)));

            return;
        }

        if (code == '\n') return;
        if (self.input_len < 255) {
            std.mem.copyBackwards(u8, self.input_buffer[self.input_idx + 1 ..], self.input_buffer[self.input_idx..255]);
            self.input_buffer[self.input_idx] = @as(u8, @intCast(code));
            self.input_len += 1;
            self.input_idx += 1;
        }
        _ = mods;
    }

    pub fn key(self: *Self, code: i32, mods: i32, down: bool) !void {
        _ = mods;
        if (!down) return;
        if (self.shell.vm != null) {
            switch (code) {
                c.GLFW_KEY_ENTER => {
                    try self.shell.appendVMIn('\n');
                },
                c.GLFW_KEY_BACKSPACE => {
                    try self.shell.appendVMIn('\x08');
                },
                else => {},
            }

            return;
        }

        self.bot = true;

        switch (code) {
            c.GLFW_KEY_ENTER => {
                if (self.shell.vm != null) {
                    try self.shell.appendVMIn('\n');

                    return;
                }

                if (self.input_len != 0 and (self.history.items.len == 0 or !std.mem.eql(u8, self.history.getLast(), self.input_buffer[0..self.input_len])))
                    try self.history.append(try allocator.alloc.dupe(u8, self.input_buffer[0..self.input_len]));

                const shell_prompt = try self.shell.getPrompt();
                defer allocator.alloc.free(shell_prompt);

                const prompt = try std.fmt.allocPrint(allocator.alloc, "\n{s}{s}\n", .{ shell_prompt, self.input_buffer[0..self.input_len] });
                defer allocator.alloc.free(prompt);
                var start = self.bt.len;

                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + prompt.len);
                @memcpy(self.bt[start .. start + prompt.len], prompt);

                const al = self.shell.run(self.input_buffer[0..self.input_len]) catch |err| {
                    const msg = @errorName(err);

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + 7);
                    @memcpy(self.bt[start..], "Error: ");

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + msg.len);
                    @memcpy(self.bt[start..], msg);

                    self.input_len = 0;
                    self.input_idx = 0;
                    self.history_idx = self.history.items.len;
                    return;
                };

                if (al.exit)
                    self.close = true;

                defer allocator.alloc.free(al.data);

                if (al.data.len == 0 and self.shell.vm == null)
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len - 1);

                if (al.clear) {
                    allocator.alloc.free(self.bt);
                    self.bt = &.{};
                } else {
                    start = self.bt.len;

                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + al.data.len);
                    @memcpy(self.bt[start..], al.data);
                }

                self.input_len = 0;
                self.input_idx = 0;
                self.history_idx = self.history.items.len;

                try self.processBT();
            },
            c.GLFW_KEY_UP => {
                if (self.history_idx > 0) {
                    self.history_idx -= 1;
                    self.input_len = @as(u8, @intCast(self.history.items[self.history_idx].len));
                    self.input_idx = self.input_len;
                    @memcpy(self.input_buffer[0..self.input_len], self.history.items[self.history_idx]);
                }
            },
            c.GLFW_KEY_DOWN => {
                if (self.history_idx < self.history.items.len) {
                    self.history_idx += 1;
                    if (self.history_idx == self.history.items.len) {
                        self.input_len = 0;
                        self.input_idx = 0;
                    } else {
                        self.input_len = @as(u8, @intCast(self.history.items[self.history_idx].len));
                        self.input_idx = self.input_len;
                        @memcpy(self.input_buffer[0..self.input_len], self.history.items[self.history_idx]);
                    }
                }
            },
            c.GLFW_KEY_LEFT => {
                if (self.input_idx != 0) {
                    self.input_idx -= 1;
                }
            },
            c.GLFW_KEY_RIGHT => {
                if (self.input_idx != self.input_len) {
                    self.input_idx += 1;
                }
            },
            c.GLFW_KEY_BACKSPACE => {
                if (self.input_idx != 0) {
                    self.input_len -= 1;
                    self.input_idx -= 1;
                    std.mem.copyForwards(u8, self.input_buffer[self.input_idx..255], self.input_buffer[self.input_idx + 1 ..]);
                }
            },
            c.GLFW_KEY_DELETE => {
                if (self.input_idx != self.input_len) {
                    std.mem.copyForwards(u8, self.input_buffer[self.input_idx..255], self.input_buffer[self.input_idx + 1 ..]);
                    self.input_len -= 1;
                }
            },
            else => {},
        }
    }

    pub fn deinit(self: *Self) void {
        // free backtrace
        allocator.alloc.free(self.bt);

        // free vm
        self.shell.deinit();

        // free history
        for (self.history.items) |item| {
            allocator.alloc.free(item);
        }
        self.history.deinit();

        // free self
        allocator.alloc.destroy(self);
    }
};

pub fn init() !Window.Data.WindowContents {
    const self = try allocator.alloc.create(CMDData);

    self.* = .{
        .bt = try std.fmt.allocPrint(allocator.alloc, "Welcome to Sh" ++ strings.EEE ++ "l\nUse help to list possible commands\n", .{}),
        .history = try std.ArrayList([]const u8).initCapacity(allocator.alloc, 32),
        .shell = .{
            .root = .home,
            .vm = null,
        },
    };

    return Window.Data.WindowContents.init(self, "cmd", "CMD", .{ .r = 0, .g = 0, .b = 0 });
}
