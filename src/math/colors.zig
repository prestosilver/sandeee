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
        .r = @intToFloat(f32, r) / 255,
        .g = @intToFloat(f32, g) / 255,
        .b = @intToFloat(f32, b) / 255,
        .a = @intToFloat(f32, a) / 255,
    };
}
