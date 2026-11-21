const std = @import("std");
const glfw = @import("glfw");

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
const Event = ui.Context.Event;
const Size = ui.Element.Size;

const Button = @This();

base: Element,
label: []const u8,
icon: ?Sprite = null,
style: enum { filled, outlined, text, icon } = .filled,
gap: f32 = 6,

border_width: f32 = 2,

animation_timer: f32 = 0.0,
bg_current: Color = .white,
fg_current: Color = .white,

pub const FOCUSABLE: bool = true;

pub fn measure(element: *const Element, _: Size) Size {
    const self: *const Button = @fieldParentPtr("base", element);

    const text_size: Vec2 = element.context.font.sizeText(.{
        .text = self.label,
    });
    const icon_size: Vec2 = if (self.icon) |icon| icon.data.size else .{};

    var total_size: Size = if (text_size.x > 0 and icon_size.x > 0) .{
        .w = text_size.x + self.gap + icon_size.x,
        .h = @max(text_size.y, icon_size.y),
    } else .{
        .w = text_size.x + icon_size.x,
        .h = @max(text_size.y, icon_size.y),
    };

    total_size.w = @max(total_size.w, 32);
    total_size.h = @max(total_size.h, 16);

    return total_size;
}

pub fn draw(element: *Element) void {
    const self: *Button = @fieldParentPtr("base", element);
    const context = element.context;

    var bg: Color = undefined;
    var fg: Color = undefined;
    var border: Color = undefined;
    if (!element.flags.enabled) {
        bg = context.theme.colors.raised_disabled;
        fg = context.theme.colors.raised_text;
        border = context.theme.colors.border;
    } else if (element.flags.pressed) {
        bg = context.theme.colors.lowered_bg;
        fg = context.theme.colors.lowered_text;
        border = context.theme.colors.border_hover;
    } else if (element.flags.hovered) {
        // bg = self.bg_normal.mix(self.bg_hover, self.animation_timer);
        // fg = self.fg_normal.mix(self.fg_hover, self.animation_timer);
        bg = context.theme.colors.raised_hover;
        fg = context.theme.colors.raised_text;
        border = context.theme.colors.border_hover;
    } else {
        //bg = self.bg_hover.mix(self.bg_normal, 1.0 - self.animation_timer);
        bg = context.theme.colors.raised_bg;
        fg = context.theme.colors.raised_text;
        border = context.theme.colors.border_hover;
    }

    switch (self.style) {
        .filled => {
            context.drawRectangle(element.bounds_abs, bg);
            context.drawRectangleOutline(element.bounds_abs, self.border_width, border);
        },
        .outlined => {
            if (element.flags.hovered or element.flags.pressed) {
                context.drawRectangle(element.bounds_abs, bg.withAlpha(0.1));
            }
            context.drawRectangleOutline(element.bounds_abs, self.border_width, border);
        },
        .text => {
            if (element.flags.hovered or element.flags.pressed) {
                context.drawRectangle(element.bounds_abs, bg.withAlpha(0.1));
            }
        },
        .icon => {},
    }

    if (element.flags.focused) {
        const ring = element.bounds_abs.expand(context.theme.focus_border);
        const focus_color = context.theme.colors.accent;
        context.drawRectangleOutline(ring, context.theme.focus_border, focus_color);
    }

    const content_rect = element.contentRect();

    if (self.icon) |icon| {
        const icon_y = content_rect.y + (content_rect.h - icon.data.size.y) / 2.0;
        context.drawSprite(&icon, .{
            .x = content_rect.x,
            .y = icon_y,
        });
    }

    if (self.label.len > 0) {
        const text_size: Vec2 = context.font.sizeText(.{
            .text = self.label,
        });
        const pos: Vec2 = .{
            .y = content_rect.y + (content_rect.h - text_size.y) / 2.0,
            .x = content_rect.x + if (self.icon) |icon| icon.data.size.x + self.gap else 0,
        };
        context.font.draw(.{
            .shader = context.font_shader,
            .text = self.label,
            .pos = pos.add(context.offset),
        }) catch unreachable;
    }
}

pub fn onEvent(element: *Element, event: *Event, _: *anyopaque) bool {
    const context = element.context;

    switch (event.kind) {
        .key_down => {
            if (event.data.key.key == glfw.KeySpace or
                event.data.key.key == glfw.KeyEnter)
                if (element.flags.enabled) {
                    var ev: Event = .{
                        .kind = .mouse_click,
                    };
                    return context.dispatch(element, &ev);
                };
        },
        else => {},
    }

    return false;
}
