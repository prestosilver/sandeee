const vec = @import("vecs.zig");

pub const Rectangle = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn equal(self: Rectangle, other: Rectangle) bool {
        return self.x == other.x and
            self.y == other.y and
            self.w == other.w and
            self.h == other.h;
    }

    pub fn contains(self: Rectangle, v: vec.Vector2) bool {
        return self.x <= v.x and self.y <= v.y and self.x + self.w > v.x and self.y + self.h > v.y;
    }

    pub fn location(self: Rectangle) vec.Vector2 {
        return vec.newVec2(self.x, self.y);
    }

    pub fn size(self: Rectangle) vec.Vector2 {
        return vec.newVec2(self.w, self.h);
    }
};

pub fn newRect(x: f32, y: f32, w: f32, h: f32) Rectangle {
    return Rectangle{
        .x = x,
        .y = y,
        .w = w,
        .h = h,
    };
}

pub const UIRectangle = struct {
    offsetXMin: f32,
    offsetXMax: f32,
    offsetYMin: f32,
    offsetYMax: f32,

    anchorXMin: f32,
    anchorXMax: f32,
    anchorYMin: f32,
    anchorYMax: f32,

    parent: *union(ParentType) {
        Rect: Rectangle,
        UIRect: UIRectangle,
    },

    pub const ParentType = enum {
        Rect,
        UIRect,
    };

    pub fn toRect(self: UIRectangle) Rectangle {
        const parent = switch (self.parent) {
            .Rect => self.parent.Rect,
            .UIRect => self.parent.UIRect.toRect(),
        };

        const axmin = parent.x.float32 + (parent.width.float32 * self.anchorXMin);
        const aymin = parent.y.float32 + (parent.height.float32 * self.anchorYMin);
        const axmax = parent.x.float32 + (parent.width.float32 * self.anchorXMax);
        const aymax = parent.y.float32 + (parent.height.float32 * self.anchorYMax);

        return .{
            .x = self.offsetXMin + axmin,
            .y = self.offsetYMin + aymin,
            .w = self.offsetXMax + axmax - self.offsetXMin - axmin,
            .h = self.offsetYMax + aymax - self.offsetYMin - aymin,
        };
    }
};
