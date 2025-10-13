const std = @import("std");
const c = @import("../c.zig");

const math = @import("../math/mod.zig");
const util = @import("mod.zig");

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;
const Color = math.Color;

const Texture = util.Texture;
const Shader = util.Shader;
const allocator = util.allocator;
const log = util.log;

pub const Context = struct {
    pub var instance: Context = undefined;

    window: ?*c.GLFWwindow,
    color: Color,
    shaders: std.ArrayList(Shader),
    lock: std.Thread.Mutex = .{},
    size: Vec2,

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
        c.glfwWindowHint(c.GLFW_REFRESH_RATE, mode.refreshRate);

        const win = c.glfwCreateWindow(mode.width, mode.height, name, monitor, null);

        c.glfwMakeContextCurrent(win);

        c.glfwSwapInterval(1);

        if (c.gladLoadGLLoader(@as(c.GLADloadproc, @ptrCast(&c.glfwGetProcAddress))) == 0) {
            return error.GLADInitFailed;
        }

        const shaders = std.ArrayList(Shader).init(allocator.alloc);

        var w: c_int = 0;
        var h: c_int = 0;

        c.glfwGetFramebufferSize(win, &w, &h);

        c.glfwSetInputMode(win, c.GLFW_CURSOR, c.GLFW_CURSOR_HIDDEN);

        c.glDepthFunc(c.GL_ALWAYS);

        c.glfwMakeContextCurrent(null);

        instance = Context{
            .window = win,
            .color = .{ .r = 0, .g = 0, .b = 0 },
            .shaders = shaders,
            .size = .{ .x = @floatFromInt(w), .y = @floatFromInt(h) },
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

    pub fn regShader(s: Shader) !void {
        try instance.shaders.append(s);

        const proj: Mat4 = .ortho(0, instance.size.x, instance.size.y, 0, 100, -1);

        s.setMat4("projection", proj);
        s.setFloat("screen_width", instance.size.x);
        s.setFloat("screen_height", instance.size.y);
    }

    pub fn resize(w: i32, h: i32) void {
        instance.size = .{ .x = @floatFromInt(w), .y = @floatFromInt(h) };

        c.glViewport(0, 0, w, h);

        const proj: Mat4 = .ortho(0, @floatFromInt(w), @floatFromInt(h), 0, 100, -1);

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
