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
const c = @import("../c.zig");

pub const GSCrash = struct {
    const Self = @This();

    message: *[]const u8,
    shader: *shd.Shader,
    face: *font.Font,
    font_shader: *shd.Shader,

    prev_state: *u8,

    sad_sprite: sp.Sprite,

    pub fn setup(_: *Self) !void {
        try files.write();
        gfx.Context.instance.color = cols.newColor(0.25, 0, 0, 1);
    }

    pub fn deinit(_: *Self) !void {}

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        batch.SpriteBatch.instance.scissor = null;

        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.sad_sprite, self.shader, vecs.newVec3(100, 100, 0));

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = "ERROR:",
            .pos = vecs.newVec2(300, 100),
            .color = cols.newColor(1, 1, 1, 1),
            .wrap = size.x - 400,
        });
        try self.face.draw(.{
            .shader = self.font_shader,
            .text = self.message.*,
            .pos = vecs.newVec2(300, 100 + self.face.size),
            .color = cols.newColor(1, 1, 1, 1),
            .wrap = size.x - 400,
        });

        const offset = self.face.sizeText(.{
            .text = self.message.*,
            .wrap = size.x - 400,
        }).y;

        const state_text = try std.fmt.allocPrint(allocator.alloc, "State: {}", .{self.prev_state.*});
        defer allocator.alloc.free(state_text);

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = state_text,
            .pos = vecs.newVec2(300, 100 + self.face.size * 1 + offset),
            .color = cols.newColor(1, 1, 1, 1),
            .wrap = size.x - 400,
        });

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = "\nIF YOU SEE THIS CRASH YOUR FILES WERE SAVED :)",
            .pos = vecs.newVec2(300, 100 + self.face.size * 3 + offset),
            .color = cols.newColor(1, 1, 1, 1),
            .wrap = size.x - 400,
        });
    }

    pub fn keypress(_: *Self, key: c_int, _: c_int, down: bool) !void {
        if (down and key == c.GLFW_KEY_ESCAPE)
            c.glfwSetWindowShouldClose(gfx.Context.instance.window, 1);
        return;
    }
};
