const std = @import("std");
const glfw = @import("glfw");

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
const Event = ui.Context.Event;
const Size = ui.Element.Size;

const Input = @This();

const INPUT_BUF_CAP = 1024;

base: Element,
input_buf: [INPUT_BUF_CAP]u8 = undefined,
input: std.ArrayList(u8),
cursor: usize = 0,

sel_start: ?usize = 0,
sel_end: usize = 0,

placeholder: []const u8,

border_width: f32 = 2.0,

scroll_x: f32 = 0.0,

caret_timer: f32 = 0.0,
caret_visible: bool = true,

password: bool = false,
max_chars: i32 = INPUT_BUF_CAP,

pub const FOCUSABLE: bool = true;

pub fn draw(element: *Element) void {
    const self: *Input = @fieldParentPtr("base", element);
    const context = element.context;

    const bg = if (element.flags.enabled)
        context.theme.colors.surface_bg
    else
        context.theme.colors.surface_disabled;

    context.drawRectangle(element.bounds_abs, bg);

    const border = if (element.flags.focused)
        context.theme.colors.border
    else
        context.theme.colors.border;

    context.drawRectangleOutline(element.bounds_abs, self.border_width, border);

    const content_rect = element.contentRect();

    const accent_color = context.theme.colors.accent;

    if (element.flags.focused) {
        const ring = element.bounds_abs.expand(context.theme.focus_border);
        context.drawRectangleOutline(ring, context.theme.focus_border, accent_color);
    }

    context.pushClip(content_rect);
    defer context.popClip();

    if (self.input.items.len == 0 and !element.flags.focused) {
        const text_size = context.font.sizeText(.{
            .text = self.placeholder,
        });

        context.font.draw(.{
            .shader = context.font_shader,
            .text = self.placeholder,
            .pos = .add(context.offset, .{
                .x = content_rect.x + self.scroll_x,
                .y = content_rect.y + (content_rect.h - text_size.y) / 2.0,
            }),
            .color = context.theme.colors.placeholder_text,
        }) catch unreachable;

        return;
    }

    const before_cursor = self.input.items[0..self.cursor];
    const cursor_px = context.font.sizeText(.{
        .text = before_cursor,
    }).x;
    if (cursor_px - self.scroll_x > content_rect.w - 4)
        self.scroll_x = cursor_px - content_rect.w + 4;
    if (cursor_px - self.scroll_x < 0)
        self.scroll_x = @max(0, cursor_px - 4);

    if (element.flags.focused) {
        if (self.sel_start) |sel_start| {
            const sel_min = @min(sel_start, self.sel_end);
            const sel_max = @max(sel_start, self.sel_end);

            const min_px = context.font.sizeText(.{
                .text = self.input.items[0..sel_min],
            }).x;
            const max_px = context.font.sizeText(.{
                .text = self.input.items[0..sel_max],
            }).x;

            context.drawRectangle(.{
                .x = content_rect.x + min_px - self.scroll_x,
                .y = content_rect.y,
                .w = max_px - min_px,
                .h = content_rect.h,
            }, context.theme.colors.accent);
        }
    }

    const text_size = context.font.sizeText(.{
        .text = self.input.items,
    });

    context.font.draw(.{
        .shader = context.font_shader,
        .text = self.input.items,
        .color = context.theme.colors.surface_text,
        .pos = .add(.{
            .x = content_rect.x - self.scroll_x,
            .y = content_rect.y + (content_rect.h - text_size.y) / 2.0,
        }, context.offset),
    }) catch unreachable;

    if (element.flags.focused) {
        if (self.caret_visible) {
            context.drawVLine(.{
                .x = content_rect.x + cursor_px - self.scroll_x,
                .y = content_rect.y + (content_rect.h - text_size.y) / 2,
            }, text_size.y, accent_color);
        }
    }
}

fn pixelToCursor(self: *Input, pixel: f32) usize {
    const context = self.base.context;

    for (0..self.input.items.len) |len| {
        const text = self.input.items[0..len];
        const width = context.font.sizeText(.{
            .text = text,
        }).x;

        if (width > pixel)
            return @max(len, 1) - 1;
    }

    return self.input.items.len;
}

fn delete(self: *Input, direction: enum { forward, backward }) void {
    if (self.sel_start) |sel_start| {
        if (sel_start == self.sel_end)
            return;

        const sel_min = @min(sel_start, self.sel_end);
        const sel_max = @max(sel_start, self.sel_end);
        const len = self.input.items.len - sel_max;
        @memmove(self.input.items[sel_min .. sel_min + len], self.input.items[sel_max..]);
        self.input.items.len -= sel_max - sel_min;
        self.sel_start = null;
        self.cursor = sel_min;

        return;
    }

    if (direction == .forward) {
        if (self.cursor < self.input.items.len)
            _ = self.input.orderedRemove(self.cursor);
    } else {
        if (self.cursor > 0) {
            _ = self.input.orderedRemove(self.cursor - 1);
            self.cursor -= 1;
        }
    }
}

pub fn onEvent(element: *Element, event: *Event, _: *anyopaque) bool {
    const self: *Input = @fieldParentPtr("base", element);
    const context = element.context;

    switch (event.kind) {
        .focus_in => {
            self.caret_visible = true;
            self.caret_timer = 0;

            return false;
        },
        .focus_out => {
            self.sel_start = null;

            return false;
        },
        .text_input => {
            if (element.flags.enabled) {
                if (self.sel_start) |sel_start| {
                    const sel_min = @min(sel_start, self.sel_end);
                    const sel_max = @max(sel_start, self.sel_end);
                    const len = self.input.items.len - sel_max;
                    @memmove(self.input.items[sel_min .. sel_min + len], self.input.items[sel_max..]);
                    self.input.items.len -= sel_max - sel_min;
                    self.sel_start = null;
                    self.cursor = sel_min;
                }

                self.input.insertSliceBounded(self.cursor, event.data.text.text) catch return true;
                self.cursor += event.data.text.text.len;

                context.dispatchChange(element, .{ .text = self.input.items });
            }

            return true;
        },
        .mouse_down => {
            if (event.data.mouse.button == 0) {
                const content_rect = element.contentRect();
                const rel_x = event.data.mouse.pos.x - content_rect.x + self.scroll_x;
                self.cursor = self.pixelToCursor(rel_x);
                self.sel_start = self.cursor;
                self.sel_end = self.cursor;
            }

            return true;
        },
        .mouse_move => {
            if (element.flags.pressed) {
                if (self.sel_start) |_| {
                    const content_rect = element.contentRect();
                    const rel_x = event.data.mouse.pos.x - content_rect.x + self.scroll_x;
                    self.cursor = self.pixelToCursor(rel_x);
                    self.sel_end = self.cursor;
                }
            }

            return true;
        },
        .key_down => {
            switch (event.data.key.key) {
                glfw.KeyLeft => {
                    // TODO: skip
                    // if (event.data.mods & glfw.ModifierControl != 0) {
                    // }
                    if (self.cursor > 0)
                        self.cursor -= 1;
                    if (event.data.key.mods & glfw.ModifierShift == 0)
                        self.sel_start = null
                    else if (self.sel_start == null)
                        self.sel_start = self.cursor + 1;

                    self.sel_end = self.cursor;
                },
                glfw.KeyRight => {
                    // TODO: skip
                    // if (event.data.mods & glfw.ModifierControl != 0) {
                    // }
                    if (self.cursor < self.input.items.len)
                        self.cursor += 1;
                    if (event.data.key.mods & glfw.ModifierShift == 0)
                        self.sel_start = null
                    else if (self.sel_start == null)
                        self.sel_start = self.cursor - 1;

                    self.sel_end = self.cursor;
                },
                // TODO: key home
                // TODO: key end
                glfw.KeyBackspace => {
                    if (element.flags.enabled) {
                        self.delete(.backward);
                        context.dispatchChange(element, .{ .text = self.input.items });
                    }
                },
                glfw.KeyDelete => {
                    if (element.flags.enabled) {
                        self.delete(.forward);
                        context.dispatchChange(element, .{ .text = self.input.items });
                    }
                },
                glfw.KeyEnter => {
                    var ev: Event = .{
                        .kind = .submit,
                    };
                    return context.dispatch(element, &ev);
                },
                glfw.KeyA => {
                    if (event.data.key.mods & glfw.ModifierControl != 0) {
                        self.sel_start = 0;
                        self.sel_end = self.input.items.len;
                        self.cursor = self.sel_end;
                    }
                },
                // TODO: ctrl c
                // TODO: ctrl x
                // TODO: ctrl v
                else => {},
            }
        },
        else => {},
    }

    return false;
}

pub fn measure(element: *Element, _: Size) Size {
    return .{ .w = 0, .h = element.context.font.size };
}
