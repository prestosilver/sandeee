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
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const c = @import("../c.zig");

const MAX_SIZE = 10000;

pub const CMDData = struct {
    const Self = @This();

    bt: []u8,
    inputBuffer: [256]u8 = undefined,
    inputIdx: u8 = 0,
    history: std.ArrayList([]const u8),
    historyIdx: usize = 0,
    shell: shell.Shell,
    bot: bool = false,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
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
            const prompt = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ shellPrompt, self.inputBuffer[0..self.inputIdx] });
            defer allocator.alloc.free(prompt);
            try font.draw(.{
                .batch = batch,
                .shader = shader,
                .text = prompt,
                .pos = vecs.newVec2(bnds.x + 6, bnds.y + bnds.h - font.size - 6 + offset),
                .color = col.newColor(1, 1, 1, 1),
            });
            idx += 1;
        } else {
            const start = self.bt.len;

            const result = try self.shell.updateVM();
            if (result != null) {
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + result.?.data.items.len);
                std.mem.copy(u8, self.bt[start..], result.?.data.items);
                result.?.data.deinit();
                idx += 1;
            } else {
                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + self.shell.vm.?.out.items.len);
                std.mem.copy(u8, self.bt[start..], self.shell.vm.?.out.items);
                self.shell.vm.?.out.clearAndFree();
            }
            self.bot = true;
        }

        var lines = std.mem.splitBackwards(u8, self.bt, "\n");

        var y = bnds.y + bnds.h - @as(f32, @floatFromInt(idx)) * font.size - 6 + offset;

        var height: f32 = @as(f32, @floatFromInt(idx)) * font.size;

        while (lines.next()) |line| {
            height += font.sizeText(.{ .text = line, .wrap = bnds.w - 12 }).y;
            if (y < bnds.y) continue;
            y -= font.sizeText(.{ .text = line, .wrap = bnds.w - 12 }).y;

            try font.draw(.{
                .batch = batch,
                .shader = shader,
                .text = line,
                .pos = vecs.newVec2(bnds.x + 6, y),
                .color = col.newColor(1, 1, 1, 1),
                .wrap = bnds.w - 12,
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
            try self.shell.vm.?.input.append(@as(u8, @intCast(code)));

            return;
        }

        if (code == '\n') return;
        if (self.inputIdx < 255) {
            self.inputBuffer[self.inputIdx] = @as(u8, @intCast(code));
            self.inputIdx += 1;
        }
        _ = mods;
    }

    pub fn key(self: *Self, code: i32, mods: i32, down: bool) !void {
        _ = mods;
        if (self.shell.vm != null) return;
        if (!down) return;

        self.bot = true;

        switch (code) {
            c.GLFW_KEY_ENTER => {
                if (self.history.items.len == 0 or !std.mem.eql(u8, self.history.getLast(), self.inputBuffer[0..self.inputIdx]))
                    try self.history.append(try allocator.alloc.dupe(u8, self.inputBuffer[0..self.inputIdx]));

                const shellPrompt = self.shell.getPrompt();
                defer allocator.alloc.free(shellPrompt);
                const prompt = try std.fmt.allocPrint(allocator.alloc, "\n{s}{s}\n", .{ shellPrompt, self.inputBuffer[0..self.inputIdx] });
                defer allocator.alloc.free(prompt);
                var start = self.bt.len;

                self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + prompt.len);
                std.mem.copy(u8, self.bt[start .. start + prompt.len], prompt);

                const al = self.shell.run(self.inputBuffer[0..self.inputIdx]) catch |err| {
                    const msg = @errorName(err);

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + 7);
                    std.mem.copy(u8, self.bt[start..], "Error: ");

                    start = self.bt.len;
                    self.bt = try allocator.alloc.realloc(self.bt, self.bt.len + msg.len);
                    std.mem.copy(u8, self.bt[start..], msg);

                    self.inputIdx = 0;
                    self.historyIdx = self.history.items.len;
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

                self.inputIdx = 0;
                self.historyIdx = self.history.items.len;
            },
            c.GLFW_KEY_UP => {
                if (self.historyIdx > 0) {
                    self.historyIdx -= 1;
                    self.inputIdx = @as(u8, @intCast(self.history.items[self.historyIdx].len));
                    @memcpy(self.inputBuffer[0..self.inputIdx], self.history.items[self.historyIdx]);
                }
            },
            c.GLFW_KEY_DOWN => {
                if (self.historyIdx < self.history.items.len) {
                    self.historyIdx += 1;
                    if (self.historyIdx == self.history.items.len) {
                        self.inputIdx = 0;
                    } else {
                        self.inputIdx = @as(u8, @intCast(self.history.items[self.historyIdx].len));
                        @memcpy(self.inputBuffer[0..self.inputIdx], self.history.items[self.historyIdx]);
                    }
                }
            },
            c.GLFW_KEY_BACKSPACE => {
                if (self.inputIdx != 0)
                    self.inputIdx -= 1;
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
        if (self.shell.vm) |*vm| try vm.deinit();

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
