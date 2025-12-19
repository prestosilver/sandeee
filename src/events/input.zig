const std = @import("std");
const glfw = @import("glfw");

pub const events = @import("mod.zig");

pub const EventManager = events.EventManager;

pub fn setup(win: ?*glfw.Window, enabled: bool) void {
    if (!enabled) return;
    _ = glfw.setCursorPosCallback(win, cursorPosCallback);
    _ = glfw.setKeyCallback(win, keyCallback);
    _ = glfw.setCharCallback(win, charCallback);
    _ = glfw.setMouseButtonCallback(win, mouseButtonCallback);
    _ = glfw.setFramebufferSizeCallback(win, framebufferSizeCallback);
    _ = glfw.setScrollCallback(win, scrollCallback);
}

pub const EventMouseMove = struct { x: f64, y: f64 };
pub const EventKeyDown = struct { key: i32, mods: i32 };
pub const EventKeyUp = struct { key: i32, mods: i32 };
pub const EventMouseDown = struct { btn: i32 };
pub const EventMouseUp = struct { btn: i32 };
pub const EventWindowResize = struct { w: i32, h: i32 };
pub const EventMouseScroll = struct { x: f32, y: f32 };
pub const EventKeyChar = struct { codepoint: u32, mods: i32 };

var global_mods: i32 = 0;

pub fn cursorPosCallback(_: ?*glfw.Window, x: f64, y: f64) callconv(.c) void {
    EventManager.instance.sendEvent(EventMouseMove{ .x = x, .y = y }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn charCallback(_: ?*glfw.Window, codepoint: c_uint) callconv(.c) void {
    EventManager.instance.sendEvent(EventKeyChar{ .codepoint = codepoint, .mods = global_mods }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn keyCallback(_: ?*glfw.Window, key: c_int, _: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = switch (action) {
        glfw.Press => EventManager.instance.sendEvent(EventKeyDown{ .key = key, .mods = mods }),
        glfw.Repeat => EventManager.instance.sendEvent(EventKeyDown{ .key = key, .mods = mods }),
        glfw.Release => EventManager.instance.sendEvent(EventKeyUp{ .key = key, .mods = mods }),
        else => {},
    } catch |err| {
        @panic(@errorName(err));
    };

    global_mods = mods;
}

pub fn mouseButtonCallback(_: ?*glfw.Window, btn: c_int, action: c_int, _: c_int) callconv(.c) void {
    _ = switch (action) {
        glfw.Press => EventManager.instance.sendEvent(EventMouseDown{ .btn = btn }),
        glfw.Release => EventManager.instance.sendEvent(EventMouseUp{ .btn = btn }),
        else => {},
    } catch |err| {
        @panic(@errorName(err));
    };
}

pub fn framebufferSizeCallback(_: ?*glfw.Window, width: c_int, height: c_int) callconv(.c) void {
    EventManager.instance.sendEvent(EventWindowResize{ .w = width, .h = height }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn scrollCallback(_: ?*glfw.Window, x: f64, y: f64) callconv(.c) void {
    EventManager.instance.sendEvent(EventMouseScroll{ .x = @as(f32, @floatCast(x)), .y = @as(f32, @floatCast(y)) }) catch |err| {
        @panic(@errorName(err));
    };
}
