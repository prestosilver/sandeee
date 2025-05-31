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

    pub fn getVerts(self: *const WallData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(6);

        const par: *const sb.Drawer(WallData) = @fieldParentPtr("data", self);
        const size = (texture_manager.TextureManager.instance.textures.get(par.texture.atlas) orelse return result).size;

        switch (self.mode) {
            .Color => {},
            .Fill => {
                const x_ratio: f32 = self.dims.x / size.x;
                const y_ratio: f32 = self.dims.y / size.y;
                const max_ratio: f32 = @max(x_ratio, y_ratio);

                const w = max_ratio * size.x;
                const h = max_ratio * size.y;

                try result.appendQuad(.{
                    .w = w,
                    .h = h,
                    .x = (self.dims.x - w) / 2,
                    .y = (self.dims.y - h) / 2,
                }, .{ .w = 1, .h = 1 }, .{});
            },
            .Tile => {
                try result.appendQuad(.{
                    .w = self.dims.x,
                    .h = self.dims.y,
                    .x = 0,
                    .y = 0,
                }, .{
                    .w = self.dims.x / size.x,
                    .h = self.dims.y / size.y,
                }, .{});
            },
            .Center => {
                try result.appendQuad(.{
                    .w = size.x,
                    .h = size.y,
                    .x = (self.dims.x - size.x) / 2,
                    .y = (self.dims.y - size.y) / 2,
                }, .{ .w = 1, .h = 1 }, .{});
            },
            .Stretch => {
                try result.appendQuad(.{
                    .w = self.dims.x,
                    .h = self.dims.y,
                    .x = 0,
                    .y = 0,
                }, .{ .w = 1, .h = 1 }, .{});
            },
            else => {},
        }

        return result;
    }
};

pub const Wallpaper = sb.Drawer(WallData);
