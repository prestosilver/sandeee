const std = @import("std");
const col = @import("math/colors.zig");
const mat4 = @import("math/mat4.zig");
const shd = @import("shader.zig");
const allocator = @import("util/allocator.zig");
const c = @import("c.zig");

pub const Context = struct {
    window: ?*c.GLFWwindow,
    color: col.Color,
    shaders: std.ArrayList(shd.Shader),
};

pub var gContext: *Context = undefined;

export fn errorCallback(err: c_int, description: [*c]const u8) void {
    std.log.info("Error: {s}, {}\n", .{ description, err });
    std.c.exit(1);
}

pub fn init(name: [*c]const u8) Context {
    _ = c.glfwSetErrorCallback(errorCallback);

    if (c.glfwInit() == 0) {
        std.log.info("Failed to initialize GLFW\n", .{});
        std.c.exit(1);
    }

    var win = c.glfwCreateWindow(640, 480, name, null, null);

    c.glfwMakeContextCurrent(win);
    c.glfwSwapInterval(1);

    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, &c.glfwGetProcAddress)) == 0) {
        std.log.info("Failed to initialize GLAD\n", .{});
        std.c.exit(1);
    }

    var shaders = std.ArrayList(shd.Shader).init(allocator.alloc);

    return Context{
        .window = win,
        .color = col.newColorRGBA(0, 128, 128, 255),
        .shaders = shaders,
    };
}

pub fn poll(ctx: Context) bool {
    c.glfwPollEvents();
    return c.glfwWindowShouldClose(ctx.window) == 0;
}

pub fn clear(ctx: Context) void {
    c.glClearColor(ctx.color.r, ctx.color.g, ctx.color.b, ctx.color.a);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
}

pub fn swap(ctx: Context) void {
    c.glfwSwapBuffers(ctx.window);
}

pub fn regShader(ctx: *Context, s: shd.Shader) void {
    ctx.shaders.append(s) catch {};

    var proj = mat4.Mat4.ortho(0, 640, 480, 0, 100, -1);
    defer proj.deinit();

    s.setMat4("projection", proj);
}

pub fn resize(w: i32, h: i32) void {
    c.glViewport(0, 0, w, h);

    var proj = mat4.Mat4.ortho(0, @intToFloat(f32, w), @intToFloat(f32, h), 0, 100, -1);
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
