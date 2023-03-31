const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const gfx = @import("../util/graphics.zig");
const va = @import("../util/vertArray.zig");
const c = @import("../c.zig");

pub const CursorData = struct {
    source: rect.Rectangle,
    size: vecs.Vector2,
    color: cols.Color,

    pub fn new(source: rect.Rectangle) CursorData {
        return CursorData{
            .source = source,
            .size = vecs.newVec2(32, 32),
            .color = cols.newColor(1, 1, 1, 1),
        };
    }

    pub fn getVerts(self: *CursorData, pos: vecs.Vector3) !va.VertArray {
        var result = va.VertArray.init();

        c.glfwGetCursorPos(gfx.gContext.win, pos.x, pos.y);
        result.append(vecs.Vector3.add(pos, vecs.newVec3(0, self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), self.color);
        result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, self.size.y, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y + self.source.h), self.color);
        result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, 0, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), self.color);

        result.append(vecs.Vector3.add(pos, vecs.newVec3(0, self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), self.color);
        result.append(vecs.Vector3.add(pos, vecs.newVec3(0, 0, 0)), vecs.newVec2(self.source.x, self.source.y), self.color);
        result.append(vecs.Vector3.add(pos, vecs.newVec3(self.size.x, 0, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), self.color);

        return result;
    }
};

pub const Cursor = sb.Drawer(CursorData);
