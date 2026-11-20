const math = @import("../math.zig");

const Rect = math.Rect;

offsetXMin: f32,
offsetXMax: f32,
offsetYMin: f32,
offsetYMax: f32,

anchorXMin: f32,
anchorXMax: f32,
anchorYMin: f32,
anchorYMax: f32,

const UIRect = @This();

pub fn toRect(self: UIRect, parent: Rect) Rect {
    const axmin = parent.x + (parent.w * self.anchorXMin);
    const aymin = parent.y + (parent.h * self.anchorYMin);
    const axmax = parent.x + (parent.w * self.anchorXMax);
    const aymax = parent.y + (parent.h * self.anchorYMax);

    return .{
        .x = self.offsetXMin + axmin,
        .y = self.offsetYMin + aymin,
        .w = self.offsetXMax + axmax - self.offsetXMin - axmin,
        .h = self.offsetYMax + aymax - self.offsetYMin - aymin,
    };
}
