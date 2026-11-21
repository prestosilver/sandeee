const math = @import("../math.zig");

const Color = math.Color;

colors: struct {
    surface_bg: Color = .white,
    surface_disabled: Color = .gray(0.75),
    surface_hover: Color = .gray(0.6),
    surface_text: Color = .black,

    app_bg: Color = .gray(0.75),
    app_text: Color = .black,

    raised_bg: Color = .gray(0.75),
    raised_hover: Color = .gray(0.7),
    raised_text: Color = .black,
    raised_disabled: Color = .gray(0.5),

    lowered_bg: Color = .gray(0.5),
    lowered_text: Color = .black,

    placeholder_text: Color = .gray(0.5),

    warn_text: Color = .red,

    border: Color = .black,
    border_hover: Color = .black,

    accent: Color = .{ .r = 0.8, .g = 0.0, .b = 0.0 },
} = .{},
focus_border: f32 = 2,
