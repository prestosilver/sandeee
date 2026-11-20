const std = @import("std");

const drawers = @import("../drawers.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const ui = @import("../ui.zig");

const Sprite = drawers.Sprite;

const Color = math.Color;
const Rect = math.Rect;
const Vec2 = math.Vec2;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const log = util.log;

const Context = ui.Context;
const Element = ui.Element;
const Size = ui.Element.Size;

const Label = @This();

base: Element,
sprite: Sprite,
h_align: enum { left, center, right } = .left,
v_align: enum { top, center, bottom } = .top,

pub fn measure(element: *const Element, _: Size) Size {
    const self: *const Label = @fieldParentPtr("base", element);

    return .{
        .w = self.sprite.data.size.x,
        .h = self.sprite.data.size.y,
    };
}

pub fn draw(element: *Element) void {
    const self: *Label = @fieldParentPtr("base", element);
    const context = element.context;

    if (self.sprite.data.size.x == 0 or self.sprite.data.size.y == 0) return;

    const content_rect = element.contentRect();
    if (content_rect.w <= 0 or content_rect.h <= 0) return;

    context.pushClip(content_rect);
    defer context.popClip();

    const x = switch (self.h_align) {
        .left => content_rect.x,
        .center => content_rect.x + (content_rect.w - self.sprite.data.size.x) / 2.0,
        .right => content_rect.x + (content_rect.w - self.sprite.data.size.x),
    };
    const y = switch (self.v_align) {
        .top => content_rect.y,
        .center => content_rect.y + (content_rect.h - self.sprite.data.size.y) / 2.0,
        .bottom => content_rect.y + (content_rect.h - self.sprite.data.size.y),
    };

    context.drawSprite(&self.sprite, .{ .x = x, .y = y });
}
