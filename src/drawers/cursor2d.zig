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
    total: usize,
    index: usize = 0,
    flip: bool = false,

    pub fn new(source: rect.Rectangle, total: usize) CursorData {
        return CursorData{
            .source = source,
            .size = vecs.newVec2(32, 32),
            .color = cols.newColor(1, 1, 1, 1),
            .total = total,
        };
    }

    pub fn getVerts(self: *const CursorData, pos: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();

        var xo: f64 = 0;
        var yo: f64 = 0;

        c.glfwGetCursorPos(gfx.Context.instance.window, &xo, &yo);

        if (self.index != 0) {
            xo -= self.size.x / 2;
            yo -= self.size.y / 2;
        }

        const x = @as(f32, @floatCast(xo));
        const y = @as(f32, @floatCast(yo));

        var source = self.source;
        source.w /= @as(f32, @floatFromInt(self.total));
        source.x += source.w * @as(f32, @floatFromInt(self.index));

        if (self.flip) {
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y + self.size.y, 0)), vecs.newVec2(source.x, source.y + source.h), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y + self.size.y, 0)), vecs.newVec2(source.x + source.w, source.y + source.h), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y, 0)), vecs.newVec2(source.x + source.w, source.y), self.color);

            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y + self.size.y, 0)), vecs.newVec2(source.x, source.y + source.h), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y, 0)), vecs.newVec2(source.x, source.y), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y, 0)), vecs.newVec2(source.x + source.w, source.y), self.color);
        } else {
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y + self.size.y, 0)), vecs.newVec2(source.x, source.y + source.h), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y + self.size.y, 0)), vecs.newVec2(source.x + source.w, source.y + source.h), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y, 0)), vecs.newVec2(source.x + source.w, source.y), self.color);

            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y + self.size.y, 0)), vecs.newVec2(source.x, source.y + source.h), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x, y, 0)), vecs.newVec2(source.x, source.y), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(x + self.size.x, y, 0)), vecs.newVec2(source.x + source.w, source.y), self.color);
        }

        return result;
    }
};

pub const Cursor = sb.Drawer(CursorData);
