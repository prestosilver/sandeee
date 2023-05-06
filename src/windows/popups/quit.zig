const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const sb = @import("../../util/spritebatch.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const events = @import("../../util/events.zig");
const windowEvs = @import("../../events/window.zig");
const systemEvs = @import("../../events/system.zig");
const gfx = @import("../../util/graphics.zig");
const c = @import("../../c.zig");

pub const PopupQuit = struct {
    const Self = @This();

    lol: u32 = 0,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        _ = self;
        try font.draw(.{
            .batch = batch,
            .shader = shader,
            .pos = bnds.location(),
            .text = "Quit",
        });
    }

    pub fn key(self: *Self, keycode: c_int, _: c_int, down: bool) !void {
        if (!down) return;

        _ = self;
        _ = keycode;
    }

    pub fn char(_: *Self, _: u32, _: i32) !void {}

    pub fn click(_: *Self, mousepos: vecs.Vector2) !void {
        if (mousepos.x < 100) {
            c.glfwSetWindowShouldClose(gfx.gContext.window, 1);
        } else {
            events.em.sendEvent(systemEvs.EventStateChange{
                .targetState = .Disks,
            });
        }
    }

    pub fn deinit(self: *Self) !void {
        allocator.alloc.destroy(self);
    }
};
