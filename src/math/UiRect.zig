const math = @import("root");

const Rect = math.Rect;

offsetXMin: f32,
offsetXMax: f32,
offsetYMin: f32,
offsetYMax: f32,

anchorXMin: f32,
anchorXMax: f32,
anchorYMin: f32,
anchorYMax: f32,

parent: *union(Type) {
    const Type = enum {
        Rect,
        UIRect,
    };

    Rect: Rect,
    UIRect: UIRect,
},

const UIRect = @This();

pub fn toRect(self: UIRect) Rect {
    const parent = switch (self.parent) {
        .Rect => self.parent.Rect,
        .UIRect => self.parent.UIRect.toRect(),
    };

    const axmin = parent.x + (parent.width * self.anchorXMin);
    const aymin = parent.y + (parent.height * self.anchorYMin);
    const axmax = parent.x + (parent.width * self.anchorXMax);
    const aymax = parent.y + (parent.height * self.anchorYMax);

    return .{
        .x = self.offsetXMin + axmin,
        .y = self.offsetYMin + aymin,
        .w = self.offsetXMax + axmax - self.offsetXMin - axmin,
        .h = self.offsetYMax + aymax - self.offsetYMin - aymin,
    };
}
