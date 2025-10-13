const std = @import("std");
const c = @import("../c.zig");

const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;

pub const SpriteData = struct {
    source: Rect,
    size: Vec2,
    color: Color = .{ .r = 1, .g = 1, .b = 1 },

    pub fn getVerts(self: *const SpriteData, pos: Vec3) !VertArray {
        var result = try VertArray.init(6);

        try result.appendQuad(.{
            .x = pos.x,
            .y = pos.y,
            .w = self.size.x,
            .h = self.size.y,
        }, self.source, .{ .color = self.color });

        return result;
    }
};

pub const drawer = SpriteBatch.Drawer(SpriteData);
