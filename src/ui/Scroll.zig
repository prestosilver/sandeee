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
const Event = ui.Context.Event;
const Size = ui.Element.Size;

const Scroll = @This();

const SCROLLBAR_MIN_THUMB = 32;
const SCROLL_SPEED = 40;

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

drag_start_scroll: f32 = 0,
drag_start_mouse: f32 = 0,

bar_color: Color = .gray(0.75),
bar_track_color: Color = .gray(0.5),
bar_size: f32 = 16,
bar_pad: f32 = 2,

pub const FOCUSABLE: bool = false;

pub fn measure(element: *Element, avail: Size) Size {
    const self: *Scroll = @fieldParentPtr("base", element);

    // HACK: dont like hardcoding the max
    const content_size = if (self.content) |content|
        content.measure(.{ .w = 65535, .h = 65535 })
    else
        Size{ .w = 0, .h = 0 };
    self.content_size.x = content_size.w + element.padding.left + element.padding.right;
    self.content_size.y = content_size.h + element.padding.top + element.padding.bottom;

    self.flags.hbar_visible = self.flags.hbar_always | (self.content_size.x > avail.w);
    self.flags.vbar_visible = self.flags.vbar_always | (self.content_size.y > avail.h);

    std.log.info("h{} v{}", .{ self.flags.hbar_visible, self.flags.vbar_visible });

    return avail;
}

pub fn arrange(element: *Element, bounds: Rect) void {
    const self: *Scroll = @fieldParentPtr("base", element);
    const content = self.content orelse return;

    const viewport: Vec2 = bounds.size().sub(.{
        .x = if (self.flags.vbar_visible) self.bar_size else 0,
        .y = if (self.flags.hbar_visible) self.bar_size else 0,
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

    const viewport: Vec2 = element.bounds_abs.size().sub(.{
        .x = if (self.flags.vbar_visible) self.bar_size else 0,
        .y = if (self.flags.hbar_visible) self.bar_size else 0,
    });

    draw_viewport: {
        context.pushClip(.{
            .x = element.bounds_abs.x,
            .y = element.bounds_abs.y,
            .w = viewport.x,
            .h = viewport.y,
        });
        defer context.popClip();

        const content = self.content orelse break :draw_viewport;

        content.draw();
    }

    if (self.flags.vbar_visible) {
        const track: Rect = .{
            .x = element.bounds_abs.x + viewport.x,
            .y = element.bounds_abs.y,
            .w = self.bar_size,
            .h = viewport.y,
        };
        context.drawRectangle(track, context.theme.colors.lowered_bg);

        const ratio = std.math.clamp(viewport.y / self.content_size.y, 0, 1);
        const thumb_h = @max(SCROLLBAR_MIN_THUMB, viewport.y * ratio);
        var thumb_y = self.scroll.y / self.content_size.y * viewport.y;
        thumb_y = std.math.clamp(thumb_y, 0, viewport.y - thumb_h);

        const thumb: Rect = .{
            .x = element.bounds_abs.x + viewport.x + self.bar_pad,
            .y = element.bounds_abs.y + thumb_y + self.bar_pad,
            .w = self.bar_size - self.bar_pad * 2,
            .h = thumb_h - self.bar_pad * 2,
        };
        context.drawRectangle(thumb, context.theme.colors.raised_bg);
    }

    if (self.flags.hbar_visible) {
        const track: Rect = .{
            .x = element.bounds_abs.x,
            .y = element.bounds_abs.y + viewport.y,
            .w = viewport.x,
            .h = self.bar_size,
        };
        context.drawRectangle(track, context.theme.colors.lowered_bg);

        const ratio = std.math.clamp(viewport.x / self.content_size.x, 0, 1);
        const thumb_w = @max(SCROLLBAR_MIN_THUMB, viewport.x * ratio);
        var thumb_x = self.scroll.x / self.content_size.x * viewport.x;
        thumb_x = std.math.clamp(thumb_x, 0, viewport.x - thumb_w);

        const thumb: Rect = .{
            .x = element.bounds_abs.x + thumb_x + self.bar_pad,
            .y = element.bounds_abs.y + viewport.y + self.bar_pad,
            .w = thumb_w - self.bar_pad * 2,
            .h = self.bar_size - self.bar_pad * 2,
        };
        context.drawRectangle(thumb, context.theme.colors.raised_bg);
    }
}

pub fn onEvent(element: *Element, event: *Event, _: *anyopaque) bool {
    const self: *Scroll = @fieldParentPtr("base", element);
    const context = element.context;

    switch (event.kind) {
        .mouse_wheel => {
            // TODO: check if shift is pressed
            self.scroll.y -= event.data.mouse.wheel.y * SCROLL_SPEED;
            element.markDirty();

            return true;
        },
        .mouse_down => {
            if (event.data.mouse.button == 0) {
                const viewport: Vec2 = element.bounds_abs.size().sub(.{
                    .x = if (self.flags.vbar_visible) self.bar_size else 0,
                    .y = if (self.flags.hbar_visible) self.bar_size else 0,
                });

                if (self.flags.vbar_visible) {
                    const track: Rect = .{
                        .x = element.bounds_abs.x + viewport.x,
                        .y = element.bounds_abs.y,
                        .w = self.bar_size,
                        .h = viewport.y,
                    };
                    if (track.contains(event.data.mouse.pos)) {
                        self.flags.vbar_dragging = true;
                        self.drag_start_scroll = self.scroll.y;
                        self.drag_start_mouse = event.data.mouse.pos.y;
                        context.mouse_captured = element;
                        return true;
                    }
                }

                if (self.flags.hbar_visible) {
                    const track: Rect = .{
                        .x = element.bounds_abs.x,
                        .y = element.bounds_abs.y + viewport.y,
                        .w = viewport.x,
                        .h = self.bar_size,
                    };
                    if (track.contains(event.data.mouse.pos)) {
                        self.flags.hbar_dragging = true;
                        self.drag_start_scroll = self.scroll.x;
                        self.drag_start_mouse = event.data.mouse.pos.x;
                        context.mouse_captured = element;

                        return true;
                    }
                }
            }
        },
        .mouse_move => {
            const viewport: Vec2 = element.bounds_abs.size().sub(.{
                .x = if (self.flags.vbar_visible) self.bar_size else 0,
                .y = if (self.flags.hbar_visible) self.bar_size else 0,
            });

            if (self.flags.vbar_dragging) {
                const delta = event.data.mouse.pos.y - self.drag_start_mouse;
                const ratio = self.content_size.y / viewport.y;
                self.scroll.y = self.drag_start_scroll + (delta * ratio);
                element.markDirty();
                return true;
            }

            if (self.flags.hbar_dragging) {
                const delta = event.data.mouse.pos.x - self.drag_start_mouse;
                const ratio = self.content_size.x / viewport.x;
                self.scroll.x = self.drag_start_scroll + (delta * ratio);
                element.markDirty();
                return true;
            }
        },
        .mouse_up => {
            self.flags.vbar_dragging = false;
            self.flags.hbar_dragging = false;
            if (context.mouse_captured == element) context.mouse_captured = null;
        },
        else => {},
    }

    return false;
}
