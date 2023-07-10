const std = @import("std");
const vecs = @import("../math/vecs.zig");
const sp = @import("../drawers/sprite2d.zig");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");
const files = @import("../system/files.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");

pub const GSLogout = struct {
    const Self = @This();

    shader: *shd.Shader,
    sb: *batch.SpriteBatch,
    face: *font.Font,
    font_shader: *shd.Shader,

    pub fn setup(_: *Self) !void {
        try files.write();
        gfx.gContext.color = cols.newColor(0, 0, 0, 1);
    }

    pub fn deinit(_: *Self) !void {}

    pub fn draw(self: *Self, _: vecs.Vector2) !void {
        self.sb.scissor = null;

        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = "TODO: Logout",
            .pos = vecs.newVec2(300, 100),
            .color = cols.newColor(1, 1, 1, 1),
        });
    }

    pub fn update(_: *Self, _: f32) !void {}

    pub fn keypress(_: *Self, _: c_int, _: c_int, _: bool) !void {}

    pub fn keychar(_: *Self, _: u32, _: c_int) !void {}
    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
