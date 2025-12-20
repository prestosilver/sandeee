const std = @import("std");
const c = @import("../c.zig");

const drawers = @import("../drawers.zig");
const util = @import("../util.zig");
const math = @import("../math.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const SpriteBatch = util.SpriteBatch;
const allocator = util.allocator;
const graphics = util.Graphics;

const VertArray = util.VertArray;

pub const GraphData = struct {
    size: Vec2,
    color: Color = .{ .r = 1, .g = 1, .b = 1 },
    data: []f32,
    max: f32 = 1.0,

    pub fn getVerts(self: *const GraphData, pos: Vec3) !VertArray {
        var result = try VertArray.init(self.data.len * 6);

        for (self.data[1..], self.data[0 .. self.data.len - 1], 0..) |point, prev, idx| {
            const cx = (@as(f32, @floatFromInt(idx)) + 1) * (self.size.x / @as(f32, @floatFromInt(self.data.len - 1)));
            const px = @as(f32, @floatFromInt(idx)) * (self.size.x / @as(f32, @floatFromInt(self.data.len - 1)));
            const cy = self.size.y - std.math.clamp(point / self.max, 0, 1) * self.size.y;
            const py = self.size.y - std.math.clamp(prev / self.max, 0, 1) * self.size.y;
            const stopy = self.size.y;

            try result.append(Vec3.add(pos, .{ .x = px, .y = py }), .{ .y = 1 }, self.color);
            try result.append(Vec3.add(pos, .{ .x = cx, .y = cy }), .{ .x = 1, .y = 1 }, self.color);
            try result.append(Vec3.add(pos, .{ .x = cx, .y = stopy }), .{ .x = 1 }, self.color);

            try result.append(Vec3.add(pos, .{ .x = px, .y = py }), .{ .y = 1 }, self.color);
            try result.append(Vec3.add(pos, .{ .x = px, .y = stopy }), .{}, self.color);
            try result.append(Vec3.add(pos, .{ .x = cx, .y = stopy }), .{ .x = 1 }, self.color);
        }

        return result;
    }
};

pub const drawer = SpriteBatch.Drawer(GraphData);
