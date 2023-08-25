const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");

pub const SpriteData = struct {
    source: rect.Rectangle,
    size: vecs.Vector2,
    color: cols.Color = cols.newColor(1, 1, 1, 1),

    pub fn new(source: rect.Rectangle, size: vecs.Vector2) SpriteData {
        return SpriteData{
            .source = source,
            .size = size,
        };
    }

    pub fn getVerts(self: *const SpriteData, pos: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(6);

        try result.append(vecs.Vector3.add(pos, vecs.newVec3(0, self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, self.size.y, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y + self.source.h), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, 0, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), self.color);

        try result.append(vecs.Vector3.add(pos, vecs.newVec3(0, self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(0, 0, 0)), vecs.newVec2(self.source.x, self.source.y), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, 0, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), self.color);

        return result;
    }
};

pub const Sprite = sb.Drawer(SpriteData);
