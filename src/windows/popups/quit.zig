const std = @import("std");
const c = @import("../../c.zig");

const drawers = @import("../../drawers.zig");
const system = @import("../../system.zig");
const events = @import("../../events.zig");
const states = @import("../../states.zig");
const math = @import("../../math.zig");
const util = @import("../../util.zig");

const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;

const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;
const system_events = events.system;

const LogoutState = states.Logout;

pub const PopupQuit = struct {
    const Self = @This();

    done: ?u32 = null,
    icons: [2]Sprite,
    shader: *Shader,

    pub fn draw(self: *Self, shader: *Shader, bnds: Rect, font: *Font) !void {
        try SpriteBatch.global.draw(Sprite, &self.icons[0], self.shader, .{ .x = bnds.x + 55, .y = bnds.y });
        try SpriteBatch.global.draw(Sprite, &self.icons[1], self.shader, .{ .x = bnds.x + 231, .y = bnds.y });

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
            .pos = bnds.location().add(Vec2{ .x = sd_x, .y = 64 }),
            .text = "Shutdown",
        });

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(Vec2{ .x = rs_x, .y = 64 }),
            .text = "Restart",
        });

        if (self.done) |rets| {
            switch (rets) {
                0 => {
                    LogoutState.target = .Bios;
                    try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                        .target_state = .Logout,
                    });
                },
                1 => {
                    LogoutState.target = .Quit;
                    try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                        .target_state = .Logout,
                    });
                },
                else => return,
            }
        }
    }

    pub fn click(self: *Self, mousepos: Vec2) !void {
        if (mousepos.x < 175) {
            self.done = 1;
        } else {
            self.done = 0;
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.destroy(self);
    }
};
