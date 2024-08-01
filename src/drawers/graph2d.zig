const std = @import("std");

const allocator = @import("../util/allocator.zig");

const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const gfx = @import("../util/graphics.zig");
const va = @import("../util/vertArray.zig");
const c = @import("../c.zig");

pub const GraphData = struct {
    size: vecs.Vector2,
    color: cols.Color = .{ .r = 1, .g = 1, .b = 1 },
    data: []f32,
    max: f32 = 1.0,

    pub fn getVerts(self: *const GraphData, pos: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(self.data.len * 6);

        for (self.data[1..], self.data[0 .. self.data.len - 1], 0..) |point, prev, idx| {
            const cx = (@as(f32, @floatFromInt(idx)) + 1) * (self.size.x / @as(f32, @floatFromInt(self.data.len - 1)));
            const px = @as(f32, @floatFromInt(idx)) * (self.size.x / @as(f32, @floatFromInt(self.data.len - 1)));
            const cy = self.size.y - std.math.clamp(point / self.max, 0, 1) * self.size.y;
            const py = self.size.y - std.math.clamp(prev / self.max, 0, 1) * self.size.y;
            const stopy = self.size.y;

            try result.append(vecs.Vector3.add(pos, .{ .x = px, .y = py }), .{ .y = 1 }, self.color);
            try result.append(vecs.Vector3.add(pos, .{ .x = cx, .y = cy }), .{ .x = 1, .y = 1 }, self.color);
            try result.append(vecs.Vector3.add(pos, .{ .x = cx, .y = stopy }), .{ .x = 1 }, self.color);

            try result.append(vecs.Vector3.add(pos, .{ .x = px, .y = py }), .{ .y = 1 }, self.color);
            try result.append(vecs.Vector3.add(pos, .{ .x = px, .y = stopy }), .{}, self.color);
            try result.append(vecs.Vector3.add(pos, .{ .x = cx, .y = stopy }), .{ .x = 1 }, self.color);
        }

        return result;
    }
};

pub const Graph = sb.Drawer(GraphData);
