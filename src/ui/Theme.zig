const math = @import("../math.zig");

const Color = math.Color;

colors: struct {
    accent: Color = .{ .r = 0.6, .g = 0.0, .b = 0.0 },
    accent_hover: Color = .{ .r = 0.9, .g = 0.0, .b = 0.0 },
    accent_disabled: Color = .{ .r = 0.4, .g = 0.0, .b = 0.0 },
    accent_text: Color = .black,
    surface_disabled: Color = .red,
    input_border: Color = .black,
    surface: Color = .gray(0.75),
} = .{},
focus_border: f32 = 2,
