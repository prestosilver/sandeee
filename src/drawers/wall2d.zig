const std = @import("std");
const c = @import("../c.zig");

const drawers = @import("mod.zig");

const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Shader = util.Shader;
const Font = util.font;

pub const WallData = struct {
    pub const Mode = enum {
        Color,
        Tile,
        Center,
        Stretch,
        Fill,
        Zoom,
    };

    dims: *Vec2,
    mode: Mode = .Center,

    pub fn getVerts(self: *const WallData, _: Vec3) !VertArray {
        var result = try VertArray.init(6);

        const par: *const SpriteBatch.Drawer(WallData) = @fieldParentPtr("data", self);
        const size = (TextureManager.instance.textures.get(par.texture.atlas) orelse return result).size;

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

pub const drawer = SpriteBatch.Drawer(WallData);
