const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");
const va = @import("../util/vertArray.zig");

pub const WallData = struct {
    pub const Mode = enum {
        Color,
        Tile,
        Center,
        Stretch,
    };

    dims: *vecs.Vector2,
    size: *vecs.Vector2,
    mode: Mode = .Center,

    fn addQuad(arr: *va.VertArray, pos: rect.Rectangle, src: rect.Rectangle) !void {
        var source = src;

        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
    }

    pub fn getVerts(self: *WallData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();
        var pos: rect.Rectangle = undefined;
        var source = rect.newRect(0, 0, 1, 1);
        switch (self.mode) {
            .Color => {
                return result;
            },
            .Tile => {
                pos.w = self.dims.x;
                pos.h = self.dims.y;
                pos.x = 0;
                pos.y = 0;
                source.w = self.dims.x / self.size.x;
                source.h = self.dims.y / self.size.y;
            },
            .Center => {
                pos.w = self.size.x;
                pos.h = self.size.y;
                pos.x = (self.dims.x - pos.w) / 2;
                pos.y = (self.dims.y - pos.h) / 2;
            },
            .Stretch => {
                pos.w = self.dims.x;
                pos.h = self.dims.y;
                pos.x = 0;
                pos.y = 0;
            },
        }

        try addQuad(&result, pos, source);

        return result;
    }
};

pub const Wallpaper = sb.Drawer(WallData);
