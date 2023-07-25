const std = @import("std");
const col = @import("../math/colors.zig");
const mat4 = @import("../math/mat4.zig");
const vecs = @import("../math/vecs.zig");
const shd = @import("../util/shader.zig");
const tex = @import("../util/texture.zig");
const allocator = @import("allocator.zig");
const c = @import("../c.zig");

pub var palette: tex.Texture = undefined;
pub var gContext: *Context = undefined;

pub const Context = struct {
    window: ?*c.GLFWwindow,
    color: col.Color,
    shaders: std.ArrayList(shd.Shader),
    lock: std.Thread.Mutex = .{},
    size: vecs.Vector2,

    pub fn makeCurrent(self: *Context) void {
        self.lock.lock();
        c.glfwMakeContextCurrent(self.window);
    }

    pub fn makeNotCurrent(self: *Context) void {
        c.glfwMakeContextCurrent(null);
        self.lock.unlock();
    }

    pub fn cursorMode(ctx: *Context, val: c_int) void {
        c.glfwSetInputMode(ctx.window, c.GLFW_CURSOR, val);
    }
};

export fn errorCallback(err: c_int, description: [*c]const u8) void {
    std.log.info("Error: {s}, {}\n", .{ description, err });
    //@panic("GLFW Error");
}

const GfxError = error{
    GLFWInit,
    GLADInit,
};

pub fn init(name: [*c]const u8) !Context {
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

    return Context{
        .window = win,
        .color = col.newColorRGBA(0, 0, 0, 255),
        .shaders = shaders,
        .size = vecs.newVec2(@as(f32, @floatFromInt(w)), @as(f32, @floatFromInt(h))),
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
    c.glFinish();
    c.glFlush();

    c.glfwSwapBuffers(ctx.window);
}

pub fn regShader(ctx: *Context, s: shd.Shader) !void {
    try ctx.shaders.append(s);

    const proj = try mat4.Mat4.ortho(0, ctx.size.x, ctx.size.y, 0, 100, -1);

    s.setMat4("projection", proj);
    s.setFloat("screen_width", ctx.size.x);
    s.setFloat("screen_height", ctx.size.y);
}

pub fn resize(w: i32, h: i32) !void {
    gContext.size = vecs.newVec2(@as(f32, @floatFromInt(w)), @as(f32, @floatFromInt(h)));

    c.glViewport(0, 0, w, h);

    const proj = try mat4.Mat4.ortho(0, @as(f32, @floatFromInt(w)), @as(f32, @floatFromInt(h)), 0, 100, -1);

    for (gContext.shaders.items) |shader| {
        shader.setMat4("projection", proj);
        shader.setFloat("screen_width", @as(f32, @floatFromInt(w)));
        shader.setFloat("screen_height", @as(f32, @floatFromInt(h)));
    }
}

pub fn close(ctx: Context) void {
    ctx.shaders.deinit();
    c.glfwDestroyWindow(ctx.window);
    c.glfwTerminate();
}
