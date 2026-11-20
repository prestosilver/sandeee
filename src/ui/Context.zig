const std = @import("std");
const glfw = @import("glfw");

const drawers = @import("../drawers.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const ui = @import("../ui.zig");

const Animation = ui.Animation;
const Element = ui.Element;
const Theme = ui.Theme;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const log = util.log;

const Sprite = drawers.Sprite;

const Color = math.Color;
const IVec2 = math.IVec2;
const Vec2 = math.Vec2;
const Rect = math.Rect;

const CLIP_STACK_MAX = 32;
const MAX_FONTS = 64;

const Context = @This();

pub const Event = struct {
    pub const Kind = enum {
        mouse_move,
        mouse_down,
        mouse_up,
        mouse_click,
        mouse_double_click,
        mouse_enter,
        mouse_leave,
        mouse_wheel,

        key_down,
        key_up,
        text_input,

        focus_in,
        focus_out,

        change,
        submit,
        select,

        resize,
    };

    kind: Kind,
    target: *Element = undefined,
    current: *Element = undefined,
    bubbles: bool = false,
    canceled: bool = false,

    data: union {
        mouse: struct {
            pos: Vec2 = undefined,
            pos_rel: Vec2 = undefined,
            button: i32 = undefined,
            wheel: Vec2 = undefined,
        },
        key: struct {
            key: i32 = undefined,
            mods: i32 = undefined,
            repeat: bool = undefined,
        },
        text: struct {
            text: []const u8,
        },
        change: struct {
            value: f32,
            str_value: []u8,
            index: usize,
        },
        resize: struct {
            size: Vec2,
        },
    } = undefined,

    userdata: *anyopaque = undefined,

    pub const HandlerFn = *const fn (*Element, *Event, *anyopaque) bool;

    pub const Handler = struct {
        kind: Kind,
        handler: HandlerFn,
        userdata: *anyopaque,
        next: ?*Handler = null,
    };
};

// window data
sprite_batch: *SpriteBatch,
shader: *Shader,
font_shader: *Shader,
window_size: IVec2,
dpi_scale: f32 = 1.0,
offset: Vec2 = .{},
last_id: Element.Id = @fromBackingInt(0),

// clip stack
clip_stack_buf: [CLIP_STACK_MAX]?Rect = undefined,
clip_stack: std.ArrayList(?Rect),

// theme
theme: Theme = .{},

// font registry
font: *Font,

// tree
root: ?*Element = null,

// focus
focused: ?*Element = null,

// mouse state
mouse_pos: Vec2 = .{ .x = 0, .y = 0 },
mouse_buttons: std.StaticBitSet(5) = .empty,
hovered: ?*Element = null,
mouse_captured: ?*Element = null,

// animation list
animations: std.SinglyLinkedList = .{},

// timing
last_tick: u32 = 0,
delta_ms: f32 = 0,

pub fn pushClip(self: *Context, clip: Rect) void {
    const intersection: Rect = if (self.sprite_batch.scissor == null)
        clip
    else if (self.clip_stack.items.len > 0) blk: {
        const x1 = @max(self.sprite_batch.scissor.?.x, clip.x + self.offset.x);
        const y1 = @max(self.sprite_batch.scissor.?.y, clip.y + self.offset.y);
        const x2 = @max(self.sprite_batch.scissor.?.x + self.sprite_batch.scissor.?.w, clip.x + self.offset.x + clip.w);
        const y2 = @max(self.sprite_batch.scissor.?.y + self.sprite_batch.scissor.?.h, clip.y + self.offset.y + clip.h);

        break :blk .{
            .x = x1,
            .y = y1,
            .w = @max(0, x2 - x1),
            .h = @max(0, y2 - y1),
        };
    } else clip.offset(self.offset);

    self.clip_stack.appendAssumeCapacity(self.sprite_batch.scissor);
    self.sprite_batch.scissor = intersection;
}

pub fn popClip(self: *Context) void {
    self.sprite_batch.scissor = self.clip_stack.pop() orelse return;
}

pub fn drawSprite(self: *Context, sprite: *const Sprite, position: Vec2) void {
    self.sprite_batch.draw(
        Sprite,
        sprite,
        self.shader,
        position.add(self.offset).toVec3(),
    ) catch @panic("todo");
}

pub fn drawRectangle(self: *Context, bounds: Rect, color: Color) void {
    self.sprite_batch.draw(
        Sprite,
        &.atlas("white", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = bounds.w, .y = bounds.h },
            .color = color,
        }),
        self.shader,
        .{ .x = bounds.x + self.offset.x, .y = bounds.y + self.offset.y },
    ) catch @panic("todo");
}

pub fn drawRectangleOutline(self: *Context, bounds: Rect, thickness: f32, color: Color) void {
    self.drawRectangle(.{ .x = bounds.x, .y = bounds.y, .w = bounds.w, .h = thickness }, color);
    self.drawRectangle(.{ .x = bounds.x, .y = bounds.y, .w = thickness, .h = bounds.h }, color);
    self.drawRectangle(.{ .x = bounds.x, .y = bounds.y + bounds.h - thickness, .w = bounds.w, .h = thickness }, color);
    self.drawRectangle(.{ .x = bounds.x + bounds.w - thickness, .y = bounds.y, .w = thickness, .h = bounds.h }, color);
}

pub fn drawHLine(self: *Context, pos: Vec2, width: f32, color: Color) void {
    const min_x = @min(pos.x, pos.x + width);
    const max_x = @max(pos.x, pos.x + width);

    self.drawRectangle(.{ .x = min_x, .y = pos.y, .w = @max(0, max_x - min_x), .h = 1 }, color);
}

pub fn drawVLine(self: *Context, pos: Vec2, height: f32, color: Color) void {
    const min_y = @min(pos.y, pos.y + height);
    const max_y = @max(pos.y, pos.y + height);

    self.drawRectangle(.{ .x = pos.x, .y = min_y, .w = 1, .h = @max(0, max_y - min_y) }, color);
}

pub fn arrange(self: *Context) void {
    const root = self.root orelse return;

    if (!root.flags.dirty) return;

    const window_size = self.window_size.toVec2();

    const size = root.measure(.{
        .w = window_size.x,
        .h = window_size.y,
    });
    root.content_size = size;

    const full: Rect = .{
        .w = size.w,
        .h = size.h,
    };
    root.arrange(full);
    root.flags.dirty = false;
}

pub fn dispatch(self: *Context, target: *Element, event: *Event) bool {
    _ = self;

    event.target = target;
    event.bubbles = true;

    var e: ?*Element = target;
    while (e) |element| : (e = element.parent) {
        if (element.dispatch(event)) return true;
        if (event.canceled) break;
        if (!event.bubbles) break;
    }

    return false;
}

pub fn focus(self: *Context, direction: enum { next, prev }) void {
    const root = self.root orelse return;

    var focusable_buf: [512]*Element = undefined;
    var focusable: std.ArrayList(*Element) = .initBuffer(&focusable_buf);

    root.getFocusable(&focusable);

    if (focusable.items.len == 0) return;

    const less_than = struct {
        pub fn less_than(_: void, lhs: *Element, rhs: *Element) bool {
            return lhs.compareTab(.lt, rhs);
        }
    }.less_than;

    std.mem.sort(*Element, focusable.items, {}, less_than);

    const current_index: ?usize =
        for (focusable.items, 0..) |item, idx| {
            if (item == self.focused) break idx;
        } else null;

    var next_index = switch (direction) {
        .prev => if (current_index) |index|
            (if (index == 0) focusable.items.len - 1 else index - 1)
        else
            focusable.items.len - 1,

        .next => if (current_index) |index|
            index + 1
        else
            0,
    };
    if (next_index >= focusable.items.len) next_index = 0;

    self.setFocus(focusable.items[next_index]);
}

pub fn setFocus(self: *Context, new_focus: ?*Element) void {
    if (new_focus) |element| {
        if (!element.flags.focusable) return;
        if (self.focused == element) return;

        if (self.focused) |focused| {
            focused.flags.focused = false;

            var event: Event = .{
                .kind = .focus_out,
            };

            _ = self.dispatch(focused, &event);
        }

        self.focused = element;
        element.flags.focused = true;

        var event: Event = .{
            .kind = .focus_in,
        };

        _ = self.dispatch(element, &event);
    } else {
        if (self.focused) |focused| {
            focused.flags.focused = false;

            var event: Event = .{
                .kind = .focus_out,
            };

            _ = self.dispatch(focused, &event);

            self.focused = null;
        }
    }
}

pub fn draw(self: *Context, offset: Vec2) void {
    const root = self.root orelse return;

    self.offset = offset;

    root.draw();
}

pub fn mouseMove(self: *Context, pos: Vec2) void {
    self.mouse_pos = pos;

    const root = self.root orelse return;

    const target = if (self.mouse_captured) |captured|
        captured
    else
        root.hitTest(self.mouse_pos);

    if (target != self.hovered) {
        if (self.hovered) |hovered| {
            hovered.flags.hovered = false;
            var event: Event = .{
                .kind = .mouse_leave,
            };

            _ = self.dispatch(hovered, &event);
        }

        self.hovered = target;

        if (target) |hovered| {
            hovered.flags.hovered = true;
            var event: Event = .{
                .kind = .mouse_enter,
            };

            _ = self.dispatch(hovered, &event);
        }
    }

    if (target) |hovered| {
        var event: Event = .{
            .kind = .mouse_move,
            .data = .{ .mouse = .{
                .pos = pos,
                .pos_rel = .{
                    .x = pos.x - hovered.bounds_abs.x,
                    .y = pos.y - hovered.bounds_abs.y,
                },
            } },
        };

        _ = self.dispatch(hovered, &event);
    }
}

pub fn resize(self: *Context, size: IVec2) void {
    self.window_size = size;
    if (self.root) |root|
        root.markDirty();

    var event: Event = .{
        .kind = .resize,
        .data = .{ .resize = .{ .size = size.toVec2() } },
    };
    _ = self.dispatch(self.root.?, &event);
}

pub fn mouseClick(self: *Context, kind: events.input.ClickKind, button: i32) void {
    const root = self.root orelse return;

    const target = if (self.mouse_captured) |captured|
        captured
    else
        root.hitTest(self.mouse_pos);

    if (kind == .down) {
        self.setFocus(target);

        if (button == 0) {
            self.mouse_captured = target;
            if (target) |captured|
                captured.flags.pressed = true;
        }
    } else if (kind == .up) {
        if (button == 0) {
            if (self.mouse_captured) |captured|
                captured.flags.pressed = false;
            self.mouse_captured = null;
        }
    }

    if (target) |clicked| {
        var event: Event = .{
            .kind = switch (kind) {
                .down => .mouse_down,
                .up => .mouse_up,
                .double => .mouse_double_click,
                .single => .mouse_click,
            },
            .data = .{
                .mouse = .{
                    .pos = self.mouse_pos,
                    .button = button,
                },
            },
        };
        _ = self.dispatch(clicked, &event);
    }
}

pub fn globalBinds(self: *Context, key: i32, mods: i32, down: bool) void {
    if (down) {
        switch (key) {
            glfw.KeyTab => {
                self.focus(if ((mods & glfw.ModifierShift) == 0) .next else .prev);
            },
            glfw.KeyEscape => {
                self.setFocus(null);
            },
            else => {},
        }
    }
}

pub fn keyEvent(self: *Context, key: i32, mods: i32, down: bool) void {
    const target = self.focused orelse self.root orelse return;
    var event: Event = .{
        .kind = if (down) .key_down else .key_up,
        .data = .{
            .key = .{
                .key = key,
                .mods = mods,
            },
        },
    };
    if (!self.dispatch(target, &event)) {
        self.globalBinds(key, mods, down);
    }
}

pub fn textInput(self: *Context, char_string: []const u8) void {
    const target = self.focused orelse self.root orelse return;
    var event: Event = .{
        .kind = .text_input,
        .data = .{
            .text = .{
                .text = char_string,
            },
        },
    };

    _ = self.dispatch(target, &event);
}

pub fn dispatchChange(self: *Context, element: *Element) void {
    _ = self;
    _ = element;
    log.info("todo: dispatch change", .{});
}
