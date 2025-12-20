const std = @import("std");

const Vec2 = @import("root").Vec2;

const Vec3 = @This();

x: f32 = 0.0,
y: f32 = 0.0,
z: f32 = 0.0,

pub inline fn add(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        .x = a.x + b.x,
        .y = a.y + b.y,
        .z = a.z + b.z,
    };
}

pub inline fn dot(a: Vec2, b: Vec2) f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

pub inline fn cross(a: Vec2, b: Vec2) Vec3 {
    return Vec3{
        .x = a.y * a.z - b.z * b.y,
        .y = a.z * a.x - b.x * b.z,
        .z = a.x * a.y - b.y * b.x,
    };
}

pub inline fn mag(a: Vec2) f32 {
    return std.math.sqrt(dot(a, a));
}

pub inline fn normalize(a: Vec3) Vec3 {
    return a * (1 / a.mag);
}
