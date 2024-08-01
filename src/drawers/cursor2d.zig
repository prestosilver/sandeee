const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const gfx = @import("../util/graphics.zig");
const va = @import("../util/vertArray.zig");
const c = @import("../c.zig");

pub const CursorData = struct {
    source: rect.Rectangle,
    size: vecs.Vector2 = .{ .x = 32, .y = 32 },
    color: cols.Color = .{ .r = 1, .g = 1, .b = 1 },
    total: usize,
    index: usize = 0,
    flip: bool = false,

    pub fn getVerts(self: *const CursorData, pos: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(6);

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
            try result.append(.{ .x = pos.x + x + self.size.x, .y = pos.y + y + self.size.y, .z = pos.z }, .{ .x = source.x, .y = source.y + source.h }, self.color);
            try result.append(.{ .x = pos.x + x, .y = pos.y + y + self.size.y, .z = pos.z }, .{ .x = source.x + source.w, .y = source.y + source.h }, self.color);
            try result.append(.{ .x = pos.x + x, .y = pos.y + y, .z = pos.z }, .{ .x = source.x + source.w, .y = source.y }, self.color);

            try result.append(.{ .x = pos.x + x + self.size.x, .y = pos.y + y + self.size.y, .z = pos.z }, .{ .x = source.x, .y = source.y + source.h }, self.color);
            try result.append(.{ .x = pos.x + x + self.size.x, .y = pos.y + y, .z = pos.z }, .{ .x = source.x, .y = source.y }, self.color);
            try result.append(.{ .x = pos.x + x, .y = pos.y + y, .z = pos.z }, .{ .x = source.x + source.w, .y = source.y }, self.color);
        } else {
            try result.append(.{ .x = pos.x + x, .y = pos.y + y + self.size.y, .z = pos.z }, .{ .x = source.x, .y = source.y + source.h }, self.color);
            try result.append(.{ .x = pos.x + x + self.size.x, .y = pos.y + y + self.size.y, .z = pos.z }, .{ .x = source.x + source.w, .y = source.y + source.h }, self.color);
            try result.append(.{ .x = pos.x + x + self.size.x, .y = pos.y + y, .z = pos.z }, .{ .x = source.x + source.w, .y = source.y }, self.color);

            try result.append(.{ .x = pos.x + x, .y = pos.y + y + self.size.y, .z = pos.z }, .{ .x = source.x, .y = source.y + source.h }, self.color);
            try result.append(.{ .x = pos.x + x, .y = pos.y + y, .z = pos.z }, .{ .x = source.x, .y = source.y }, self.color);
            try result.append(.{ .x = pos.x + x + self.size.x, .y = pos.y + y, .z = pos.z }, .{ .x = source.x + source.w, .y = source.y }, self.color);
        }

        return result;
    }
};

pub const Cursor = sb.Drawer(CursorData);
