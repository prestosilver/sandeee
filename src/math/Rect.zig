const math = @import("../math.zig");

const Vec3 = math.Vec3;
const Vec2 = math.Vec2;

pub const Rect = @This();

x: f32 = 0.0,
y: f32 = 0.0,
w: f32,
h: f32,

pub const Corner = enum {
    top_left,
    top_right,
    bot_left,
    bot_right,
};

pub fn getCorner(self: Rect, comptime corner: Corner) Vec2 {
    return switch (corner) {
        .top_left => .{ .x = self.x, .y = self.y },
        .top_right => .{ .x = self.x + self.w, .y = self.y },
        .bot_left => .{ .x = self.x, .y = self.y + self.h },
        .bot_right => .{ .x = self.x + self.w, .y = self.y + self.h },
    };
}

pub fn equal(self: Rect, other: Rect) bool {
    return self.x == other.x and
        self.y == other.y and
        self.w == other.w and
        self.h == other.h;
}

pub fn contains(self: Rect, v: Vec2) bool {
    return self.x <= v.x and self.y <= v.y and self.x + self.w > v.x and self.y + self.h > v.y;
}

pub fn containsWhole(self: Rect, v: Rect) bool {
    return self.contains(v.location()) and self.contains(v.location().add(v.size()));
}

pub fn containsSome(self: Rect, v: Rect) bool {
    return self.contains(v.location()) or self.contains(v.location().add(v.size()));
}

pub fn location(self: Rect) Vec2 {
    return .{ .x = self.x, .y = self.y };
}

pub fn size(self: Rect) Vec2 {
    return .{ .x = self.w, .y = self.h };
}

pub fn round(self: Rect) Rect {
    return .{
        .x = @round(self.x),
        .y = @round(self.y),
        .w = @round(self.w),
        .h = @round(self.h),
    };
}

pub fn initCentered(parent: Rect, w: f32, h: f32) Rect {
    return Rect{
        .x = parent.x + (parent.w - w) / 2,
        .y = parent.y + (parent.h - h) / 2,
        .w = w,
        .h = h,
    };
}
