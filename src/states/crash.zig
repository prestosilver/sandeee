const std = @import("std");
const vecs = @import("../math/vecs.zig");
const sp = @import("../drawers/sprite2d.zig");
const shd = @import("../shader.zig");
const batch = @import("../spritebatch.zig");

pub const GSCrash = struct {
    const Self = @This();

    message: []const u8 = "ERROR",
    shader: *shd.Shader,
    sb: *batch.SpriteBatch,

    sad_sprite: sp.Sprite,

    pub fn setup(_: *Self) !void {}

    pub fn draw(self: *Self, _: vecs.Vector2) !void {
        self.sb.draw(sp.Sprite, &self.sad_sprite, self.shader, vecs.newVec3(100, 100, 0));
    }

    pub fn update(_: *Self, _: f32) !void {}

    pub fn keypress(_: *Self, _: c_int, _: c_int) !bool {
        return false;
    }

    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
