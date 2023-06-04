const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");

pub const ScrollData = struct {
    const UV_UP = rect.newRect(0.0 / 5.0, 0.0 / 5.0, 2.0 / 5.0, 2.0 / 5.0);

    pos: rect.Rectangle,
    hide: bool = false,

    fn addQuad(arr: *va.VertArray, pos: rect.Rectangle, src: rect.Rectangle) !void {
        var source = src;

        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
    }

    pub fn getVerts(self: *ScrollData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();
        if (self.hide) return result;

        addQuad(result, rect.newRect(self.pos.x, self.pos.y, self.pos.w, self.pos.w), UV_UP);
    }
};

pub const Scroll = sb.Drawer(ScrollData);
