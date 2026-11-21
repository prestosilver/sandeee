const std = @import("std");

const math = @import("../math.zig");
const util = @import("../util.zig");
const ui = @import("../ui.zig");

const Color = math.Color;
const Rect = math.Rect;
const Vec2 = math.Vec2;

const Element = ui.Element;
const Size = ui.Element.Size;

const log = util.log;

const Panel = @This();

base: Element,
flags: packed struct(u8) {
    direction: enum(u1) { row, column } = .row,
    content_align: enum(u2) { start, center, end, stretch } = .start,
    justify: enum(u3) { start, center, end, space_between, space_around, space_evenly } = .start,
    has_shadow: bool = false,
    wrap: bool = false,
} = .{},
gap: f32 = 0,
color: Color = .gray(0.75),

border_radius: f32 = 0,
border_width: f32 = 0,
border_color: Color = .black,

has_shadow: bool = false,

pub const FOCUSABLE: bool = false;

pub fn init(self: *Panel, context: *ui.Context, name: []const u8) void {
    self.* = .{
        .base = .init(context, name, ui.Panel, .{}),
    };
}

pub fn measure(element: *const Element, avail: Size) Size {
    const self: *const Panel = @fieldParentPtr("base", element);

    var main_total: f32 = 0;
    var cross_max: f32 = 0;
    var visible_count: usize = 0;

    var child_node: ?*std.DoublyLinkedList.Node = element.children.first;
    while (child_node) |node| : (child_node = node.next) {
        const child = Element.fromNode(node);
        if (!child.flags.visible) continue;
        defer visible_count += 1;

        const avail_child: Size = .{
            .w = avail.w - element.padding.left - element.padding.right -
                element.margin.left - element.margin.right,
            .h = avail.h - element.padding.top - element.padding.bottom -
                element.margin.top - element.margin.bottom,
        };

        const child_size = child.measure(avail_child);

        log.info("child {any}", .{child_size});

        const child_outer: Size = .{
            .w = child_size.w + child.padding.left + child.padding.right +
                child.margin.left + child.margin.right,
            .h = child_size.h + child.padding.top + child.padding.bottom +
                child.padding.top + child.margin.bottom,
        };

        if (self.flags.direction == .row) {
            main_total += child_outer.w;
            cross_max = @max(child_outer.h, cross_max);
        } else {
            main_total += child_outer.h;
            cross_max = @max(child_outer.w, cross_max);
        }
    }

    const gap_total: f32 = if (visible_count > 1) self.gap * @as(f32, @floatFromInt(visible_count - 1)) else 0;

    return if (self.flags.direction == .row) .{
        .w = main_total + gap_total,
        .h = cross_max,
    } else .{
        .w = cross_max,
        .h = main_total + gap_total,
    };
}

pub fn arrange(element: *Element, bounds: Rect) void {
    _ = bounds;

    const self: *Panel = @fieldParentPtr("base", element);

    const content = element.contentRect();

    var visible_count: usize = 0;
    var expand_count: usize = 0;
    var fixed_main: f32 = 0;

    var child_node: ?*std.DoublyLinkedList.Node = element.children.first;
    while (child_node) |node| : (child_node = node.next) {
        const child = Element.fromNode(node);
        if (!child.flags.visible) continue;
        defer visible_count += 1;

        const expands = if (self.flags.direction == .row)
            child.flags.expand_w
        else
            child.flags.expand_h;

        if (expands) {
            expand_count += 1;
        } else {
            const outer = if (self.flags.direction == .row)
                child.content_size.w +
                    child.padding.left + child.padding.right +
                    child.margin.left + child.margin.right
            else
                child.content_size.h +
                    child.padding.top + child.padding.bottom +
                    child.margin.top + child.margin.bottom;
            fixed_main += outer;
        }
    }

    const gap_total: f32 = if (visible_count > 1) self.gap * @as(f32, @floatFromInt(visible_count - 1)) else 0;
    const avail_main = (if (self.flags.direction == .row) content.w else content.h) - gap_total;

    var expand_each: f32 = 0;
    if (expand_count > 0)
        expand_each = @max(0, (avail_main - fixed_main) / @as(f32, @floatFromInt(expand_count)));

    const main_used = fixed_main + gap_total + expand_each * @as(f32, @floatFromInt(expand_count));
    const main_avail = if (self.flags.direction == .row) content.w else content.h;
    const main_free = @max(0, main_avail - main_used);

    var start_pos: f32 = undefined;
    var between_gap: f32 = undefined;

    switch (self.flags.justify) {
        .start => {
            start_pos = 0;
            between_gap = 0;
        },
        .center => {
            start_pos = main_free / 2;
            between_gap = 0;
        },
        .end => {
            start_pos = main_free;
            between_gap = 0;
        },
        .space_between => {
            start_pos = 0;
            between_gap = if (visible_count > 1) main_free / @as(f32, @floatFromInt(visible_count - 1)) else 0;
        },
        .space_around => {
            between_gap = if (visible_count > 0) main_free / @as(f32, @floatFromInt(visible_count)) else 0;
            start_pos = between_gap / 2;
        },
        .space_evenly => {
            between_gap = if (visible_count > 1) main_free / @as(f32, @floatFromInt(visible_count - 1)) else 0;
            start_pos = between_gap;
        },
    }

    // position children
    var cursor: f32 = (if (self.flags.direction == .row) content.x else content.y) + start_pos;

    child_node = element.children.first;
    while (child_node) |node| : (child_node = node.next) {
        const child = Element.fromNode(node);
        if (!child.flags.visible) continue;

        const expands = if (self.flags.direction == .row)
            child.flags.expand_w
        else
            child.flags.expand_h;

        var outer_main = if (self.flags.direction == .row)
            child.content_size.w +
                child.padding.left + child.padding.right +
                child.margin.left + child.margin.right
        else
            child.content_size.h +
                child.padding.top + child.padding.bottom +
                child.margin.top + child.margin.bottom;

        if (expands) outer_main = expand_each + (if (self.flags.direction == .row)
            child.padding.left + child.padding.right +
                child.margin.left + child.margin.right
        else
            child.padding.top + child.padding.bottom +
                child.margin.top + child.margin.bottom);

        const cross_avail = if (self.flags.direction == .row) content.h else content.w;
        const outer_cross = if (self.flags.direction == .row)
            child.content_size.h +
                child.padding.top + child.padding.bottom +
                child.margin.top + child.margin.bottom
        else
            child.content_size.w +
                child.padding.left + child.padding.right +
                child.margin.left + child.margin.right;

        const cross_pos: f32 = switch (self.flags.content_align) {
            .center => (if (self.flags.direction == .row) content.y else content.x) + (cross_avail - outer_cross) / 2,
            .end => (if (self.flags.direction == .row) content.y else content.x) + cross_avail - outer_cross,
            else => if (self.flags.direction == .row) content.y else content.x,
        };

        const child_bounds_abs: Rect = if (self.flags.direction == .row) .{
            .x = cursor + child.margin.left,
            .y = cross_pos + child.margin.top,
            .w = outer_main - child.margin.left - child.margin.right,
            .h = if (self.flags.content_align == .stretch)
                cross_avail - child.margin.top - child.margin.bottom
            else
                outer_cross - child.margin.top - child.margin.bottom,
        } else .{
            .x = cross_pos + child.margin.left,
            .y = cursor + child.margin.top,
            .w = if (self.flags.content_align == .stretch)
                cross_avail - child.margin.left - child.margin.right
            else
                outer_cross - child.margin.left - child.margin.right,
            .h = outer_main - child.margin.top - child.margin.bottom,
        };

        if (self.flags.content_align == .stretch) {
            if (self.flags.direction == .row)
                child.content_size.h = child_bounds_abs.h - child.padding.top - child.padding.bottom
            else
                child.content_size.w = child_bounds_abs.w - child.padding.left - child.padding.right;
        }

        log.info("arrange {any}", .{child_bounds_abs});

        child.arrange(child_bounds_abs);

        cursor += outer_main + self.gap + between_gap;
    }
}

pub fn draw(element: *Element) void {
    const self: *Panel = @fieldParentPtr("base", element);
    const context = element.context;

    const content_rect = element.bounds_abs;

    if (content_rect.w <= 0 or content_rect.h <= 0) return;

    context.drawRectangle(content_rect, self.color);
}
