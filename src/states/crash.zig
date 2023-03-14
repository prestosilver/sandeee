const std = @import("std");
const vecs = @import("../math/vecs.zig");
const sp = @import("../drawers/sprite2d.zig");
const shd = @import("../shader.zig");
const batch = @import("../spritebatch.zig");
const files = @import("../system/files.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../graphics.zig");
const cols = @import("../math/colors.zig");

pub const GSCrash = struct {
    const Self = @This();

    message: *[]const u8,
    shader: *shd.Shader,
    sb: *batch.SpriteBatch,
    face: *font.Font,
    font_shader: *shd.Shader,

    prevState: *u8,

    sad_sprite: sp.Sprite,

    pub fn setup(_: *Self) !void {
        try files.write();
        gfx.gContext.color = cols.newColor(0.3333, 0, 0, 1);
    }

    pub fn deinit(_: *Self) !void {}

    pub fn draw(self: *Self, _: vecs.Vector2) !void {
        try self.sb.draw(sp.Sprite, &self.sad_sprite, self.shader, vecs.newVec3(100, 100, 0));

        try self.face.drawScale(self.sb, self.font_shader, "ERROR:", vecs.newVec2(300, 100), cols.newColor(1, 1, 1, 1), 1);
        try self.face.drawScale(self.sb, self.font_shader, self.message.*, vecs.newVec2(300, 100 + self.face.size), cols.newColor(1, 1, 1, 1), 1);

        var stateLine = try std.fmt.allocPrint(allocator.alloc, "State: {}", .{self.prevState.*});
        defer allocator.alloc.free(stateLine);

        try self.face.drawScale(self.sb, self.font_shader, stateLine, vecs.newVec2(300, 100 + self.face.size * 2), cols.newColor(1, 1, 1, 1), 1);
        try self.face.drawScale(self.sb, self.font_shader, "THIS IS NOT AN INTENTIONAL CRASH, PLEASE REPORT THIS", vecs.newVec2(300, 100 + self.face.size * 4), cols.newColor(1, 1, 1, 1), 1);
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
