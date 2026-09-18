const math = @import("../math.zig");

const Color = math.Color;

pub const FONT_COLORS = [16]Color{
    .black,
    .mix(.white, .black, 0.5),
    .mix(.red, .black, 0.5),
    .mix(.yellow, .black, 0.5),
    .mix(.green, .black, 0.5),
    .mix(.cyan, .black, 0.5),
    .mix(.blue, .black, 0.5),
    .mix(.magenta, .black, 0.5),
    .black,
    .white,
    .red,
    .yellow,
    .green,
    .cyan,
    .blue,
    .magenta,
};
