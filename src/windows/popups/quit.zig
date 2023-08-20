const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const batch = @import("../../util/spritebatch.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const logoutState = @import("../../states/logout.zig");
const events = @import("../../util/events.zig");
const windowEvs = @import("../../events/window.zig");
const systemEvs = @import("../../events/system.zig");
const gfx = @import("../../util/graphics.zig");
const spr = @import("../../drawers/sprite2d.zig");
const c = @import("../../c.zig");

pub const PopupQuit = struct {
    const Self = @This();

    done: ?u32 = null,
    icons: [2]spr.Sprite,
    shader: *shd.Shader,

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        try batch.SpriteBatch.instance.draw(spr.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 55, bnds.y, 0));
        try batch.SpriteBatch.instance.draw(spr.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x + 231, bnds.y, 0));

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(vecs.Vector2{ .x = 0, .y = 64 }),
            .text = "Shutdown",
        });

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(vecs.Vector2{ .x = 175, .y = 64 }),
            .text = "Restart",
        });

        if (self.done) |rets| {
            switch (rets) {
                0 => {
                    logoutState.target = .Bios;
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Logout,
                    });
                },
                1 => {
                    logoutState.target = .Quit;
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Logout,
                    });
                },
                else => return,
            }
        }
    }

    pub fn key(self: *Self, keycode: c_int, _: c_int, down: bool) !void {
        if (!down) return;

        _ = self;
        _ = keycode;
    }

    pub fn char(_: *Self, _: u32, _: i32) !void {}

    pub fn click(self: *Self, mousepos: vecs.Vector2) !void {
        if (mousepos.x < 175) {
            self.done = 1;
        } else {
            self.done = 0;
        }
    }

    pub fn deinit(self: *Self) !void {
        allocator.alloc.destroy(self);
    }
};
