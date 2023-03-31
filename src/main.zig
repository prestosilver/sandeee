const std = @import("std");
const builtin = @import("builtin");

const states = @import("states/manager.zig");
const diskState = @import("states/disks.zig");
const loadingState = @import("states/loading.zig");
const windowedState = @import("states/windowed.zig");
const crashState = @import("states/crash.zig");
const installState = @import("states/installer.zig");

const fm = @import("util/files.zig");
const font = @import("util/font.zig");
const audio = @import("util/audio.zig");
const events = @import("util/events.zig");
const allocator = @import("util/allocator.zig");
const batch = @import("util/spritebatch.zig");
const gfx = @import("util/graphics.zig");
const shd = @import("util/shader.zig");
const tex = @import("util/texture.zig");

const inputEvs = @import("events/input.zig");
const windowEvs = @import("events/window.zig");
const systemEvs = @import("events/system.zig");

const worker = @import("loaders/worker.zig");

const vecs = @import("math/vecs.zig");
const rect = @import("math/rects.zig");

const wall = @import("drawers/wall2d.zig");
const sprite = @import("drawers/sprite2d.zig");
const bar = @import("drawers/bar2d.zig");
const win = @import("drawers/window2d.zig");
const cursor = @import("drawers/cursor2d.zig");

const conf = @import("system/config.zig");
const files = @import("system/files.zig");
const network = @import("system/network.zig");
const headless = @import("system/headless.zig");

const c = @import("c.zig");

// embed shaders
const vertShader = @embedFile("shaders/vert.glsl");
const fragShader = @embedFile("shaders/frag.glsl");
const fontVertShader = @embedFile("shaders/fvert.glsl");
const fontFragShader = @embedFile("shaders/ffrag.glsl");

// embed images
const logoImage = @embedFile("images/logo.eia");
const loadImage = @embedFile("images/load.eia");
const biosImage = @embedFile("images/bios.eia");
const sadImage = @embedFile("images/sad.eia");

const shader_files = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = fragShader, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = vertShader, .kind = c.GL_VERTEX_SHADER },
};

const font_shader_files = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = fontFragShader, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = fontVertShader, .kind = c.GL_VERTEX_SHADER },
};

var gameStates: std.EnumArray(systemEvs.State, states.GameState) = undefined;
var currentState: systemEvs.State = .Disks;

// create loader
var loader_queue: std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)) = undefined;
var loader = worker.WorkerContext{ .queue = &loader_queue };

// shaders
var font_shader: shd.Shader = undefined;
var shader: shd.Shader = undefined;

// screen dims
var size: vecs.Vector2 = vecs.newVec2(0, 0);

// the selected disk
var disk: ?[]u8 = null;

//
var settingManager: conf.SettingManager = undefined;

var wintex: tex.Texture = undefined;
var webtex: tex.Texture = undefined;
var bartex: tex.Texture = undefined;
var walltex: tex.Texture = undefined;
var emailtex: tex.Texture = undefined;
var editortex: tex.Texture = undefined;
var barlogotex: tex.Texture = undefined;
var explorertex: tex.Texture = undefined;
var cursortex: tex.Texture = undefined;

var ctx: gfx.Context = undefined;
var sb: batch.SpriteBatch = undefined;
var audioman: audio.Audio = undefined;

var errorMsg: []const u8 = "Error: Unknown";
var errorState: u8 = 0;

pub fn blit() !void {
    // actual gl calls start here
    ctx.makeCurrent();

    // clear the window
    gfx.clear(&ctx);

    // finish render
    try sb.render();

    c.glFlush();
    c.glFinish();

    // swap buffer
    gfx.swap(&ctx);

    // actual gl calls done
    ctx.makeNotCurrent();
}

pub fn changeState(event: systemEvs.EventStateChange) bool {
    std.log.debug("ChangeState: {}", .{event.targetState});

    currentState = event.targetState;

    // disable events on loading screen
    inputEvs.setup(ctx.window, currentState != .Loading);

    // run setup
    gameStates.getPtr(currentState).setup() catch |msg| {
        @panic(@errorName(msg));
    };

    return true;
}

pub fn keyDown(event: inputEvs.EventKeyDown) bool {
    return gameStates.getPtr(currentState).keypress(event.key, event.mods) catch false;
}

pub fn mouseDown(event: inputEvs.EventMouseDown) bool {
    gameStates.getPtr(currentState).mousepress(event.btn) catch return false;
    return false;
}

pub fn mouseUp(_: inputEvs.EventMouseUp) bool {
    gameStates.getPtr(currentState).mouserelease() catch return false;
    return false;
}

pub fn mouseMove(event: inputEvs.EventMouseMove) bool {
    gameStates.getPtr(currentState).mousemove(vecs.newVec2(@floatCast(f32, event.x), @floatCast(f32, event.y))) catch return false;
    return false;
}

pub fn mouseScroll(event: inputEvs.EventMouseScroll) bool {
    gameStates.getPtr(currentState).mousescroll(vecs.newVec2(@floatCast(f32, event.x), @floatCast(f32, event.y))) catch return false;
    return false;
}

pub fn setupEvents() !void {
    events.init();

    events.em.registerListener(inputEvs.EventWindowResize, windowResize);
    events.em.registerListener(inputEvs.EventMouseMove, mouseMove);
    events.em.registerListener(inputEvs.EventMouseDown, mouseDown);
    events.em.registerListener(inputEvs.EventMouseUp, mouseUp);
    events.em.registerListener(inputEvs.EventMouseScroll, mouseScroll);
    events.em.registerListener(inputEvs.EventKeyDown, keyDown);

    events.em.registerListener(systemEvs.EventStateChange, changeState);
}

pub fn drawLoading(self: *loadingState.GSLoading) void {
    while (!self.done) {
        // render loading screen
        self.draw(size) catch {};

        blit() catch {};
    }

    return;
}

pub fn windowResize(event: inputEvs.EventWindowResize) bool {
    ctx.makeCurrent();
    gfx.resize(event.w, event.h) catch {};
    ctx.makeNotCurrent();

    size = vecs.newVec2(@intToFloat(f32, event.w), @intToFloat(f32, event.h));

    return false;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    var trace = @errorReturnTrace();
    std.log.info("{?}", .{trace});

    errorMsg = msg;
    errorState = @enumToInt(currentState);

    if (isHeadless) {
        std.log.info("{s}, {}", .{ msg, errorState });
        std.os.exit(0);
    }

    gameStates.getPtr(currentState).deinit() catch {};

    currentState = .Crash;

    // disable events on loading screen
    inputEvs.setup(ctx.window, currentState != .Loading);

    // run setuip
    gameStates.getPtr(currentState).setup() catch {};

    while (gfx.poll(&ctx)) {
        var state = gameStates.getPtr(currentState);

        state.update(1.0 / 60.0) catch break;
        state.draw(size) catch break;

        blit() catch break;
    }
    std.os.exit(0);
}

var isHeadless = false;

pub fn main() anyerror!void {
    defer if (!builtin.link_libc or !allocator.useclib) {
        std.debug.assert(!allocator.gpa.deinit());
        std.log.debug("no leaks! :)", .{});
    };

    var args = try std.process.ArgIterator.initWithAllocator(allocator.alloc);
    _ = args.next().?;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--cwd")) {
            var path = args.next().?;
            std.log.debug("chdir: {s}", .{path});

            try std.process.changeCurDir(path);
        }
        if (std.mem.eql(u8, arg, "--headless")) {
            isHeadless = true;
        }
    }

    args.deinit();

    if (isHeadless) {
        return headless.headlessMain();
    }

    // init graphics
    ctx = try gfx.init("Sandeee");
    gfx.gContext = &ctx;
    size = ctx.size;

    var bigfontpath = fm.getContentPath("content/bios.ttf");
    defer bigfontpath.deinit();

    var biosFace: font.Font = undefined;
    var mainFace: font.Font = undefined;

    loader_queue = std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)).init();

    // shaders
    try loader.enqueue(&shader_files, &shader, worker.shader.loadShader);
    try loader.enqueue(&font_shader_files, &font_shader, worker.shader.loadShader);

    // fonts
    try loader.enqueue(&bigfontpath.items, &biosFace, worker.font.loadFont);

    // load bios
    var prog: f32 = 0;
    loader.run(&prog) catch {
        @panic("Preload Failed");
    };

    sb = try batch.newSpritebatch(&size);

    // start setup states
    ctx.makeCurrent();

    // load some textures
    var biosTex = try tex.newTextureMem(biosImage);
    var logoTex = try tex.newTextureMem(logoImage);
    var loadTex = try tex.newTextureMem(loadImage);
    var sadTex = try tex.newTextureMem(sadImage);

    // disks state
    var gsDisks = diskState.GSDisks{
        .sb = &sb,
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &biosFace,
        .disk = &disk,
        .logo_sprite = .{
            .texture = &biosTex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(168, 84),
            ),
        },
    };

    // loading state
    var gsLoading = loadingState.GSLoading{
        .sb = &sb,
        .wintex = &wintex,
        .bartex = &bartex,
        .webtex = &webtex,
        .walltex = &walltex,
        .emailtex = &emailtex,
        .editortex = &editortex,
        .cursortex = &cursortex,
        .barlogotex = &barlogotex,
        .explorertex = &explorertex,
        .face = &mainFace,
        .audio_man = &audioman,
        .ctx = &ctx,
        .loading = drawLoading,
        .logo_sprite = .{
            .texture = &logoTex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(320, 70),
            ),
        },
        .load_sprite = .{
            .texture = &loadTex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(20, 20),
            ),
        },
        .shader = &shader,
        .settingManager = &settingManager,
        .disk = &disk,
        .loader = &loader,
    };

    // windowed state
    var gsWindowed = windowedState.GSWindowed{
        .sb = &sb,
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &mainFace,
        .webtex = &webtex,
        .wintex = &wintex,
        .emailtex = &emailtex,
        .editortex = &editortex,
        .explorertex = &explorertex,
        .settingsManager = &settingManager,
        .bar_logo_sprite = .{
            .texture = &barlogotex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(36, 464),
            ),
        },
        .cursor = .{
            .texture = &cursortex,
            .data = cursor.CursorData.new(
                rect.newRect(0, 0, 1, 1),
            ),
        },
        .wallpaper = wall.Wallpaper.new(&walltex, wall.WallData{
            .dims = &size,
            .mode = .Center,
            .size = &walltex.size,
        }),
        .bar = bar.Bar.new(&bartex, bar.BarData{
            .height = 38,
            .screendims = &size,
        }),
    };

    // crashed state
    var gsCrash = crashState.GSCrash{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &biosFace,
        .sb = &sb,
        .message = &errorMsg,
        .prevState = &errorState,
        .sad_sprite = .{
            .texture = &sadTex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(150, 150),
            ),
        },
    };

    // crashed state
    var gsInstall = installState.GSInstall{
        .shader = &shader,
        .sb = &sb,
        .font_shader = &font_shader,
        .face = &biosFace,
        .load_sprite = .{
            .texture = &loadTex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(20, 32),
            ),
        },
    };

    // done states setup
    ctx.makeNotCurrent();

    // setup event system
    try setupEvents();

    // setup game states
    gameStates.set(.Disks, states.GameState.init(&gsDisks));
    gameStates.set(.Loading, states.GameState.init(&gsLoading));
    gameStates.set(.Windowed, states.GameState.init(&gsWindowed));
    gameStates.set(.Crash, states.GameState.init(&gsCrash));
    gameStates.set(.Installer, states.GameState.init(&gsInstall));

    // run setup
    try gameStates.getPtr(.Disks).setup();
    inputEvs.setup(ctx.window, true);

    win.deskSize = &size;

    var lastFrameTime = c.glfwGetTime();

    network.server = try network.Server.init();
    _ = try std.Thread.spawn(.{}, network.Server.serve, .{});

    // main loop
    while (gfx.poll(&ctx)) {
        switch (currentState) {
            .Windowed => ctx.cursorMode(c.GLFW_CURSOR_NORMAL),
            else => ctx.cursorMode(c.GLFW_CURSOR_HIDDEN),
        }

        var state = gameStates.getPtr(currentState);

        // get the time & update
        var currentTime = c.glfwGetTime();

        try state.update(@floatCast(f32, currentTime - lastFrameTime));

        // get tris
        try state.draw(size);

        // render
        try blit();

        if (state != gameStates.getPtr(currentState)) {
            try state.deinit();
        }

        // update the time
        lastFrameTime = currentTime;
    }

    try gameStates.getPtr(currentState).deinit();

    if (disk) |toFree| {
        allocator.alloc.free(toFree);
    }

    gfx.close(ctx);
    events.deinit();
    sb.deinit();
}
