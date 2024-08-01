const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");
const va = @import("../util/vertArray.zig");
const texture_manager = @import("../util/texmanager.zig");

pub const WallData = struct {
    pub const Mode = enum {
        Color,
        Tile,
        Center,
        Stretch,
        Fill,
        Zoom,
    };

    dims: *vecs.Vector2,
    mode: Mode = .Center,

    inline fn addQuad(arr: *va.VertArray, pos: rect.Rectangle, src: rect.Rectangle) !void {
        const source = src;

        const color = cols.Color{ .r = 1, .g = 1, .b = 1 };

        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y + pos.h }, .{ .x = source.x + source.w, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y }, .{ .x = source.x, .y = source.y }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
    }

    pub fn getVerts(self: *const WallData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(6);
        var pos: rect.Rectangle = undefined;
        var source = rect.Rectangle{ .w = 1, .h = 1 };

        const par: *const sb.Drawer(WallData) = @fieldParentPtr("data", self);
        const size = (texture_manager.TextureManager.instance.textures.get(par.texture) orelse return result).size;

        switch (self.mode) {
            .Color => {
                return result;
            },
            .Fill => {
                const x_ratio: f32 = self.dims.x / size.x;
                const y_ratio: f32 = self.dims.y / size.y;
                const max_ratio: f32 = @max(x_ratio, y_ratio);

                pos.w = max_ratio * size.x;
                pos.h = max_ratio * size.y;
                pos.x = (self.dims.x - pos.w) / 2;
                pos.y = (self.dims.y - pos.h) / 2;
            },
            .Tile => {
                pos.w = self.dims.x;
                pos.h = self.dims.y;
                pos.x = 0;
                pos.y = 0;
                source.w = self.dims.x / size.x;
                source.h = self.dims.y / size.y;
            },
            .Center => {
                pos.w = size.x;
                pos.h = size.y;
                pos.x = (self.dims.x - pos.w) / 2;
                pos.y = (self.dims.y - pos.h) / 2;
            },
            .Stretch => {
                pos.w = self.dims.x;
                pos.h = self.dims.y;
                pos.x = 0;
                pos.y = 0;
            },
            else => return result,
        }

        try addQuad(&result, pos, source);

        return result;
    }
};

pub const Wallpaper = sb.Drawer(WallData);
