const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const batch = @import("../../util/spritebatch.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const logout_state = @import("../../states/logout.zig");
const events = @import("../../util/events.zig");
const window_events = @import("../../events/window.zig");
const system_events = @import("../../events/system.zig");
const gfx = @import("../../util/graphics.zig");
const spr = @import("../../drawers/sprite2d.zig");
const c = @import("../../c.zig");

pub const PopupQuit = struct {
    const Self = @This();

    done: ?u32 = null,
    icons: [2]spr.Sprite,
    shader: *shd.Shader,

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        try batch.SpriteBatch.instance.draw(spr.Sprite, &self.icons[0], self.shader, .{ .x = bnds.x + 55, .y = bnds.y });
        try batch.SpriteBatch.instance.draw(spr.Sprite, &self.icons[1], self.shader, .{ .x = bnds.x + 231, .y = bnds.y });

        const single_width = bnds.w / 2;
        const sd_width = font.sizeText(.{
            .text = "Shutdown",
        }).x;
        const sd_x = (single_width - sd_width) / 2;

        const rs_width = font.sizeText(.{
            .text = "Restart",
        }).x;
        const rs_x = single_width + (single_width - rs_width) / 2;

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(vecs.Vector2{ .x = sd_x, .y = 64 }),
            .text = "Shutdown",
        });

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(vecs.Vector2{ .x = rs_x, .y = 64 }),
            .text = "Restart",
        });

        if (self.done) |rets| {
            switch (rets) {
                0 => {
                    logout_state.target = .Bios;
                    try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                        .target_state = .Logout,
                    });
                },
                1 => {
                    logout_state.target = .Quit;
                    try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                        .target_state = .Logout,
                    });
                },
                else => return,
            }
        }
    }

    pub fn click(self: *Self, mousepos: vecs.Vector2) !void {
        if (mousepos.x < 175) {
            self.done = 1;
        } else {
            self.done = 0;
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};
