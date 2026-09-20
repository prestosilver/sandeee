const std = @import("std");
const glfw = @import("glfw");

const math = @import("../math.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const util = @import("../util.zig");
const sandeee_data = @import("../data.zig");

const strings = sandeee_data.strings;

const Vec2 = math.Vec2;

const EventManager = events.EventManager;

const graphics = util.graphics;
const allocator = util.allocator;

pub fn setup(win: ?*glfw.Window, enabled: bool) void {
    if (!enabled) return;
    _ = glfw.setCursorPosCallback(win, cursorPosCallback);
    _ = glfw.setKeyCallback(win, keyCallback);
    _ = glfw.setCharCallback(win, charCallback);
    _ = glfw.setMouseButtonCallback(win, mouseButtonCallback);
    _ = glfw.setFramebufferSizeCallback(win, framebufferSizeCallback);
    _ = glfw.setScrollCallback(win, scrollCallback);
}

pub const ClickKind = enum { down, up, double, single };

const InputEventError = std.mem.Allocator.Error ||
    std.Io.Writer.Error || std.Io.File.Writer.Error ||
    std.Io.File.Reader.Error || std.Io.File.Reader.Error ||
    std.Io.File.SeekError || std.Io.File.OpenError ||
    std.Io.Reader.Error || system.files.FileError || util.Url.Error || error{
    FileSystem,
    BadDiskSize,
};

pub const EventMouseMove = struct {
    pub const Error = InputEventError;

    pos: Vec2,
};
pub const EventKeyDown = struct {
    pub const Error = InputEventError;

    key: i32,
    mods: i32,
};
pub const EventKeyUp = struct {
    pub const Error = InputEventError;

    key: i32,
    mods: i32,
};
pub const EventKeyChar = struct {
    pub const Error = InputEventError;

    codepoint: u32,
    mods: i32,
};
pub const EventMouseClick = struct {
    pub const Error = InputEventError;

    btn: i32,
    kind: ClickKind,
};
pub const EventDisplayResize = struct {
    pub const Error = InputEventError;

    w: i32,
    h: i32,
};
pub const EventMouseScroll = struct {
    pub const Error = InputEventError;

    x: f32,
    y: f32,
};
pub const EventClipboardCopy = struct {
    pub const Error = InputEventError;

    value: []const u8,
};
pub const EventClipboardPaste = struct {
    pub const Error = InputEventError;
};

var global_mods: i32 = 0;
var mouse_pos: Vec2 = .{};

pub fn cursorPosCallback(_: ?*glfw.Window, x: f64, y: f64) callconv(.c) void {
    mouse_pos = .{ .x = @floatCast(x), .y = @floatCast(y) };

    if (mouse_pos.x < 0)
        mouse_pos.x = 0;
    if (mouse_pos.y < 0)
        mouse_pos.y = 0;
    if (mouse_pos.x > graphics.Context.instance.size.x)
        mouse_pos.x = graphics.Context.instance.size.x;
    if (mouse_pos.y > graphics.Context.instance.size.y)
        mouse_pos.y = graphics.Context.instance.size.y;

    EventManager.event_mouse_move.send(.{ .pos = mouse_pos }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn charCallback(_: ?*glfw.Window, codepoint: c_uint) callconv(.c) void {
    EventManager.event_key_char.send(.{ .codepoint = codepoint, .mods = global_mods }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn keyCallback(_: ?*glfw.Window, key: c_int, _: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = switch (action) {
        glfw.Press => EventManager.event_key_down.send(.{ .key = key, .mods = mods }),
        glfw.Repeat => EventManager.event_key_down.send(.{ .key = key, .mods = mods }),
        glfw.Release => EventManager.event_key_up.send(.{ .key = key, .mods = mods }),
        else => {},
    } catch |err| {
        @panic(@errorName(err));
    };

    global_mods = mods;
}

pub var last_mouse_release_pos: Vec2 = .{};
pub var last_mouse_release_time: f64 = 0;
pub var is_single_click: bool = false;

pub fn mouseButtonHandle(btn: c_int, action: c_int) !void {
    const action_time = glfw.getTime();
    const time_diff = action_time - last_mouse_release_time;

    switch (action) {
        glfw.Press => {
            try EventManager.event_mouse_click.send(.{ .btn = btn, .kind = .down });

            if (time_diff < 0.1 and
                mouse_pos.distSq(last_mouse_release_pos) < 100 and
                is_single_click)
            {
                try EventManager.event_mouse_click.send(.{ .btn = btn, .kind = .double });
                is_single_click = false;
            } else {
                try EventManager.event_mouse_click.send(.{ .btn = btn, .kind = .single });
                is_single_click = true;
            }
        },
        glfw.Release => {
            defer last_mouse_release_time = action_time;
            defer last_mouse_release_pos = mouse_pos;

            try EventManager.event_mouse_click.send(.{ .btn = btn, .kind = .up });
        },
        else => {},
    }
}

pub fn mouseButtonCallback(_: ?*glfw.Window, btn: c_int, action: c_int, _: c_int) callconv(.c) void {
    _ = mouseButtonHandle(btn, action) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn framebufferSizeCallback(_: ?*glfw.Window, width: c_int, height: c_int) callconv(.c) void {
    EventManager.event_display_resize.send(.{ .w = width, .h = height }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn scrollCallback(_: ?*glfw.Window, x: f64, y: f64) callconv(.c) void {
    EventManager.event_mouse_scroll.send(.{ .x = @as(f32, @floatCast(x)), .y = @as(f32, @floatCast(y)) }) catch |err| {
        @panic(@errorName(err));
    };
}
