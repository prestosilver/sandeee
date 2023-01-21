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

const MAX_SIZE = 5000;

const CMDData = struct {
    bt: std.ArrayList(u8),
    text: std.ArrayList(u8),
    shell: shell.Shell,
};

pub fn drawCmd(cself: *[]u8, batch: *sb.SpriteBatch, shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*CMDData, cself);

    while (self.bt.items.len > MAX_SIZE) {
        _ = self.bt.orderedRemove(0);
    }

    var lines = std.ArrayList(std.ArrayList(u8)).init(allocator.alloc);
    defer lines.deinit();
    var line = std.ArrayList(u8).init(allocator.alloc);

    for (self.bt.items) |char| {
        switch (char) {
            '\n' => {
                lines.append(line) catch {};
                line = std.ArrayList(u8).init(allocator.alloc);
            },
            else => {
                line.append(char) catch {};
            },
        }
    }

    lines.append(line) catch {};
    if (self.shell.vm != null) {
        var result = self.shell.updateVM();
        if (result != null) {
            self.bt.appendSlice(result.?.data.items) catch {};
            result.?.data.deinit();
        } else {
            self.bt.appendSlice(self.shell.vm.?.out.items) catch {};
            self.shell.vm.?.out.clearAndFree();
        }
    } else {
        line = std.ArrayList(u8).init(allocator.alloc);

        line.appendSlice("$ ") catch {};
        line.appendSlice(self.text.items) catch {};
        line.appendSlice("_") catch {};

        lines.append(line) catch {};
    }

    var height = font.size * @intToFloat(f32, lines.items.len);

    if (bnds.h < height) {
        height = bnds.h;
    }

    for (lines.items) |_, idx| {
        var i = lines.items[lines.items.len - idx - 1];
        var y = bnds.y + height - @intToFloat(f32, idx + 1) * font.size - 6;

        font.draw(batch, shader, i.items, vecs.newVec2(bnds.x + 6, y), col.newColor(1, 1, 1, 1));

        i.deinit();
    }
}

pub fn keyCmd(cself: *[]u8, key: i32, mods: i32) void {
    var self = @ptrCast(*CMDData, cself);

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
            self.bt.appendSlice("\n$ ") catch {};
            self.bt.appendSlice(self.text.items) catch {};

            var command = std.ArrayList(u8).init(allocator.alloc);
            defer command.deinit();

            for (self.text.items) |char| {
                if (char == ' ') {
                    break;
                } else {
                    command.append(char) catch {};
                }
            }

            var al = self.shell.run(command.items, self.text.items);
            if (al.clear) {
                self.bt.clearAndFree();
            } else {
                if (al.data.items.len != 0 and self.bt.getLast() != '\n') self.bt.append('\n') catch {};

                self.bt.appendSlice(al.data.items) catch {};
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
    self.bt.deinit();
    self.text.deinit();
    if (self.shell.vm != null) {
        self.shell.vm.?.destroy();
    }
    allocator.alloc.destroy(self);
}

pub fn new() win.WindowContents {
    const self = allocator.alloc.create(CMDData) catch undefined;

    self.text = std.ArrayList(u8).init(allocator.alloc);
    self.bt = std.ArrayList(u8).init(allocator.alloc);

    self.bt.appendSlice("Welcome to ShEEEl") catch {};
    self.shell.root = files.root;
    self.shell.vm = null;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .drawFn = drawCmd,
        .keyFn = keyCmd,
        .deleteFn = deleteCmd,
        .name = "CMD",
        .clearColor = col.newColor(0, 0, 0, 1),
    };
}
