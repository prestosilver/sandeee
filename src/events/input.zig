const std = @import("std");
const c = @import("../c.zig");

pub const events = @import("mod.zig");

pub const EventManager = events.EventManager;

pub fn setup(win: ?*c.GLFWwindow, enabled: bool) void {
    if (enabled) {
        _ = c.glfwSetCursorPosCallback(win, cursorPosCallback);
        _ = c.glfwSetKeyCallback(win, keyCallback);
        _ = c.glfwSetCharCallback(win, charCallback);
        _ = c.glfwSetMouseButtonCallback(win, mouseButtonCallback);
        _ = c.glfwSetFramebufferSizeCallback(win, framebufferSizeCallback);
        _ = c.glfwSetScrollCallback(win, scrollCallback);
    } else {
        _ = c.glfwSetCursorPosCallback(win, null);
        _ = c.glfwSetKeyCallback(win, null);
        _ = c.glfwSetCharCallback(win, null);
        _ = c.glfwSetMouseButtonCallback(win, null);
        _ = c.glfwSetFramebufferSizeCallback(win, null);
        _ = c.glfwSetScrollCallback(win, null);
    }
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

pub fn cursorPosCallback(_: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    EventManager.instance.sendEvent(EventMouseMove{ .x = x, .y = y }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn charCallback(_: ?*c.GLFWwindow, codepoint: c_uint) callconv(.C) void {
    EventManager.instance.sendEvent(EventKeyChar{ .codepoint = codepoint, .mods = global_mods }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn keyCallback(_: ?*c.GLFWwindow, key: c_int, _: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = switch (action) {
        c.GLFW_PRESS => EventManager.instance.sendEvent(EventKeyDown{ .key = key, .mods = mods }),
        c.GLFW_REPEAT => EventManager.instance.sendEvent(EventKeyDown{ .key = key, .mods = mods }),
        c.GLFW_RELEASE => EventManager.instance.sendEvent(EventKeyUp{ .key = key, .mods = mods }),
        else => {},
    } catch |err| {
        @panic(@errorName(err));
    };

    global_mods = mods;
}

pub fn mouseButtonCallback(_: ?*c.GLFWwindow, btn: c_int, action: c_int, _: c_int) callconv(.C) void {
    _ = switch (action) {
        c.GLFW_PRESS => EventManager.instance.sendEvent(EventMouseDown{ .btn = btn }),
        c.GLFW_RELEASE => EventManager.instance.sendEvent(EventMouseUp{ .btn = btn }),
        else => {},
    } catch |err| {
        @panic(@errorName(err));
    };
}

pub fn framebufferSizeCallback(_: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    EventManager.instance.sendEvent(EventWindowResize{ .w = width, .h = height }) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn scrollCallback(_: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    EventManager.instance.sendEvent(EventMouseScroll{ .x = @as(f32, @floatCast(x)), .y = @as(f32, @floatCast(y)) }) catch |err| {
        @panic(@errorName(err));
    };
}
