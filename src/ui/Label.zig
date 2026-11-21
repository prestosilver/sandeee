const std = @import("std");

const math = @import("../math.zig");
const util = @import("../util.zig");
const ui = @import("../ui.zig");

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
text: []const u8 = "",
color: Color = .black,
h_align: enum { left, center, right } = .left,
v_align: enum { top, center, bottom } = .top,
scale: f32 = 1.0,
wrap: ?f32 = null,

pub const FOCUSABLE: bool = false;

pub fn init(self: *Label, context: *ui.Context, name: []const u8) void {
    self.* = .{
        .base = .init(context, name, ui.Label, .{}),
    };
}

pub fn measure(element: *const Element, _: Size) Size {
    const self: *const Label = @fieldParentPtr("base", element);

    if (self.text.len == 0)
        return .{ .w = 0, .h = 0 };

    const size = element.context.font.sizeText(.{
        .text = self.text,
        .wrap = self.wrap,
        .scale = self.scale,
    });

    log.info("text '{s}' size {any}", .{ self.text, size });

    return .{
        .w = size.x,
        .h = size.y,
    };
}

pub fn draw(element: *Element) void {
    const self: *Label = @fieldParentPtr("base", element);
    const context = element.context;

    if (self.text.len == 0) return;

    const content_rect = element.contentRect();
    if (content_rect.w <= 0 or content_rect.h <= 0) return;

    context.pushClip(content_rect);
    defer context.popClip();

    context.font.draw(.{
        .pos = content_rect.getCorner(.top_left).add(context.offset),
        .shader = context.font_shader,
        .batch = context.sprite_batch,
        .text = self.text,
        .wrap = self.wrap,
        .scale = self.scale,
        .color = self.color,
    }) catch unreachable;
}

pub fn setText(self: *Label, text: []const u8) void {
    self.text = text;
    self.base.markDirty();
}
