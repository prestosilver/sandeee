const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../shader.zig");
const shell = @import("../system/shell.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");

const MAX_SIZE = 10000;

const CMDData = struct {
    bt: []u8,
    text: std.ArrayList(u8),
    shell: shell.Shell,
};

pub fn drawCmd(cself: *[]u8, batch: *sb.SpriteBatch, shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*CMDData, cself);

    if (self.bt.len > MAX_SIZE) {
        var newbt = allocator.alloc.alloc(u8, MAX_SIZE) catch self.bt;
        std.mem.copy(u8, newbt, self.bt[self.bt.len - MAX_SIZE ..]);

        allocator.alloc.free(self.bt);

        self.bt = newbt;
    }

    var idx: usize = 0;

    if (self.shell.vm == null) {
        var prompt = std.fmt.allocPrint(allocator.alloc, "$ {s}", .{self.text.items}) catch "";
        defer allocator.alloc.free(prompt);
        font.draw(batch, shader, prompt, vecs.newVec2(bnds.x + 6, bnds.y + bnds.h - font.size - 6), col.newColor(1, 1, 1, 1));
        idx += 1;
    } else {
        var result = self.shell.updateVM() catch null;
        var start = self.bt.len;
        if (result != null) {
            self.bt = allocator.alloc.realloc(self.bt, self.bt.len + result.?.data.items.len) catch self.bt;
            std.mem.copy(u8, self.bt[start..], result.?.data.items);
            result.?.data.deinit();
        } else {
            self.bt = allocator.alloc.realloc(self.bt, self.bt.len + self.shell.vm.?.out.items.len) catch self.bt;
            std.mem.copy(u8, self.bt[start..], self.shell.vm.?.out.items);
            self.shell.vm.?.out.clearAndFree();
        }
    }

    var lines = std.mem.splitBackwards(u8, self.bt, "\n");

    while (lines.next()) |line| {
        var y = bnds.y + bnds.h - @intToFloat(f32, idx + 1) * font.size - 6;

        font.draw(batch, shader, line, vecs.newVec2(bnds.x + 6, y), col.newColor(1, 1, 1, 1));

        idx += 1;
    }

    return;
}

pub fn keyCmd(cself: *[]u8, key: i32, mods: i32) void {
    var self = @ptrCast(*CMDData, cself);

    if (self.shell.vm != null) return;

    switch (key) {
        c.GLFW_KEY_A...c.GLFW_KEY_Z => {
            if ((mods & c.GLFW_MOD_SHIFT) != 0) {
                self.text.append(@intCast(u8, key - c.GLFW_KEY_A) + 'A') catch {};
            } else {
                self.text.append(@intCast(u8, key - c.GLFW_KEY_A) + 'a') catch {};
            }
        },
        c.GLFW_KEY_0...c.GLFW_KEY_9 => {
            if ((mods & c.GLFW_MOD_SHIFT) != 0) {
                self.text.append(")!@#$%^&*("[@intCast(u8, key - c.GLFW_KEY_0)]) catch {};
            } else {
                self.text.append(@intCast(u8, key - c.GLFW_KEY_0) + '0') catch {};
            }
        },
        c.GLFW_KEY_SPACE => {
            self.text.append(' ') catch {};
        },
        c.GLFW_KEY_PERIOD => {
            self.text.append('.') catch {};
        },
        c.GLFW_KEY_COMMA => {
            self.text.append(',') catch {};
        },
        c.GLFW_KEY_SLASH => {
            self.text.append('/') catch {};
        },
        c.GLFW_KEY_ENTER => {
            var start = self.bt.len;
            self.bt = allocator.alloc.realloc(self.bt, self.bt.len + self.text.items.len + 4) catch self.bt;
            std.mem.copy(u8, self.bt[start .. start + 3], "\n$ ");
            std.mem.copy(u8, self.bt[start + 3 .. self.bt.len - 1], self.text.items);
            self.bt[self.bt.len - 1] = '\n';

            var command = std.ArrayList(u8).init(allocator.alloc);
            defer command.deinit();

            for (self.text.items) |char| {
                if (char == ' ') {
                    break;
                } else {
                    command.append(char) catch {};
                }
            }

            var al = self.shell.run(command.items, self.text.items) catch |err| {
                const msg = @errorName(err);

                start = self.bt.len;
                self.bt = allocator.alloc.realloc(self.bt, self.bt.len + 7) catch self.bt;
                std.mem.copy(u8, self.bt[start..], "Error: ");

                start = self.bt.len;
                self.bt = allocator.alloc.realloc(self.bt, self.bt.len + msg.len) catch self.bt;
                std.mem.copy(u8, self.bt[start..], msg);

                self.text.clearAndFree();
                return;
            };

            if (al.clear) {
                allocator.alloc.free(self.bt);
                self.bt = allocator.alloc.alloc(u8, 0) catch undefined;
            } else {
                start = self.bt.len;

                self.bt = allocator.alloc.realloc(self.bt, self.bt.len + al.data.items.len) catch self.bt;
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

fn deleteCmd(cself: *[]u8) void {
    var self = @ptrCast(*CMDData, cself);
    allocator.alloc.free(self.bt);
    self.text.deinit();
    if (self.shell.vm != null) {
        self.shell.vm.?.destroy();
    }
    allocator.alloc.destroy(self);
}

pub fn new() win.WindowContents {
    const self = allocator.alloc.create(CMDData) catch undefined;

    self.text = std.ArrayList(u8).init(allocator.alloc);
    self.bt = std.fmt.allocPrint(allocator.alloc, "Welcome to ShEEEl", .{}) catch undefined;

    self.shell.root = files.root;
    self.shell.vm = null;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .drawFn = drawCmd,
        .keyFn = keyCmd,
        .deleteFn = deleteCmd,
        .name = "CMD",
        .kind = "cmd",
        .clearColor = col.newColor(0, 0, 0, 1),
    };
}
