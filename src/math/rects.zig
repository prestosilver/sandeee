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
