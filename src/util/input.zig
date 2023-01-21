const std = @import("std");
const ev = @import("events.zig");
const c = @import("../c.zig");

pub var em: ev.EventManager = undefined;

pub fn setup(win: ?*c.GLFWwindow) void {
    em = ev.EventManager.init();

    _ = c.glfwSetCursorPosCallback(win, cursor_pos_callback);
    _ = c.glfwSetKeyCallback(win, key_callback);
    _ = c.glfwSetMouseButtonCallback(win, mouse_button_callback);
    _ = c.glfwSetFramebufferSizeCallback(win, framebuffer_size_callback);
}

pub const EventMouseMove = struct { x: f64, y: f64 };
pub const EventKeyDown = struct { key: i32, mods: i32 };
pub const EventKeyUp = struct { key: i32, mods: i32 };
pub const EventMouseDown = struct { btn: i32 };
pub const EventMouseUp = struct { btn: i32 };
pub const EventWindowResize = struct { w: i32, h: i32 };

pub fn cursor_pos_callback(_: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    em.sendEvent(EventMouseMove, EventMouseMove{ .x = x, .y = y });
}

pub fn key_callback(_: ?*c.GLFWwindow, key: c_int, _: c_int, action: c_int, mods: c_int) callconv(.C) void {
    switch (action) {
        c.GLFW_PRESS => em.sendEvent(EventKeyDown, EventKeyDown{ .key = key, .mods = mods}),
        c.GLFW_REPEAT => em.sendEvent(EventKeyDown, EventKeyDown{ .key = key, .mods = mods}),
        c.GLFW_RELEASE => em.sendEvent(EventKeyUp, EventKeyUp{ .key = key, .mods = mods }),
        else => {},
    }
}

pub fn mouse_button_callback(_: ?*c.GLFWwindow, btn: c_int, action: c_int, _: c_int) callconv(.C) void {
    switch (action) {
        c.GLFW_PRESS => em.sendEvent(EventMouseDown, EventMouseDown{ .btn = btn }),
        c.GLFW_RELEASE => em.sendEvent(EventMouseUp, EventMouseUp{ .btn = btn }),
        else => {},
    }
}

pub fn framebuffer_size_callback(_: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    em.sendEvent(EventWindowResize, EventWindowResize{ .w = width, .h = height });
}
