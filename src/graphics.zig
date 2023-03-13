const std = @import("std");
const col = @import("math/colors.zig");
const mat4 = @import("math/mat4.zig");
const vecs = @import("math/vecs.zig");
const shd = @import("shader.zig");
const tex = @import("texture.zig");
const allocator = @import("util/allocator.zig");
const c = @import("c.zig");

pub var palette: tex.Texture = undefined;
pub var gContext: *Context = undefined;

pub const Context = struct {
    window: ?*c.GLFWwindow,
    color: col.Color,
    shaders: std.ArrayList(shd.Shader),
    lock: std.Thread.Mutex = undefined,
    size: vecs.Vector2,

    pub fn makeCurrent(self: *Context) void {
        self.lock.lock();
        c.glfwMakeContextCurrent(self.window);
    }

    pub fn makeNotCurrent(self: *Context) void {
        c.glfwMakeContextCurrent(null);
        self.lock.unlock();
    }
};

export fn errorCallback(err: c_int, description: [*c]const u8) void {
    std.log.info("Error: {s}, {}\n", .{ description, err });
    std.c.exit(1);
}

const GfxError = error{
    GLFWInit,
    GLADInit,
};

pub fn init(name: [*c]const u8) !Context {
    _ = c.glfwSetErrorCallback(errorCallback);

    if (c.glfwInit() == 0) {
        return error.GLFWInit;
    }

    var monitor = c.glfwGetPrimaryMonitor();

    var mode = c.glfwGetVideoMode(monitor)[0];

    var win = c.glfwCreateWindow(mode.width, mode.height, name, null, null);
    c.glfwSetWindowMonitor(win, monitor, 0, 0, mode.width, mode.height, mode.refreshRate);

    c.glfwMakeContextCurrent(win);
    c.glfwSwapInterval(1);

    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, &c.glfwGetProcAddress)) == 0) {
        return error.GLADInit;
    }

    var shaders = std.ArrayList(shd.Shader).init(allocator.alloc);

    //c.glfwSetInputMode(win, c.GLFW_CURSOR, c.GLFW_CURSOR_HIDDEN);

    var w: c_int = 0;
    var h: c_int = 0;

    c.glfwGetFramebufferSize(win, &w, &h);

    c.glfwMakeContextCurrent(null);

    return Context{
        .window = win,
        .color = col.newColorRGBA(0, 0, 0, 255),
        .shaders = shaders,
        .size = vecs.newVec2(@intToFloat(f32, w), @intToFloat(f32, h)),
    };
}

pub fn poll(ctx: *Context) bool {
    c.glfwPollEvents();
    return c.glfwWindowShouldClose(ctx.window) == 0;
}

pub fn clear(ctx: *Context) void {
    c.glClearColor(ctx.color.r, ctx.color.g, ctx.color.b, ctx.color.a);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
}

pub fn swap(ctx: *Context) void {
    c.glfwSwapBuffers(ctx.window);
}

pub fn regShader(ctx: *Context, s: shd.Shader) !void {
    try ctx.shaders.append(s);

    var proj = try mat4.Mat4.ortho(0, ctx.size.x, ctx.size.y, 0, 100, -1);
    defer proj.deinit();

    s.setMat4("projection", proj);
    s.setInt("palette", 1);
}

pub fn resize(w: i32, h: i32) !void {
    gContext.size = vecs.newVec2(@intToFloat(f32, w), @intToFloat(f32, h));

    c.glViewport(0, 0, w, h);

    var proj = try mat4.Mat4.ortho(0, @intToFloat(f32, w), @intToFloat(f32, h), 0, 100, -1);
    defer proj.deinit();

    for (gContext.shaders.items) |shader| {
        shader.setMat4("projection", proj);
    }
}

pub fn close(ctx: Context) void {
    ctx.shaders.deinit();
    c.glfwDestroyWindow(ctx.window);
    c.glfwTerminate();
}
