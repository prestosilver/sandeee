const vec = @import("vecs.zig");

pub const Rectangle = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    w: f32,
    h: f32,

    pub const Corner = enum {
        TopLeft,
        TopRight,
        BotLeft,
        BotRight,
    };

    pub inline fn getCorner(self: Rectangle, corner: Corner) vec.Vector2 {
        return switch (corner) {
            .TopLeft => .{ .x = self.x, .y = self.y },
            .TopRight => .{ .x = self.x + self.w, .y = self.y },
            .BotLeft => .{ .x = self.x, .y = self.y + self.h },
            .BotRight => .{ .x = self.x + self.w, .y = self.y + self.h },
        };
    }

    pub inline fn equal(self: Rectangle, other: Rectangle) bool {
        return self.x == other.x and
            self.y == other.y and
            self.w == other.w and
            self.h == other.h;
    }

    pub inline fn contains(self: Rectangle, v: vec.Vector2) bool {
        return self.x <= v.x and self.y <= v.y and self.x + self.w > v.x and self.y + self.h > v.y;
    }

    pub inline fn containsWhole(self: Rectangle, v: Rectangle) bool {
        return self.contains(v.location()) and self.contains(v.location().add(v.size()));
    }

    pub inline fn containsSome(self: Rectangle, v: Rectangle) bool {
        return self.contains(v.location()) or self.contains(v.location().add(v.size()));
    }

    pub inline fn location(self: Rectangle) vec.Vector2 {
        return .{ .x = self.x, .y = self.y };
    }

    pub inline fn size(self: Rectangle) vec.Vector2 {
        return .{ .x = self.w, .y = self.h };
    }

    pub inline fn round(self: Rectangle) Rectangle {
        return .{
            .x = @round(self.x),
            .y = @round(self.y),
            .w = @round(self.w),
            .h = @round(self.h),
        };
    }

    pub inline fn initCentered(parent: Rectangle, w: f32, h: f32) Rectangle {
        return Rectangle{
            .x = parent.x + (parent.w - w) / 2,
            .y = parent.y + (parent.h - h) / 2,
            .w = w,
            .h = h,
        };
    }
};

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
};

pub const Border = struct {
    l: f32 = 0,
    r: f32 = 0,
    t: f32 = 0,
    b: f32 = 0,
};
