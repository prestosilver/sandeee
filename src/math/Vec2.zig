const std = @import("std");

const math = @import("../math.zig");

const Vec3 = math.Vec3;

x: f32 = 0.0,
y: f32 = 0.0,

const Vec2 = @This();

pub inline fn round(a: Vec2) Vec2 {
    return Vec2{
        .x = @round(a.x),
        .y = @round(a.y),
    };
}

pub inline fn add(a: Vec2, b: Vec2) Vec2 {
    return Vec2{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}

pub inline fn mul(a: Vec2, b: f32) Vec2 {
    return Vec2{
        .x = a.x * b,
        .y = a.y * b,
    };
}

pub inline fn sub(a: Vec2, b: Vec2) Vec2 {
    return Vec2{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}

pub inline fn div(a: Vec2, b: f32) Vec2 {
    return Vec2{
        .x = a.x / b,
        .y = a.y / b,
    };
}

// misc stuff
pub inline fn magSq(a: Vec2) f32 {
    return @abs((a.x * a.x) + (a.y * a.y));
}

pub inline fn mag(a: Vec2) f32 {
    return std.math.sqrt(magSq(a));
}

pub inline fn distSq(a: Vec2, b: Vec2) f32 {
    return magSq(sub(a, b));
}

pub inline fn dist(a: Vec2, b: Vec2) f32 {
    return mag(sub(a, b));
}

pub inline fn getAngle(a: Vec2) f32 {
    return std.math.atan2(f32, a.x, a.y);
}

pub inline fn setAngle(a: Vec2, angle: f32) f32 {
    const magnitude = a.mag;

    const x = @cos(angle);
    const y = @sin(angle);

    return Vec2{
        .x = x * magnitude,
        .y = y * magnitude,
    };
}

pub fn toVec3(self: Vec2) Vec3 {
    return .{ .x = self.x, .y = self.y };
}
