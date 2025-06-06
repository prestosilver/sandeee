const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");

const SpriteBatch = @import("../util/spritebatch.zig");

pub const SpriteData = struct {
    source: rect.Rectangle,
    size: vecs.Vector2,
    color: cols.Color = .{ .r = 1, .g = 1, .b = 1 },

    pub fn getVerts(self: *const SpriteData, pos: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(6);

        try result.appendQuad(.{
            .x = pos.x,
            .y = pos.y,
            .w = self.size.x,
            .h = self.size.y,
        }, self.source, .{ .color = self.color });

        return result;
    }
};

pub const Sprite = SpriteBatch.Drawer(SpriteData);
