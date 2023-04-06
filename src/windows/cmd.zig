const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const shell = @import("../system/shell.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");

// TODO: Scrolling

const MAX_SIZE = 10000;

const CMDData = struct {
    const Self = @This();

    bt: []u8,
    text: std.ArrayList(u8),
    shell: shell.Shell,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) !void {
        if (self.bt.len > MAX_SIZE) {
            var newbt = try allocator.alloc.alloc(u8, MAX_SIZE);
            std.mem.copy(u8, newbt, self.bt[self.bt.len - MAX_SIZE ..]);

            allocator.alloc.free(self.bt);

            self.bt = newbt;
        }

        var idx: usize = 0;

        if (self.shell.vm == null) {
            var shellPrompt = self.shell.getPrompt();
            defer allocator.alloc.free(shellPrompt);
            var prompt = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ shellPrompt, self.text.items });
            defer allocator.alloc.free(prompt);
            try font.draw(.{
                .batch = batch,
                .shader = shader,
                .text = prompt,
                .pos = vecs.newVec2(bnds.x + 6, bnds.y + bnds.h - font.size - 6),
                .color = col.newColor(1, 1, 1, 1),
            });
            idx += 1;
        } else {
            var result = try self.shell.updateVM();
            var start = self.bt.len;
            if (result != null) {
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + result.?.data.items.len);
                std.mem.copy(u8, self.bt[start..], result.?.data.items);
                result.?.data.deinit();
            } else {
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + self.shell.vm.?.out.items.len);
                std.mem.copy(u8, self.bt[start..], self.shell.vm.?.out.items);
                self.shell.vm.?.out.clearAndFree();
            }
        }

        var lines = std.mem.splitBackwards(u8, self.bt, "\n");

        var y = bnds.y + bnds.h - @intToFloat(f32, idx) * font.size - 6;

        while (lines.next()) |line| {
            y -= font.sizeText(.{ .text = line, .wrap = bnds.w - 12 }).y;

            try font.draw(.{
                .batch = batch,
                .shader = shader,
                .text = line,
                .pos = vecs.newVec2(bnds.x + 6, y),
                .color = col.newColor(1, 1, 1, 1),
                .wrap = bnds.w - 12,
            });

            if (y < bnds.y) return;
        }

        return;
    }

    pub fn key(self: *Self, code: i32, mods: i32) !void {
        if (self.shell.vm != null) return;

        switch (code) {
            c.GLFW_KEY_A...c.GLFW_KEY_Z => {
                if ((mods & c.GLFW_MOD_SHIFT) != 0) {
                    try self.text.append(@intCast(u8, code - c.GLFW_KEY_A) + 'A');
                } else {
                    try self.text.append(@intCast(u8, code - c.GLFW_KEY_A) + 'a');
                }
            },
            c.GLFW_KEY_0...c.GLFW_KEY_9 => {
                if ((mods & c.GLFW_MOD_SHIFT) != 0) {
                    try self.text.append(")!@#$%^&*("[@intCast(u8, code - c.GLFW_KEY_0)]);
                } else {
                    try self.text.append(@intCast(u8, code - c.GLFW_KEY_0) + '0');
                }
            },
            c.GLFW_KEY_SPACE => {
                try self.text.append(' ');
            },
            c.GLFW_KEY_PERIOD => {
                try self.text.append('.');
            },
            c.GLFW_KEY_COMMA => {
                try self.text.append(',');
            },
            c.GLFW_KEY_SLASH => {
                try self.text.append('/');
            },
            c.GLFW_KEY_ENTER => {
                var shellPrompt = self.shell.getPrompt();
                defer allocator.alloc.free(shellPrompt);
                var prompt = try std.fmt.allocPrint(allocator.alloc, "\n{s}{s}\n", .{ shellPrompt, self.text.items });
                defer allocator.alloc.free(prompt);
                var start = self.bt.len;
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + prompt.len);
                std.mem.copy(u8, self.bt[start .. start + prompt.len], prompt);

                var command = self.text.items;
                if (std.mem.indexOf(u8, self.text.items, " ")) |size| {
                    command.len = size;
                }

                var al = self.shell.run(command, self.text.items) catch |err| {
                    const msg = @errorName(err);

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + 7);
                    std.mem.copy(u8, self.bt[start..], "Error: ");

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + msg.len);
                    std.mem.copy(u8, self.bt[start..], msg);

                    self.text.clearAndFree();
                    return;
                };

                if (al.data.items.len == 0 and self.shell.vm == null)
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len - 1);

                if (al.clear) {
                    allocator.alloc.free(self.bt);
                    self.bt = try allocator.alloc.alloc(u8, 0);
                } else {
                    start = self.bt.len;

                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + al.data.items.len);
                    std.mem.copy(u8, self.bt[start..], al.data.items);
                }
                al.data.deinit();

                self.text.clearAndFree();
            },
            c.GLFW_KEY_BACKSPACE => {
                _ = self.text.popOrNull();
            },
            else => {},
        }
    }

    pub fn click(_: *Self, _: vecs.Vector2, _: vecs.Vector2, _: i32) !void {}
    pub fn scroll(_: *Self, _: f32, _: f32) !void {}
    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}

    pub fn deinit(self: *Self) !void {
        allocator.alloc.free(self.bt);
        self.text.deinit();
        if (self.shell.vm) |*vm| {
            try vm.deinit();
        }
        allocator.alloc.destroy(self);
    }
};

pub fn new() !win.WindowContents {
    const self = try allocator.alloc.create(CMDData);

    self.text = std.ArrayList(u8).init(allocator.alloc);
    self.bt = try std.fmt.allocPrint(allocator.alloc, "Welcome to ShEEEl", .{});

    self.shell.root = files.home;
    self.shell.vm = null;

    return win.WindowContents.init(self, "cmd", "CMD", col.newColor(0, 0, 0, 1));
}
