const std = @import("std");

pub const Vector2 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    pub inline fn round(a: Vector2) Vector2 {
        return Vector2{
            .x = @round(a.x),
            .y = @round(a.y),
        };
    }

    pub inline fn add(a: Vector2, b: Vector2) Vector2 {
        return Vector2{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }

    pub inline fn mul(a: Vector2, b: f32) Vector2 {
        return Vector2{
            .x = a.x * b,
            .y = a.y * b,
        };
    }

    pub inline fn sub(a: Vector2, b: Vector2) Vector2 {
        return Vector2{
            .x = a.x - b.x,
            .y = a.y - b.y,
        };
    }

    pub inline fn div(a: Vector2, b: f32) Vector2 {
        return Vector2{
            .x = a.x / b,
            .y = a.y / b,
        };
    }

    // misc stuff
    pub inline fn magSq(a: Vector2) f32 {
        return @abs((a.x * a.x) + (a.y * a.y));
    }

    pub inline fn mag(a: Vector2) f32 {
        return std.math.sqrt(magSq(a));
    }

    pub inline fn distSq(a: Vector2, b: Vector2) f32 {
        return magSq(sub(a, b));
    }

    pub inline fn dist(a: Vector2, b: Vector2) f32 {
        return mag(sub(a, b));
    }

    pub inline fn getAngle(a: Vector2) f32 {
        return std.math.atan2(f32, a.x, a.y);
    }

    pub inline fn setAngle(a: Vector2, angle: f32) f32 {
        const magnitude = a.mag;

        const x = @cos(angle);
        const y = @sin(angle);

        return Vector2{
            .x = x * magnitude,
            .y = y * magnitude,
        };
    }
};

pub const Vector3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub inline fn add(a: Vector3, b: Vector3) Vector3 {
        return Vector3{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    pub inline fn dot(a: Vector2, b: Vector2) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub inline fn cross(a: Vector2, b: Vector2) Vector3 {
        return Vector3{
            .x = a.y * a.z - b.z * b.y,
            .y = a.z * a.x - b.x * b.z,
            .z = a.x * a.y - b.y * b.x,
        };
    }

    pub inline fn mag(a: Vector2) f32 {
        return std.math.sqrt(dot(a, a));
    }

    pub inline fn normalize(a: Vector3) Vector3 {
        return a * (1 / a.mag);
    }
};
