const std = @import("std");
const glfw = @import("glfw");

const drawers = @import("mod.zig");

const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const graphics = util.graphics;

pub const CursorData = struct {
    source: Rect,
    size: Vec2 = .{ .x = 32, .y = 32 },
    color: Color = .{ .r = 1, .g = 1, .b = 1 },
    total: usize,
    index: usize = 0,
    flip: bool = false,

    pub fn getVerts(self: *const CursorData, pos: Vec3) !VertArray {
        var result = try VertArray.init(6);

        var xo: f64 = 0;
        var yo: f64 = 0;

        glfw.getCursorPos(graphics.Context.instance.window, &xo, &yo);

        if (self.index != 0) {
            xo -= self.size.x / 2;
            yo -= self.size.y / 2;
        }

        const x = @as(f32, @floatCast(xo));
        const y = @as(f32, @floatCast(yo));

        var source = self.source;
        source.w /= @as(f32, @floatFromInt(self.total));
        source.x += source.w * @as(f32, @floatFromInt(self.index));

        try result.appendQuad(
            .{
                .x = pos.x + x,
                .y = pos.y + y,
                .w = self.size.x,
                .h = self.size.y,
            },
            source,
            .{ .flip_x = self.flip },
        );

        return result;
    }
};

pub const drawer = SpriteBatch.Drawer(CursorData);
