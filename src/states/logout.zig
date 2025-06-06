const std = @import("std");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const events = @import("../util/events.zig");
const system_events = @import("../events/system.zig");
const sp = @import("../drawers/sprite2d.zig");
const shd = @import("../util/shader.zig");
const files = @import("../system/files.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");
const wall = @import("../drawers/wall2d.zig");
const audio = @import("../util/audio.zig");
const c = @import("../c.zig");
const vm_manager = @import("../system/vmmanager.zig");
const loader = @import("../loaders/loader.zig");

const SpriteBatch = @import("../util/spritebatch.zig");

pub var target: enum { Quit, Bios, Update } = .Quit;
pub var target_file: []const u8 = "";

pub const GSLogout = struct {
    const Self = @This();

    shader: *shd.Shader,
    clear_shader: *shd.Shader,
    face: *font.Font,
    font_shader: *shd.Shader,
    wallpaper: *wall.Wallpaper,
    logout_sound: *audio.Sound,

    time: f32 = 0,

    pub var unloader: ?loader.Unloader = null;

    pub fn setup(self: *Self) !void {
        try audio.instance.playSound(self.logout_sound.*);
        try vm_manager.VMManager.logout();
        self.time = 3;

        if (unloader) |*ul|
            ul.run();

        unloader = null;
    }

    pub fn deinit(_: *Self) void {}

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        const old_scissor = SpriteBatch.global.scissor;
        defer SpriteBatch.global.scissor = old_scissor;

        SpriteBatch.global.scissor = null;

        try SpriteBatch.global.draw(wall.Wallpaper, self.wallpaper, self.shader, .{});

        const clear_sprite: sp.Sprite = .atlas("none", .{
            .size = size,
            .source = .{ .w = size.x, .h = size.y },
        });

        try SpriteBatch.global.draw(sp.Sprite, &clear_sprite, self.clear_shader, .{});

        const text = if (target == .Update) "Updating" else "Logging Out";

        const logout_size = self.face.sizeText(.{
            .text = text,
        });

        const logout_pos = size.sub(logout_size).div(2);

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = text,
            .pos = logout_pos,
            .color = .{ .r = 1, .g = 1, .b = 1 },
        });
    }

    pub fn update(self: *Self, dt: f32) !void {
        self.time -= dt;

        if (self.time < 0) {
            switch (target) {
                .Quit => {
                    c.glfwSetWindowShouldClose(gfx.Context.instance.window, 1);
                },
                .Bios => {
                    try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                        .target_state = .Disks,
                    });
                },
                .Update => {
                    try files.Folder.recoverDisk(target_file, false);

                    try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                        .target_state = .Disks,
                    });

                    allocator.alloc.free(target_file);
                    target_file = "";
                },
            }
        }
    }
};
