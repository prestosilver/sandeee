const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const batch = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const shell = @import("../system/shell.zig");
const files = @import("../system/files.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const c = @import("../c.zig");

const MAX_SIZE = 10000;

pub const CMDData = struct {
    const Self = @This();

    bt: []u8,
    inputBuffer: [256]u8 = undefined,
    inputLen: u8 = 0,
    inputIdx: u8 = 0,

    history: std.ArrayList([]const u8),
    historyIdx: usize = 0,
    shell: shell.Shell,
    bot: bool = false,

    pub fn processBT(self: *Self) !void {
        const oldbt = self.bt;
        defer allocator.alloc.free(oldbt);

        self.bt = try allocator.alloc.alloc(u8, self.bt.len);
        var idx: usize = 0;

        for (oldbt) |ch| {
            switch (ch) {
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

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 0,
            };
        }

        if (self.bt.len > MAX_SIZE) {
            const newbt = try allocator.alloc.dupe(u8, self.bt[self.bt.len - MAX_SIZE ..]);
            allocator.alloc.free(self.bt);
            self.bt = newbt;
        }

        var idx: usize = 0;
        const offset = if (self.bot) 0 else props.scroll.?.maxy - props.scroll.?.value;

        if (self.shell.vm == null) {
            const shellPrompt = self.shell.getPrompt();
            defer allocator.alloc.free(shellPrompt);
            const prompt = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ shellPrompt, self.inputBuffer[0..self.inputLen] });
            defer allocator.alloc.free(prompt);
            try font.draw(.{
                .shader = shader,
                .text = prompt,
                .pos = vecs.newVec2(bnds.x + 6, bnds.y + bnds.h - font.size - 6 + offset),
                .color = col.newColor(1, 1, 1, 1),
            });
            try font.draw(.{
                .shader = shader,
                .text = "|",
                .pos = vecs.newVec2(
                    bnds.x + font.sizeText(.{
                        .text = prompt[0 .. shellPrompt.len + self.inputIdx],
                    }).x,
                    bnds.y + bnds.h - font.size - 6 + offset,
                ),
                .color = col.newColor(1, 1, 1, 1),
            });
            idx += 1;
        } else {
            const start = self.bt.len;

            const result = try self.shell.getVMResult();
            if (result != null) {
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + result.?.data.len);
                @memcpy(self.bt[start..], result.?.data);
                allocator.alloc.free(result.?.data);
                try self.processBT();
                idx += 1;
            } else {
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len);
                @memcpy(self.bt[start..], "");
                try self.processBT();
            }
            self.bot = true;
        }

        var lines = std.mem.splitBackwards(u8, self.bt, "\n");

        var y = bnds.y + bnds.h - @as(f32, @floatFromInt(idx)) * font.size - 6 + offset;

        var height: f32 = @as(f32, @floatFromInt(idx)) * font.size;

        while (lines.next()) |line| {
            height += font.sizeText(.{ .text = line, .wrap = bnds.w - 30 }).y;
            if (y < bnds.y) continue;
            y -= font.sizeText(.{ .text = line, .wrap = bnds.w - 30 }).y;

            try font.draw(.{
                .shader = shader,
                .text = line,
                .pos = vecs.newVec2(bnds.x + 6, y),
                .color = col.newColor(1, 1, 1, 1),
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
        if (self.inputLen < 255) {
            std.mem.copyBackwards(u8, self.inputBuffer[self.inputIdx + 1 ..], self.inputBuffer[self.inputIdx..255]);
            self.inputBuffer[self.inputIdx] = @as(u8, @intCast(code));
            self.inputLen += 1;
            self.inputIdx += 1;
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

                if (self.inputLen != 0 and (self.history.items.len == 0 or !std.mem.eql(u8, self.history.getLast(), self.inputBuffer[0..self.inputLen])))
                    try self.history.append(try allocator.alloc.dupe(u8, self.inputBuffer[0..self.inputLen]));

                const shellPrompt = self.shell.getPrompt();
                defer allocator.alloc.free(shellPrompt);
                const prompt = try std.fmt.allocPrint(allocator.alloc, "\n{s}{s}\n", .{ shellPrompt, self.inputBuffer[0..self.inputLen] });
                defer allocator.alloc.free(prompt);
                var start = self.bt.len;

                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + prompt.len);
                @memcpy(self.bt[start .. start + prompt.len], prompt);

                const al = self.shell.run(self.inputBuffer[0..self.inputLen]) catch |err| {
                    const msg = @errorName(err);

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + 7);
                    @memcpy(self.bt[start..], "Error: ");

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + msg.len);
                    @memcpy(self.bt[start..], msg);

                    self.inputLen = 0;
                    self.inputIdx = 0;
                    self.historyIdx = self.history.items.len;
                    return;
                };

                defer allocator.alloc.free(al.data);

                if (al.data.len == 0 and self.shell.vm == null)
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len - 1);

                if (al.clear) {
                    allocator.alloc.free(self.bt);
                    self.bt = try allocator.alloc.alloc(u8, 0);
                } else {
                    start = self.bt.len;

                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + al.data.len);
                    @memcpy(self.bt[start..], al.data);
                }

                self.inputLen = 0;
                self.inputIdx = 0;
                self.historyIdx = self.history.items.len;

                try self.processBT();
            },
            c.GLFW_KEY_UP => {
                if (self.historyIdx > 0) {
                    self.historyIdx -= 1;
                    self.inputLen = @as(u8, @intCast(self.history.items[self.historyIdx].len));
                    self.inputIdx = self.inputLen;
                    @memcpy(self.inputBuffer[0..self.inputLen], self.history.items[self.historyIdx]);
                }
            },
            c.GLFW_KEY_DOWN => {
                if (self.historyIdx < self.history.items.len) {
                    self.historyIdx += 1;
                    if (self.historyIdx == self.history.items.len) {
                        self.inputLen = 0;
                        self.inputIdx = 0;
                    } else {
                        self.inputLen = @as(u8, @intCast(self.history.items[self.historyIdx].len));
                        self.inputIdx = self.inputLen;
                        @memcpy(self.inputBuffer[0..self.inputLen], self.history.items[self.historyIdx]);
                    }
                }
            },
            c.GLFW_KEY_LEFT => {
                if (self.inputIdx != 0) {
                    self.inputIdx -= 1;
                }
            },
            c.GLFW_KEY_RIGHT => {
                if (self.inputIdx != self.inputLen) {
                    self.inputIdx += 1;
                }
            },
            c.GLFW_KEY_BACKSPACE => {
                if (self.inputIdx != 0) {
                    self.inputLen -= 1;
                    self.inputIdx -= 1;
                    std.mem.copyForwards(u8, self.inputBuffer[self.inputIdx..255], self.inputBuffer[self.inputIdx + 1 ..]);
                }
            },
            c.GLFW_KEY_DELETE => {
                if (self.inputIdx != self.inputLen) {
                    std.mem.copyForwards(u8, self.inputBuffer[self.inputIdx..255], self.inputBuffer[self.inputIdx + 1 ..]);
                    self.inputLen -= 1;
                }
            },
            else => {},
        }
    }

    pub fn click(_: *Self, _: vecs.Vector2, _: vecs.Vector2, _: ?i32) !void {}
    pub fn scroll(_: *Self, _: f32, _: f32) !void {}
    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}
    pub fn moveResize(_: *Self, _: *rect.Rectangle) !void {}

    pub fn deinit(self: *Self) !void {
        // free backtrace
        allocator.alloc.free(self.bt);

        // free vm
        try self.shell.deinit();

        // free history
        for (self.history.items) |item| {
            allocator.alloc.free(item);
        }
        self.history.deinit();

        // free self
        allocator.alloc.destroy(self);
    }
};

pub fn new() !win.WindowContents {
    const self = try allocator.alloc.create(CMDData);

    self.* = .{
        .bt = try std.fmt.allocPrint(allocator.alloc, "Welcome to Sh\x82\x82\x82l\nUse help to list possible commands\n", .{}),
        .history = try std.ArrayList([]const u8).initCapacity(allocator.alloc, 32),
        .shell = .{
            .root = files.home,
            .vm = null,
        },
    };

    return win.WindowContents.init(self, "cmd", "CMD", col.newColor(0, 0, 0, 1));
}
