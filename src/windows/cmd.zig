const std = @import("std");
const glfw = @import("glfw");

const Windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

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

    history: std.array_list.Managed([]const u8),
    history_idx: usize = 0,
    shell: Shell,
    bot: bool = false,
    close: bool = false,

    pub fn processBT(self: *Self) !void {
        const oldbt = self.bt;
        defer allocator.free(oldbt);

        self.bt = try allocator.alloc(u8, self.bt.len);
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

        self.bt = try allocator.realloc(self.bt, idx);
    }

    pub fn draw(self: *Self, shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 0,
            };
        }

        props.close = self.close;

        if (self.bt.len > MAX_SIZE) {
            const newbt = try allocator.dupe(u8, self.bt[self.bt.len - MAX_SIZE ..]);
            allocator.free(self.bt);
            self.bt = newbt;
        }

        var idx: usize = 0;
        const offset = if (self.bot) 0 else props.scroll.?.maxy - props.scroll.?.value;

        if (self.shell.vm == null) {
            const shell_prompt = try self.shell.getPrompt();

            defer allocator.free(shell_prompt);

            const prompt = try std.fmt.allocPrint(allocator, "{s}{s}", .{ shell_prompt, self.input_buffer[0..self.input_len] });
            defer allocator.free(prompt);
            try font.draw(.{
                .shader = shader,
                .text = prompt,
                .pos = .{
                    .x = bnds.x + 6,
                    .y = bnds.y + bnds.h - font.size - 6 + offset,
                },
                .color = .{ .r = 1, .g = 1, .b = 1 },
                .wrap = bnds.w - 30,
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
                self.bt = try allocator.realloc(self.bt, self.bt.len + result_data.data.len);

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
                glfw.KeyEnter => {
                    try self.shell.appendVMIn('\n');
                },
                glfw.KeyBackspace => {
                    try self.shell.appendVMIn('\x08');
                },
                else => {},
            }

            return;
        }

        self.bot = true;

        switch (code) {
            glfw.KeyEnter => {
                if (self.shell.vm != null) {
                    try self.shell.appendVMIn('\n');

                    return;
                }

                if (self.input_len != 0 and (self.history.items.len == 0 or !std.mem.eql(u8, self.history.getLast(), self.input_buffer[0..self.input_len])))
                    try self.history.append(try allocator.dupe(u8, self.input_buffer[0..self.input_len]));

                const shell_prompt = try self.shell.getPrompt();
                defer allocator.free(shell_prompt);

                const prompt = try std.fmt.allocPrint(allocator, "\n{s}{s}\n", .{ shell_prompt, self.input_buffer[0..self.input_len] });
                defer allocator.free(prompt);
                var start = self.bt.len;

                self.bt = try allocator.realloc(self.bt, self.bt.len + prompt.len);
                @memcpy(self.bt[start .. start + prompt.len], prompt);

                const al = self.shell.run(self.input_buffer[0..self.input_len]) catch |err| {
                    const msg = @errorName(err);

                    start = self.bt.len;
                    self.bt = try allocator.realloc(self.bt, self.bt.len + 7);
                    @memcpy(self.bt[start..], "Error: ");

                    start = self.bt.len;
                    self.bt = try allocator.realloc(self.bt, self.bt.len + msg.len);
                    @memcpy(self.bt[start..], msg);

                    self.input_len = 0;
                    self.input_idx = 0;
                    self.history_idx = self.history.items.len;
                    return;
                };

                if (al.exit)
                    self.close = true;

                defer allocator.free(al.data);

                if (al.data.len == 0 and self.shell.vm == null)
                    self.bt = try allocator.realloc(self.bt, self.bt.len - 1);

                if (al.clear) {
                    allocator.free(self.bt);
                    self.bt = &.{};
                } else {
                    start = self.bt.len;

                    self.bt = try allocator.realloc(self.bt, self.bt.len + al.data.len);
                    @memcpy(self.bt[start..], al.data);
                }

                self.input_len = 0;
                self.input_idx = 0;
                self.history_idx = self.history.items.len;

                try self.processBT();
            },
            glfw.KeyUp => {
                if (self.history_idx > 0) {
                    self.history_idx -= 1;
                    self.input_len = @as(u8, @intCast(self.history.items[self.history_idx].len));
                    self.input_idx = self.input_len;
                    @memcpy(self.input_buffer[0..self.input_len], self.history.items[self.history_idx]);
                }
            },
            glfw.KeyDown => {
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
            glfw.KeyLeft => {
                if (self.input_idx != 0) {
                    self.input_idx -= 1;
                }
            },
            glfw.KeyRight => {
                if (self.input_idx != self.input_len) {
                    self.input_idx += 1;
                }
            },
            glfw.KeyBackspace => {
                if (self.input_idx != 0) {
                    self.input_len -= 1;
                    self.input_idx -= 1;
                    std.mem.copyForwards(u8, self.input_buffer[self.input_idx..255], self.input_buffer[self.input_idx + 1 ..]);
                }
            },
            glfw.KeyDelete => {
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
        allocator.free(self.bt);

        // free vm
        self.shell.deinit();

        // free history
        for (self.history.items) |item| {
            allocator.free(item);
        }
        self.history.deinit();

        // free self
        allocator.destroy(self);
    }
};

pub fn init() !Window.Data.WindowContents {
    const self = try allocator.create(CMDData);

    self.* = .{
        .bt = try std.fmt.allocPrint(allocator, "Welcome to Sh" ++ strings.EEE ++ "l\nUse help to list possible commands\n", .{}),
        .history = try .initCapacity(allocator, 32),
        .shell = .{
            .root = .home,
            .vm = null,
        },
    };

    return Window.Data.WindowContents.init(self, "cmd", "CMD", .{ .r = 0, .g = 0, .b = 0 });
}
