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

const CheckBox = @This();

gap: f32 = 6,
base: Element,
label: []const u8,
checked: bool = false,
check_animation_timer: f32 = 0.0,
border_width: f32 = 2,

pub fn draw(element: *Element) void {
    const self: *CheckBox = @fieldParentPtr("base", element);
    const context = element.context;

    const box_size = context.font.size;
    const box: Rect = .{
        .x = element.bounds_abs.x,
        .y = element.bounds_abs.y + (element.bounds_abs.h - box_size) / 2,
        .w = box_size,
        .h = box_size,
    };

    const bg = if (self.checked)
        (if (!element.flags.enabled)
            context.theme.colors.accent_disabled
        else if (element.flags.hovered)
            context.theme.colors.accent_hover
        else
            context.theme.colors.accent)
    else
        (if (!element.flags.enabled)
            context.theme.colors.surface_disabled
        else
            context.theme.colors.surface);

    context.drawRectangle(box, bg);
    context.drawRectangleOutline(box, self.border_width, context.theme.colors.input_border);

    // TODO: animate
    self.check_animation_timer = if (self.checked)
        1.0
    else
        0.0;

    if (self.check_animation_timer > 0.0) {
        const check_color = context.theme.colors.accent_text.withAlpha(self.check_animation_timer);

        // TODO: render actual texture
        context.drawRectangle(box.expand(-self.border_width * 2), check_color);
    }

    if (element.flags.focused) {
        const ring = box.expand(context.theme.focus_border);
        const focus_color = context.theme.colors.accent;
        context.drawRectangleOutline(ring, context.theme.focus_border, focus_color);
    }

    if (self.label.len > 0) {
        const text_size: Vec2 = context.font.sizeText(.{
            .text = self.label,
        });
        const pos: Vec2 = .{
            .y = element.bounds_abs.y + (element.bounds_abs.h - text_size.y) / 2.0,
            .x = element.bounds_abs.x + box_size + self.gap,
        };

        context.font.draw(.{
            .pos = pos.add(context.offset),
            .shader = context.font_shader,
            .batch = context.sprite_batch,
            .text = self.label,
        }) catch unreachable;
    }
}
