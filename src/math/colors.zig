const std = @import("std");

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn mix(a: Color, b: Color, pc: f32) Color {
        var result: Color = undefined;

        result.r = a.r + (b.r - a.r) * pc;
        result.g = a.g + (b.g - a.g) * pc;
        result.b = a.b + (b.b - a.b) * pc;
        result.a = a.a + (b.a - a.a) * pc;

        return result;
    }

    pub fn contrast(c: Color) Color {
        const gamma = 2.2;
        const L = 0.2126 * std.math.pow(f32, c.r, gamma) + 0.7152 * std.math.pow(f32, c.g, gamma) + 0.0722 * std.math.pow(f32, c.b, gamma);

        if (L > std.math.pow(f32, 0.5, gamma)) {
            return newColor(0, 0, 0, 1);
        } else {
            return newColor(1, 1, 1, 1);
        }
    }
};

pub fn newColor(r: f32, g: f32, b: f32, a: f32) Color {
    return Color{
        .r = r,
        .g = g,
        .b = b,
        .a = a,
    };
}

pub fn newColorRGBA(r: u8, g: u8, b: u8, a: u8) Color {
    return Color{
        .r = @as(f32, @floatFromInt(r)) / 255,
        .g = @as(f32, @floatFromInt(g)) / 255,
        .b = @as(f32, @floatFromInt(b)) / 255,
        .a = @as(f32, @floatFromInt(a)) / 255,
    };
}
