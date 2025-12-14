const std = @import("std");
const glfw = @import("glfw");
const zgl = @import("zgl");

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

    window: ?*glfw.Window,
    color: Color,
    shaders: std.ArrayList(Shader),
    lock: std.Thread.Mutex = .{},
    size: Vec2,

    pub inline fn makeCurrent() void {
        instance.lock.lock();
        glfw.makeContextCurrent(instance.window);
    }

    pub inline fn makeNotCurrent() void {
        glfw.makeContextCurrent(null);
        instance.lock.unlock();
    }

    pub inline fn cursorMode(val: c_int) void {
        glfw.SetInputMode(instance.window, glfw._CURSOR, val);
    }

    export fn errorCallback(err: c_int, description: [*:0]const u8) void {
        log.err("{s}, {}\n", .{ description, err });
    }

    const GfxError = error{
        GLFWInit,
        GLADInit,
    };

    pub fn getGlFn(_: void, func: [:0]const u8) ?zgl.binding.FunctionPointer {
        return @ptrCast(glfw.getProcAddress(func));
    }

    pub fn glDebug(source: zgl.DebugSource, msg_type: zgl.DebugMessageType, id: usize, severity: zgl.DebugSeverity, message: []const u8) void {
        _ = id;
        _ = msg_type;
        switch (severity) {
            .high => log.err("{}, {s}", .{ source, message }),
            else => |x| log.info("{}_{} {s} ", .{ x, source, message }),
        }
    }

    pub fn init(name: [*:0]const u8) !void {
        _ = glfw.setErrorCallback(errorCallback);

        try glfw.init();

        const monitor = glfw.getPrimaryMonitor();

        const mode = glfw.getVideoMode(monitor).?;

        glfw.windowHint(glfw.RedBits, mode.redBits);
        glfw.windowHint(glfw.GreenBits, mode.greenBits);
        glfw.windowHint(glfw.BlueBits, mode.blueBits);
        glfw.windowHint(glfw.RefreshRate, mode.refreshRate);

        const win = try glfw.createWindow(mode.width, mode.height, name, monitor, null);

        glfw.makeContextCurrent(win);

        try zgl.loadExtensions(void{}, getGlFn);
        zgl.debugMessageCallback(void{}, glDebug);

        glfw.swapInterval(1);

        const shaders = std.ArrayList(Shader).init(allocator.alloc);

        var w: c_int = 0;
        var h: c_int = 0;

        glfw.getFramebufferSize(win, &w, &h);

        glfw.setInputMode(win, glfw.Cursor, glfw.CursorHidden);

        zgl.depthFunc(.always);

        glfw.makeContextCurrent(null);

        instance = Context{
            .window = win,
            .color = .{ .r = 0, .g = 0, .b = 0 },
            .shaders = shaders,
            .size = .{ .x = @floatFromInt(w), .y = @floatFromInt(h) },
        };
    }

    pub inline fn poll() bool {
        glfw.pollEvents();
        return !glfw.windowShouldClose(instance.window);
    }

    pub inline fn clear() void {
        zgl.clearColor(instance.color.r, instance.color.g, instance.color.b, instance.color.a);
        zgl.clear(.{ .color = true });
    }

    pub inline fn swap() void {
        zgl.flush();

        glfw.swapBuffers(instance.window);
    }

    pub fn regShader(s: Shader) !void {
        try instance.shaders.append(s);

        const proj: Mat4 = .ortho(0, instance.size.x, instance.size.y, 0, 100, -1);

        s.setMat4("projection", proj);
        s.setFloat("screen_width", instance.size.x);
        s.setFloat("screen_height", instance.size.y);
    }

    pub fn resize(w: usize, h: usize) void {
        instance.size = .{ .x = @floatFromInt(w), .y = @floatFromInt(h) };

        zgl.viewport(0, 0, w, h);

        const proj: Mat4 = .ortho(0, @floatFromInt(w), @floatFromInt(h), 0, 100, -1);

        for (instance.shaders.items) |shader| {
            shader.setMat4("projection", proj);
            shader.setFloat("screen_width", @as(f32, @floatFromInt(w)));
            shader.setFloat("screen_height", @as(f32, @floatFromInt(h)));
        }
    }

    pub fn deinit() void {
        instance.shaders.deinit();
        glfw.destroyWindow(instance.window);
        glfw.terminate();
    }
};
