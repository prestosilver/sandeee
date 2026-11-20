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

const Scroll = @This();

const SCROLLBAR_SIZE = 8;
const SCROLLBAR_MIN_THUMB = 32;

base: Element,
content: ?*Element = null,
scroll: Vec2 = .{},
content_size: Vec2 = .{},

flags: packed struct(u8) {
    hbar_visible: bool = false,
    vbar_visible: bool = false,
    hbar_always: bool = false,
    vbar_always: bool = false,
    hbar_dragging: bool = false,
    vbar_dragging: bool = false,
    pad: u2 = undefined,
} = .{},

bar_color: Color = .gray(0.75),
bar_track_color: Color = .gray(0.5),
bar_size: f32 = 5,

pub fn measure(element: *Element, avail: Size) Size {
    const self: *Scroll = @fieldParentPtr("base", element);
    const content = self.content orelse
        return .{ .w = 0, .h = 0 };

    // HACK: dont like hardcoding the max
    const size = content.measure(.{ .w = 65535, .h = 65535 });
    self.content_size.x = size.w + element.padding.left + element.padding.right;
    self.content_size.y = size.h + element.padding.top + element.padding.bottom;

    self.flags.hbar_visible = self.flags.hbar_always | (self.content_size.x > avail.w);
    self.flags.vbar_visible = self.flags.vbar_always | (self.content_size.y > avail.h);

    return avail;
}

pub fn arrange(element: *Element, bounds: Rect) void {
    const self: *Scroll = @fieldParentPtr("base", element);
    const content = self.content orelse return;

    const viewport: Vec2 = .sub(bounds.size(), .{
        .x = if (self.flags.hbar_visible) self.bar_size else 0,
        .y = if (self.flags.vbar_visible) self.bar_size else 0,
    });
    const max_scroll_x = @max(0, self.content_size.x - viewport.x);
    const max_scroll_y = @max(0, self.content_size.y - viewport.y);
    self.scroll.x = std.math.clamp(self.scroll.x, 0, max_scroll_x);
    self.scroll.y = std.math.clamp(self.scroll.y, 0, max_scroll_y);

    const content_abs: Rect = .{
        .x = bounds.x - self.scroll.x,
        .y = bounds.y - self.scroll.y,
        .w = @max(self.content_size.x, viewport.x),
        .h = @max(self.content_size.y, viewport.y),
    };

    content.arrange(content_abs);
}

pub fn draw(element: *Element) void {
    const self: *Scroll = @fieldParentPtr("base", element);
    const context = element.context;

    draw_viewport: {
        const viewport: Vec2 = .sub(element.bounds_abs.size(), .{
            .x = if (self.flags.hbar_visible) self.bar_size else 0,
            .y = if (self.flags.vbar_visible) self.bar_size else 0,
        });
        context.pushClip(.{
            .x = element.bounds_abs.x,
            .y = element.bounds_abs.y,
            .w = viewport.x,
            .h = viewport.y,
        });
        defer context.popClip();

        const content = self.content orelse break :draw_viewport;
        if (!content.flags.visible) break :draw_viewport;

        if (content.vtable.draw) |draw_impl|
            draw_impl(content);
    }

    if (self.flags.vbar_visible) {
        // TODO: render vbar
    }

    if (self.flags.hbar_visible) {
        // TODO: render hbar
    }
}
