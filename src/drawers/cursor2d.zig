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
        var result = try va.VertArray.init();

        var xo: f64 = 0;
        var yo: f64 = 0;

        c.glfwGetCursorPos(gfx.gContext.window, &xo, &yo);

        var x = @floatCast(f32, xo);
        var y = @floatCast(f32, yo);

        try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y + self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y + self.size.y, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y + self.source.h), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), self.color);

        try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y + self.size.y, 0)), vecs.newVec2(self.source.x, self.source.y + self.source.h), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y, 0)), vecs.newVec2(self.source.x, self.source.y), self.color);
        try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y, 0)), vecs.newVec2(self.source.x + self.source.w, self.source.y), self.color);

        return result;
    }
};

pub const Cursor = sb.Drawer(CursorData);
