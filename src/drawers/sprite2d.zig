const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");

pub const SpriteData = struct {
    source: rect.Rectangle,
    size: vecs.Vector2,
    color: cols.Color = .{ .r = 1, .g = 1, .b = 1 },

    pub fn getVerts(self: *const SpriteData, pos: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(6);

        try result.append(vecs.Vector3.add(pos, .{ .y = self.size.y }), .{ .x = self.source.x, .y = self.source.y + self.source.h }, self.color);
        try result.append(vecs.Vector3.add(pos, .{ .x = self.size.x, .y = self.size.y }), .{ .x = self.source.x + self.source.w, .y = self.source.y + self.source.h }, self.color);
        try result.append(vecs.Vector3.add(pos, .{ .x = self.size.x }), .{ .x = self.source.x + self.source.w, .y = self.source.y }, self.color);

        try result.append(vecs.Vector3.add(pos, .{ .y = self.size.y }), .{ .x = self.source.x, .y = self.source.y + self.source.h }, self.color);
        try result.append(vecs.Vector3.add(pos, .{}), .{ .x = self.source.x, .y = self.source.y }, self.color);
        try result.append(vecs.Vector3.add(pos, .{ .x = self.size.x }), .{ .x = self.source.x + self.source.w, .y = self.source.y }, self.color);

        return result;
    }
};

pub const Sprite = sb.Drawer(SpriteData);
