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
    color: cols.Color = cols.newColor(1, 1, 1, 1),
    data: []f32,
    max: f32 = 1.0,

    pub fn new(size: vecs.Vector2) !GraphData {
        return GraphData{
            .size = size,
            .data = try allocator.alloc.alloc(f32, 0),
        };
    }

    pub fn getVerts(self: *const GraphData, pos: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(self.data.len * 6);

        for (self.data[1..], self.data[0 .. self.data.len - 1], 0..) |point, prev, idx| {
            const cx = (@as(f32, @floatFromInt(idx)) + 1) * (self.size.x / @as(f32, @floatFromInt(self.data.len - 1)));
            const px = @as(f32, @floatFromInt(idx)) * (self.size.x / @as(f32, @floatFromInt(self.data.len - 1)));
            const cy = self.size.y - std.math.clamp(point / self.max, 0, 1) * self.size.y;
            const py = self.size.y - std.math.clamp(prev / self.max, 0, 1) * self.size.y;
            const stopy = self.size.y;

            try result.append(vecs.Vector3.add(pos, vecs.newVec3(px, py, 0)), vecs.newVec2(0, 1), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(cx, cy, 0)), vecs.newVec2(1, 1), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(cx, stopy, 0)), vecs.newVec2(1, 0), self.color);

            try result.append(vecs.Vector3.add(pos, vecs.newVec3(px, py, 0)), vecs.newVec2(0, 1), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(px, stopy, 0)), vecs.newVec2(0, 0), self.color);
            try result.append(vecs.Vector3.add(pos, vecs.newVec3(cx, stopy, 0)), vecs.newVec2(1, 0), self.color);
        }

        return result;
    }
};

pub const Graph = sb.Drawer(GraphData);
