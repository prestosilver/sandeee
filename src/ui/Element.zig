const std = @import("std");
const builtin = @import("builtin");

const util = @import("../util.zig");
const math = @import("../math.zig");
const ui = @import("../ui.zig");

const Context = ui.Context;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const log = util.log;

const Rect = math.Rect;
const Vec2 = math.Vec2;

const allocator = util.allocator;

const Element = @This();

const UI_DEBUG = true;
const MAX_ITERATOR_DEPTH = 256;

// This is based off of this blog
// https://0xkiire.com/gui_guide/

const Event = Context.Event;

const VTable = struct {
    measure: ?*const fn (*Element, Size) Size = null, // avail space
    arrange: ?*const fn (*Element, Rect) void = null, // bounds
    draw: ?*const fn (*Element) void = null,
    onEvent: ?*const fn (*Element, *Event, userdata: *anyopaque) bool = null,
    deinit: ?*const fn (*Element) void = null,
};

const Flags = packed struct {
    visible: bool = true,
    enabled: bool = true,
    hovered: bool = false,
    pressed: bool = false,
    focused: bool = false,
    dirty: bool = true,
    clip: bool = false,
    focusable: bool = false,
    selected: bool = false,
    expand_w: bool = false,
    expand_h: bool = false,
};

const Insets = struct {
    top: f32 = 0.0,
    bottom: f32 = 0.0,
    left: f32 = 0.0,
    right: f32 = 0.0,

    pub fn all(value: f32) Insets {
        return .{
            .top = value,
            .bottom = value,
            .left = value,
            .right = value,
        };
    }

    pub const none: Insets = .all(0);

    pub fn fromCfg(value: anytype) Insets {
        if (@TypeOf(value) == comptime_float or @TypeOf(value) == comptime_int) {
            return .all(value);
        }

        @compileError("todo");
    }
};

pub const Size = struct {
    w: f32 = wrap,
    h: f32 = wrap,

    pub fn toVec2(self: Size) Vec2 {
        return .{
            .x = self.w,
            .y = self.h,
        };
    }

    pub fn fromCfg(value: anytype) Size {
        return .{
            .w = if (@hasField(@TypeOf(value), "w"))
                if (@TypeOf(value.w) == @EnumLiteral())
                    @field(Size, @tagName(value.w))
                else
                    value.w
            else
                wrap,
            .h = if (@hasField(@TypeOf(value), "h"))
                if (@TypeOf(value.h) == @EnumLiteral())
                    @field(Size, @tagName(value.h))
                else
                    value.h
            else
                wrap,
        };
    }

    pub const zero: Size = .{ .w = 0, .h = 0 };
    pub const wrap: f32 = -1;
    pub const fill: f32 = -2;
};

const Iterator = struct {
    stack: [256]*Element = undefined,
    top: usize = 0,

    pub fn next(self: Iterator) ?*Element {
        if (self.top == 0) return null;

        self.top -= 1;
        const element = self.stack[self.top];

        var c = element.children.last;
        while (c) |child| : (c = child.prev) {
            const elem = Element.fromNode(child);
            self.stack[self.top + 1] = elem;
            self.top += 1;
        }

        return element;
    }
};

pub const Id = enum(u32) {
    _,

    pub fn next(context: *Context) Id {
        const result = context.last_id;

        const val = @backingInt(context.last_id);
        context.last_id = @fromBackingInt(val +% 1);

        return result;
    }
};

// identity
context: *Context,
vtable: *const VTable = &.{},
id: Id,
name: []const u8,

// tree
parent: ?*Element = null,
children: std.DoublyLinkedList = .{},
siblings: std.DoublyLinkedList.Node = .{},
children_count: usize = 0,

// layout input
desired_size: Size = .{ .w = Size.wrap, .h = Size.wrap },
margin: Insets = .none,
padding: Insets = .none,
min_size: Vec2 = .{ .x = 0, .y = 0 },
max_size: Vec2 = .{ .x = std.math.inf(f32), .y = std.math.inf(f32) },

// layout computed
bounds: Rect = .{ .w = 0, .h = 0 },
bounds_abs: Rect = .{ .w = 0, .h = 0 },
content_size: Size = .{ .w = 0, .h = 0 },

// state
flags: Flags = .{},

// event handlers
handlers: ?*Event.Handler = null,

tab_index: u32 = 0,

pub fn fromNode(node: *std.DoublyLinkedList.Node) *Element {
    return @fieldParentPtr("siblings", node);
}

pub fn addChild(self: *Element, child: *Element) void {
    if (child.parent != null)
        removeFromTree(child);

    child.parent = self;
    self.children.append(&child.siblings);
    self.children_count += 1;
    self.markDirty();
}

pub fn removeFromTree(self: *Element) void {
    const parent = self.parent orelse return;
    parent.children.remove(&self.siblings);

    self.parent = null;
    parent.children_count -= 1;

    parent.markDirty();
}

pub fn deinit(self: *Element) void {
    if (self.context.focused == self) self.context.focused = null;
    if (self.context.hovered == self) self.context.hovered = null;
    if (self.context.mouse_captured == self) self.context.mouse_captured = null;

    const child_node = self.children.first;
    while (child_node) |child| : (child_node = child.next) {
        const elem: *Element = .fromNode(child);
        elem.parent = null;
        elem.deinit();
        allocator.free(elem);
    }

    if (self.vtable.deinit) |deinit_fn|
        deinit_fn(self);
}

pub fn markDirty(self: *Element) void {
    var current: ?*Element = self;
    while (current) |elem| : (current = elem.parent) {
        elem.flags.dirty = true;
    }
}

pub fn setVisible(self: *Element, visible: bool) void {
    self.flags.visible = visible;
    self.markDirty();
}

pub fn setEnabled(self: *Element, enabled: bool) void {
    self.flags.enabled = enabled;
}

pub fn iterator(self: *Element) Iterator {
    var result = .{
        .top = 1,
    };

    result.stack[0] = self;

    return result;
}

pub fn contentRect(self: *const Element) Rect {
    var result = self.bounds_abs;
    result.x += self.padding.left;
    result.y += self.padding.top;
    result.w -= self.padding.left + self.padding.right;
    result.h -= self.padding.top + self.padding.bottom;

    result.w = @max(result.w, 0);
    result.h = @max(result.h, 0);

    return result.round();
}

pub fn measure(self: *Element, avail: Size) Size {
    if (!self.flags.visible) {
        self.content_size = .{ .w = 0, .h = 0 };
        return .zero;
    }

    var size: Size = .{
        .w = avail.w - self.padding.left - self.padding.right,
        .h = avail.h - self.padding.top - self.padding.bottom,
    };

    size.w = @max(size.w, 0);
    size.h = @max(size.h, 0);

    if (self.vtable.measure) |measure_impl|
        self.content_size = measure_impl(self, size);

    if (self.desired_size.w > 0)
        self.content_size.w = self.desired_size.w - self.padding.left - self.padding.right;

    if (self.desired_size.h > 0)
        self.content_size.h = self.desired_size.h - self.padding.top - self.padding.bottom;

    if (self.desired_size.w == Size.fill)
        self.content_size.w = avail.w - self.padding.left - self.padding.right;

    if (self.desired_size.h == Size.fill)
        self.content_size.h = avail.h - self.padding.top - self.padding.bottom;

    var total_w = self.content_size.w + self.padding.left + self.padding.right;
    var total_h = self.content_size.h + self.padding.top + self.padding.bottom;
    total_w = std.math.clamp(total_w, self.min_size.x, self.max_size.x);
    total_h = std.math.clamp(total_h, self.min_size.y, self.max_size.y);
    self.content_size.w = total_w - self.padding.left - self.padding.right;
    self.content_size.h = total_h - self.padding.top - self.padding.bottom;

    return self.content_size;
}

pub fn arrange(self: *Element, bounds_abs: Rect) void {
    self.bounds_abs = bounds_abs;
    self.bounds = bounds_abs;

    if (!self.flags.visible) return;
    if (self.vtable.arrange) |arrange_impl|
        arrange_impl(self, bounds_abs);
}

pub fn onEvent(self: *Element, kind: Event.Kind, handler: Event.HandlerFn, userdata: *anyopaque) !void {
    const handler_node = try allocator.create(Event.Handler);
    handler_node.* = .{
        .kind = kind,
        .handler = handler,
        .userdata = userdata,
        .next = self.handlers,
    };
    self.handlers = handler_node;
}

pub fn dispatch(self: *Element, event: *Event) bool {
    if (self.vtable.onEvent) |ev|
        if (ev(self, event, undefined))
            return true;

    var current = self.handlers;
    while (current) |handler| : (current = handler.next) {
        if (handler.kind == event.kind) {
            if (handler.handler(self, event, handler.userdata)) return true;
        }
    }

    return false;
}

pub fn getFocusable(self: *Element, out: *std.ArrayList(*Element)) void {
    if (!self.flags.visible) return;
    if (self.flags.focusable)
        out.appendAssumeCapacity(self);

    var c = self.children.first;
    while (c) |child| : (c = child.next) {
        const elem = Element.fromNode(child);
        elem.getFocusable(out);
    }
}

pub fn compareTab(a: *Element, op: std.math.CompareOperator, b: *Element) bool {
    if (a.tab_index != b.tab_index)
        return std.math.compare(a.tab_index, op, b.tab_index);

    return std.math.compare(@backingInt(a.id), op, @backingInt(b.id));
}

pub fn init(context: *Context, name: []const u8, Child: type, flags: struct {
    desired_size: Size = .{ .w = Size.wrap, .h = Size.wrap },
    margin: Insets = .none,
    padding: Insets = .none,
    min_size: Vec2 = .{ .x = 0, .y = 0 },
    max_size: Vec2 = .{ .x = std.math.inf(f32), .y = std.math.inf(f32) },
    expand_w: bool = false,
    expand_h: bool = false,
    focusable: ?bool = null,
    enabled: bool = true,
    visible: bool = true,
}) Element {
    const gen = VTable{
        .measure = if (@hasDecl(Child, "measure")) Child.measure else null,
        .arrange = if (@hasDecl(Child, "arrange")) Child.arrange else null,
        .draw = if (@hasDecl(Child, "draw")) Child.draw else null,
        .onEvent = if (@hasDecl(Child, "onEvent")) Child.onEvent else null,
        .deinit = if (@hasDecl(Child, "deinit")) Child.deinit else null,
    };
    return .{
        .context = context,
        .id = .next(context),
        .name = name,
        .vtable = &gen,
        .flags = .{
            .expand_w = flags.expand_w,
            .expand_h = flags.expand_h,
            .focusable = flags.focusable orelse Child.FOCUSABLE,
            .enabled = flags.enabled,
            .visible = flags.visible,
        },
        .desired_size = flags.desired_size,
        .margin = flags.margin,
        .padding = flags.padding,
        .min_size = flags.min_size,
        .max_size = flags.max_size,
    };
}

pub fn draw(self: *Element) void {
    if (!self.flags.visible) return;

    if (self.flags.clip) self.context.pushClip(self.bounds_abs);
    defer if (self.flags.clip) self.context.popClip();

    if (self.vtable.draw) |draw_impl|
        draw_impl(self);

    if (UI_DEBUG) blk: {
        if (self.bounds_abs.w == 0 or self.bounds_abs.h == 0) break :blk;
        self.context.drawRectangleOutline(self.bounds_abs.round(), 3, .red);
        self.context.drawRectangleOutline(self.contentRect().round(), 2, .green);
    }

    var c = self.children.first;
    while (c) |child| : (c = child.next) {
        const elem = Element.fromNode(child);
        elem.draw();
    }
}

pub fn hitTest(self: *Element, pos: Vec2) ?*Element {
    if (!self.flags.visible) return null;

    if (!self.bounds_abs.contains(pos))
        return null;

    var c = self.children.last;
    while (c) |child| : (c = child.prev) {
        const elem = Element.fromNode(child);
        if (elem.hitTest(pos)) |hit|
            return hit;
    }

    return self;
}

pub const Handlers = struct {
    pub fn resizeWithMax(self: *Element, ev: *Event, _: *anyopaque) bool {
        self.desired_size.w = ev.data.resize.size.x;
        self.desired_size.h = ev.data.resize.size.y;

        self.markDirty();

        return false;
    }
};
