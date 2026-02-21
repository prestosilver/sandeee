const std = @import("std");

const math = @import("../math.zig");

const Vec3 = math.Vec3;

x: usize = 0.0,
y: usize = 0.0,

const IVec2 = @This();

pub inline fn add(a: IVec2, b: IVec2) IVec2 {
    return IVec2{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}

pub inline fn mul(a: IVec2, b: f32) IVec2 {
    return IVec2{
        .x = a.x * b,
        .y = a.y * b,
    };
}

pub inline fn sub(a: IVec2, b: IVec2) IVec2 {
    return IVec2{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}

pub inline fn div(a: IVec2, b: f32) IVec2 {
    return IVec2{
        .x = a.x / b,
        .y = a.y / b,
    };
}

// misc stuff
pub inline fn magSq(a: IVec2) f32 {
    return @abs((a.x * a.x) + (a.y * a.y));
}

pub inline fn mag(a: IVec2) f32 {
    return std.math.sqrt(magSq(a));
}

pub inline fn distSq(a: IVec2, b: IVec2) f32 {
    return magSq(sub(a, b));
}

pub inline fn dist(a: IVec2, b: IVec2) f32 {
    return mag(sub(a, b));
}

pub inline fn getAngle(a: IVec2) f32 {
    return std.math.atan2(f32, a.x, a.y);
}

pub inline fn setAngle(a: IVec2, angle: f32) f32 {
    const magnitude = a.mag;

    const x = @cos(angle);
    const y = @sin(angle);

    return IVec2{
        .x = x * magnitude,
        .y = y * magnitude,
    };
}

pub fn toVec3(self: IVec2) Vec3 {
    return .{ .x = self.x, .y = self.y };
}
