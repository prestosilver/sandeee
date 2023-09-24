const std = @import("std");
const col = @import("../math/colors.zig");
const mat4 = @import("../math/mat4.zig");
const vecs = @import("../math/vecs.zig");
const shd = @import("../util/shader.zig");
const tex = @import("../util/texture.zig");
const allocator = @import("allocator.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

pub const Context = struct {
    pub var instance: Context = undefined;

    window: ?*c.GLFWwindow,
    color: col.Color,
    shaders: std.ArrayList(shd.Shader),
    lock: std.Thread.Mutex = .{},
    size: vecs.Vector2,

    pub inline fn makeCurrent() void {
        instance.lock.lock();
        c.glfwMakeContextCurrent(instance.window);
    }

    pub inline fn makeNotCurrent() void {
        c.glfwMakeContextCurrent(null);
        instance.lock.unlock();
    }

    pub inline fn cursorMode(val: c_int) void {
        c.glfwSetInputMode(instance.window, c.GLFW_CURSOR, val);
    }

    export fn errorCallback(err: c_int, description: [*c]const u8) void {
        log.err("{s}, {}\n", .{ description, err });
    }

    const GfxError = error{
        GLFWInit,
        GLADInit,
    };

    pub fn init(name: [*c]const u8) !void {
        _ = c.glfwSetErrorCallback(errorCallback);

        if (c.glfwInit() == 0) {
            return error.GLFWInitFailed;
        }

        const monitor = c.glfwGetPrimaryMonitor();

        const mode = c.glfwGetVideoMode(monitor)[0];

        c.glfwWindowHint(c.GLFW_RED_BITS, mode.redBits);
        c.glfwWindowHint(c.GLFW_GREEN_BITS, mode.greenBits);
        c.glfwWindowHint(c.GLFW_BLUE_BITS, mode.blueBits);
        c.glfwWindowHint(c.GLFW_REFRESH_RATE, 60);

        const win = c.glfwCreateWindow(mode.width, mode.height, name, monitor, null);

        c.glfwMakeContextCurrent(win);

        c.glfwSwapInterval(1);

        if (c.gladLoadGLLoader(@as(c.GLADloadproc, @ptrCast(&c.glfwGetProcAddress))) == 0) {
            return error.GLADInitFailed;
        }

        const shaders = std.ArrayList(shd.Shader).init(allocator.alloc);

        var w: c_int = 0;
        var h: c_int = 0;

        c.glfwGetFramebufferSize(win, &w, &h);

        c.glfwSetInputMode(win, c.GLFW_CURSOR, c.GLFW_CURSOR_HIDDEN);

        c.glfwMakeContextCurrent(null);

        instance = Context{
            .window = win,
            .color = col.newColorRGBA(0, 0, 0, 255),
            .shaders = shaders,
            .size = vecs.newVec2(@as(f32, @floatFromInt(w)), @as(f32, @floatFromInt(h))),
        };
    }

    pub inline fn poll() bool {
        c.glfwPollEvents();
        return c.glfwWindowShouldClose(instance.window) == 0;
    }

    pub inline fn clear() void {
        c.glClearColor(instance.color.r, instance.color.g, instance.color.b, instance.color.a);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
    }

    pub inline fn swap() void {
        c.glFinish();
        c.glFlush();

        c.glfwSwapBuffers(instance.window);
    }

    pub fn regShader(s: shd.Shader) !void {
        try instance.shaders.append(s);

        const proj = try mat4.Mat4.ortho(0, instance.size.x, instance.size.y, 0, 100, -1);

        s.setMat4("projection", proj);
        s.setFloat("screen_width", instance.size.x);
        s.setFloat("screen_height", instance.size.y);
    }

    pub fn resize(w: i32, h: i32) !void {
        instance.size = vecs.newVec2(@as(f32, @floatFromInt(w)), @as(f32, @floatFromInt(h)));

        c.glViewport(0, 0, w, h);

        const proj = try mat4.Mat4.ortho(0, @as(f32, @floatFromInt(w)), @as(f32, @floatFromInt(h)), 0, 100, -1);

        for (instance.shaders.items) |shader| {
            shader.setMat4("projection", proj);
            shader.setFloat("screen_width", @as(f32, @floatFromInt(w)));
            shader.setFloat("screen_height", @as(f32, @floatFromInt(h)));
        }
    }

    pub fn deinit() void {
        instance.shaders.deinit();
        c.glfwDestroyWindow(instance.window);
        c.glfwTerminate();
    }
};
