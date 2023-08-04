const std = @import("std");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const sp = @import("../drawers/sprite2d.zig");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");
const files = @import("../system/files.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");
const wall = @import("../drawers/wall2d.zig");
const audio = @import("../util/audio.zig");
const c = @import("../c.zig");

pub var target: enum { Quit, Bios } = .Quit;

pub const GSLogout = struct {
    const Self = @This();

    shader: *shd.Shader,
    clearShader: *shd.Shader,
    sb: *batch.SpriteBatch,
    face: *font.Font,
    font_shader: *shd.Shader,
    wallpaper: *wall.Wallpaper,
    logout_sound: *audio.Sound,
    audio_man: *audio.Audio,

    time: f32 = 0,

    pub fn setup(self: *Self) !void {
        try files.write();
        try self.audio_man.playSound(self.logout_sound.*);

        self.time = 3;
    }

    pub fn deinit(_: *Self) !void {}

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        self.sb.scissor = null;

        try self.sb.draw(wall.Wallpaper, self.wallpaper, self.shader, vecs.newVec3(0, 0, 0));

        const clearSprite = sp.Sprite{
            .texture = "none",
            .data = .{
                .size = vecs.newVec2(size.x, size.y),
                .source = rect.newRect(0, 0, size.x, size.y),
            },
        };

        try self.sb.draw(sp.Sprite, &clearSprite, self.clearShader, vecs.newVec3(0, 0, 0));

        const logoutSize = self.face.sizeText(.{
            .text = "Logging Out",
        });

        const logoutPos = size.sub(logoutSize).div(2);

        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = "Logging Out",
            .pos = logoutPos,
            .color = cols.newColor(1, 1, 1, 1),
        });
    }

    pub fn update(self: *Self, dt: f32) !void {
        self.time -= dt;

        if (self.time < 0) {
            switch (target) {
                .Quit => {
                    c.glfwSetWindowShouldClose(gfx.gContext.window, 1);
                },
                .Bios => {
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Disks,
                    });
                },
            }
        }
    }

    pub fn keypress(_: *Self, _: c_int, _: c_int, _: bool) !void {}

    pub fn keychar(_: *Self, _: u32, _: c_int) !void {}
    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
