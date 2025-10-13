const std = @import("std");

const Color = @This();

r: f32,
g: f32,
b: f32,
a: f32 = 1,

pub inline fn mix(a: Color, b: Color, pc: f32) Color {
    return .{
        .r = a.r + (b.r - a.r) * pc,
        .g = a.g + (b.g - a.g) * pc,
        .b = a.b + (b.b - a.b) * pc,
        .a = a.a + (b.a - a.a) * pc,
    };
}

pub inline fn parseColor(color: [6]u8) !Color {
    const hex = try std.fmt.parseInt(u24, &color, 16);

    return .{
        .r = @as(f32, @floatFromInt((hex >> 16) & 255)) / 255,
        .g = @as(f32, @floatFromInt((hex >> 8) & 255)) / 255,
        .b = @as(f32, @floatFromInt((hex >> 0) & 255)) / 255,
        .a = 1,
    };
}

pub inline fn contrast(c: Color) Color {
    const gamma = 2.2;
    const luma = 0.2126 * std.math.pow(f32, c.r, gamma) + 0.7152 * std.math.pow(f32, c.g, gamma) + 0.0722 * std.math.pow(f32, c.b, gamma);

    if (luma > std.math.pow(f32, 0.5, gamma)) {
        return .{ .r = 0, .g = 0, .b = 0 };
    } else {
        return .{ .r = 1, .g = 1, .b = 1 };
    }
}
