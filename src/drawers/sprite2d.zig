const sb = @import("../spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../vertArray.zig");

pub const SpriteData = struct {
    source: rect.Rectangle,
    size: vecs.Vector2,

    pub fn new(source: rect.Rectangle, size: vecs.Vector2) SpriteData {
        return SpriteData{
            .source = source,
            .size = size,
        };
    }

    pub fn getVerts(self: *SpriteData, pos: vecs.Vector3) va.VertArray {
        var result = va.VertArray.init();

        result.append(vecs.Vector3.add(pos, vecs.newVec3(0, self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), cols.newColor(1, 1, 1, 1));
        result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, self.size.y, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y + self.source.h), cols.newColor(1, 1, 1, 1));
        result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, 0, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), cols.newColor(1, 1, 1, 1));

        result.append(vecs.Vector3.add(pos, vecs.newVec3(0, self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), cols.newColor(1, 1, 1, 1));
        result.append(vecs.Vector3.add(pos, vecs.newVec3(0, 0, 0)), vecs.newVec2(self.source.x, self.source.y), cols.newColor(1, 1, 1, 1));
        result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, 0, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), cols.newColor(1, 1, 1, 1));

        return result;
    }
};

pub const Sprite = sb.Drawer(SpriteData);
