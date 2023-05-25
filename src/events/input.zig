const std = @import("std");
const ev = @import("../util/events.zig");
const c = @import("../c.zig");

pub fn setup(win: ?*c.GLFWwindow, enabled: bool) void {
    if (enabled) {
        _ = c.glfwSetCursorPosCallback(win, cursor_pos_callback);
        _ = c.glfwSetKeyCallback(win, key_callback);
        _ = c.glfwSetCharCallback(win, char_callback);
        _ = c.glfwSetMouseButtonCallback(win, mouse_button_callback);
        _ = c.glfwSetFramebufferSizeCallback(win, framebuffer_size_callback);
        _ = c.glfwSetScrollCallback(win, scroll_callback);
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

pub fn cursor_pos_callback(_: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    ev.EventManager.instance.sendEvent(EventMouseMove{ .x = x, .y = y });
}

pub fn char_callback(_: ?*c.GLFWwindow, codepoint: c_uint) callconv(.C) void {
    ev.EventManager.instance.sendEvent(EventKeyChar{ .codepoint = codepoint, .mods = global_mods });
}

pub fn key_callback(_: ?*c.GLFWwindow, key: c_int, _: c_int, action: c_int, mods: c_int) callconv(.C) void {
    switch (action) {
        c.GLFW_PRESS => ev.EventManager.instance.sendEvent(EventKeyDown{ .key = key, .mods = mods }),
        c.GLFW_REPEAT => ev.EventManager.instance.sendEvent(EventKeyDown{ .key = key, .mods = mods }),
        c.GLFW_RELEASE => ev.EventManager.instance.sendEvent(EventKeyUp{ .key = key, .mods = mods }),
        else => {},
    }

    global_mods = mods;
}

pub fn mouse_button_callback(_: ?*c.GLFWwindow, btn: c_int, action: c_int, _: c_int) callconv(.C) void {
    switch (action) {
        c.GLFW_PRESS => ev.EventManager.instance.sendEvent(EventMouseDown{ .btn = btn }),
        c.GLFW_RELEASE => ev.EventManager.instance.sendEvent(EventMouseUp{ .btn = btn }),
        else => {},
    }
}

pub fn framebuffer_size_callback(_: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    ev.EventManager.instance.sendEvent(EventWindowResize{ .w = width, .h = height });
}

pub fn scroll_callback(_: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    ev.EventManager.instance.sendEvent(EventMouseScroll{ .x = @floatCast(f32, x), .y = @floatCast(f32, y) });
}
