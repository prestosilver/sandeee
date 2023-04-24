const std = @import("std");
const builtin = @import("builtin");

const states = @import("states/manager.zig");
const diskState = @import("states/disks.zig");
const loadingState = @import("states/loading.zig");
const windowedState = @import("states/windowed.zig");
const crashState = @import("states/crash.zig");
const installState = @import("states/installer.zig");
const recoveryState = @import("states/recovery.zig");

const fm = @import("util/files.zig");
const font = @import("util/font.zig");
const audio = @import("util/audio.zig");
const events = @import("util/events.zig");
const allocator = @import("util/allocator.zig");
const batch = @import("util/spritebatch.zig");
const gfx = @import("util/graphics.zig");
const shd = @import("util/shader.zig");
const tex = @import("util/texture.zig");
const panicHandler = @import("util/panic.zig");

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

const crtFragShader = @embedFile("shaders/crtfrag.glsl");
const crtVertShader = @embedFile("shaders/crtvert.glsl");

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

const crt_shader_files = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = crtFragShader, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = crtVertShader, .kind = c.GL_VERTEX_SHADER },
};

var gameStates: std.EnumArray(systemEvs.State, states.GameState) = undefined;
var currentState: systemEvs.State = .Disks;

// create loader
var loader_queue: std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)) = undefined;
var loader = worker.WorkerContext{ .queue = &loader_queue };

// shaders
var font_shader: shd.Shader = undefined;
var crt_shader: shd.Shader = undefined;
var shader: shd.Shader = undefined;

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
var scrolltex: tex.Texture = undefined;

var ctx: gfx.Context = undefined;
var sb: batch.SpriteBatch = undefined;
var audioman: audio.Audio = undefined;

var errorMsg: []const u8 = "Error: Unknown";
var errorState: u8 = 0;

var framebufferName: c.GLuint = 0;
var quad_VertexArrayID: c.GLuint = 0;
var renderedTexture: c.GLuint = 0;
var depthrenderbuffer: c.GLuint = 0;

const full_quad = [_]c.GLfloat{
    -1.0, -1.0, 0.0,
    1.0,  -1.0, 0.0,
    -1.0, 1.0,  0.0,
    -1.0, 1.0,  0.0,
    1.0,  -1.0, 0.0,
    1.0,  1.0,  0.0,
};

pub fn blit() !void {
    // actual gl calls start here
    ctx.makeCurrent();

    if (c.glfwGetWindowAttrib(gfx.gContext.window, c.GLFW_ICONIFIED) != 0) {
        // TODO: No signal indicator

        // for when minimized render nothing
        gfx.clear(&ctx);

        gfx.swap(&ctx);

        ctx.makeNotCurrent();

        return;
    }
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebufferName);

    // clear the window
    c.glBindTexture(c.GL_TEXTURE_2D, renderedTexture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @floatToInt(i32, ctx.size.x), @floatToInt(i32, ctx.size.y), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    // Poor filtering. Needed !
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);

    c.glBindRenderbuffer(c.GL_RENDERBUFFER, depthrenderbuffer);
    c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, @floatToInt(i32, ctx.size.x), @floatToInt(i32, ctx.size.y));
    c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depthrenderbuffer);

    c.glFramebufferTexture(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, renderedTexture, 0);

    c.glDrawBuffers(1, &[_]c.GLenum{c.GL_COLOR_ATTACHMENT0});

    if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE)
        return error.FramebufferSetupFail;

    c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebufferName);

    gfx.clear(&ctx);

    // finish render
    try sb.render();

    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_VertexArrayID);
    c.glBindTexture(c.GL_TEXTURE_2D, renderedTexture);

    c.glUseProgram(crt_shader.id);
    crt_shader.setFloat("time", @floatCast(f32, c.glfwGetTime()));

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 3 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);
    c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

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
    return gameStates.getPtr(currentState).keypress(event.key, event.mods, true) catch false;
}

pub fn keyUp(event: inputEvs.EventKeyUp) bool {
    return gameStates.getPtr(currentState).keypress(event.key, event.mods, false) catch false;
}

pub fn keyChar(event: inputEvs.EventKeyChar) bool {
    gameStates.getPtr(currentState).keychar(event.codepoint, event.mods) catch return false;
    return false;
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
    events.em.registerListener(inputEvs.EventMouseScroll, mouseScroll);
    events.em.registerListener(inputEvs.EventMouseMove, mouseMove);
    events.em.registerListener(inputEvs.EventMouseDown, mouseDown);
    events.em.registerListener(inputEvs.EventMouseUp, mouseUp);
    events.em.registerListener(inputEvs.EventKeyDown, keyDown);
    events.em.registerListener(inputEvs.EventKeyChar, keyChar);
    events.em.registerListener(inputEvs.EventKeyUp, keyUp);

    events.em.registerListener(systemEvs.EventStateChange, changeState);
}

pub fn drawLoading(self: *loadingState.GSLoading) void {
    while (!self.done) {
        // render loading screen
        self.draw(gfx.gContext.size) catch {};

        blit() catch {};
    }

    return;
}

pub fn windowResize(event: inputEvs.EventWindowResize) bool {
    ctx.makeCurrent();
    gfx.resize(event.w, event.h) catch {};
    ctx.makeNotCurrent();

    return false;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    errorState = @enumToInt(currentState);

    var st = panicHandler.log();
    errorMsg = std.fmt.allocPrint(allocator.alloc, "{s}\n{s}", .{ msg, st }) catch {
        std.os.exit(0);
    };

    std.log.info("{s}", .{errorMsg});

    if (isHeadless) {
        std.os.exit(0);
    }

    defer gameStates.getPtr(@intToEnum(systemEvs.State, errorState)).deinit() catch {};

    // disable events on loading screen
    inputEvs.setup(ctx.window, true);

    // run setup
    gameStates.getPtr(.Crash).setup() catch {};

    while (gfx.poll(&ctx)) {
        var state = gameStates.getPtr(.Crash);

        state.update(1.0 / 60.0) catch break;
        state.draw(gfx.gContext.size) catch break;

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
    var headlessCmd: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--cwd")) {
            var path = args.next().?;
            std.log.debug("chdir: {s}", .{path});

            try std.process.changeCurDir(path);
        }
        if (std.mem.eql(u8, arg, "--headless")) {
            isHeadless = true;
        }
        if (std.mem.eql(u8, arg, "--headless-cmd")) {
            var script = args.next().?;
            var buff = try allocator.alloc.alloc(u8, 1024);
            var file = try std.fs.cwd().openFile(script, .{});

            var len = try file.readAll(buff);
            headlessCmd = buff[0..len];
            file.close();

            isHeadless = true;
        }
    }

    args.deinit();

    if (isHeadless) {
        return headless.headlessMain(headlessCmd, false, null);
    }

    // init graphics
    ctx = try gfx.init("Sandeee");
    gfx.gContext = &ctx;

    var biosFace: font.Font = undefined;
    var mainFace: font.Font = undefined;

    loader_queue = std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)).init();

    // shaders
    try loader.enqueue(&crt_shader_files, &crt_shader, worker.shader.loadShader);
    try loader.enqueue(&shader_files, &shader, worker.shader.loadShader);
    try loader.enqueue(&font_shader_files, &font_shader, worker.shader.loadShader);

    // fonts
    const biosFont: []const u8 = @embedFile("images/main.eff");
    try loader.enqueue(&biosFont, &biosFace, worker.font.loadFont);

    // load bios
    var prog: f32 = 0;
    loader.run(&prog) catch {
        @panic("Preload Failed");
    };

    // start setup states
    ctx.makeCurrent();

    // setup double buffer rendering
    c.glGenFramebuffers(1, &framebufferName);
    c.glGenBuffers(1, &quad_VertexArrayID);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_VertexArrayID);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c.GLsizeiptr, full_quad.len * @sizeOf(f32)), &full_quad, c.GL_DYNAMIC_DRAW);
    c.glGenTextures(1, &renderedTexture);
    c.glGenRenderbuffers(1, &depthrenderbuffer);

    sb = try batch.newSpritebatch(&gfx.gContext.size);
    // load some textures
    var biosTex = try tex.newTextureMem(biosImage);
    var logoTex = try tex.newTextureMem(logoImage);
    var loadTex = try tex.newTextureMem(loadImage);
    var sadTex = try tex.newTextureMem(sadImage);

    audioman = try audio.Audio.init();

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
        .scrolltex = &scrolltex,
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
                vecs.newVec2(320, 64),
            ),
        },
        .load_sprite = .{
            .texture = &loadTex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(10, 10),
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
        .scrolltex = &scrolltex,
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
                6,
            ),
        },
        .wallpaper = wall.Wallpaper.new(&walltex, wall.WallData{
            .dims = &gfx.gContext.size,
            .mode = .Center,
            .size = &walltex.size,
        }),
        .bar = bar.Bar.new(&bartex, bar.BarData{
            .height = 38,
            .screendims = &gfx.gContext.size,
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

    // install state
    var gsInstall = installState.GSInstall{
        .shader = &shader,
        .sb = &sb,
        .font_shader = &font_shader,
        .face = &biosFace,
        .load_sprite = .{
            .texture = &loadTex,
            .data = sprite.SpriteData.new(
                rect.newRect(1.0 / 5.0, 1.0 / 5.0, 1.0 / 5.0, 1.0 / 5.0),
                vecs.newVec2(20, 32),
            ),
        },
    };

    // recovery state
    var gsRecovery = recoveryState.GSRecovery{
        .shader = &shader,
        .sb = &sb,
        .font_shader = &font_shader,
        .face = &biosFace,
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
    gameStates.set(.Recovery, states.GameState.init(&gsRecovery));
    gameStates.set(.Installer, states.GameState.init(&gsInstall));

    // run setup
    try gameStates.getPtr(.Disks).setup();
    inputEvs.setup(ctx.window, true);

    //TODO: ???
    win.deskSize = &gfx.gContext.size;

    // update the frame timer
    var lastFrameTime = c.glfwGetTime();

    // networking :O
    // network.server = try network.Server.init();
    // _ = try std.Thread.spawn(.{}, network.Server.serve, .{});

    // main loop
    while (gfx.poll(&ctx)) {
        // get the current state
        var state = gameStates.getPtr(currentState);

        // get the time & update
        var currentTime = c.glfwGetTime();

        // pause the game on minimize
        if (c.glfwGetWindowAttrib(gfx.gContext.window, c.GLFW_ICONIFIED) == 0) {
            // update the game state
            try state.update(@floatCast(f32, currentTime - lastFrameTime));

            // get tris
            try state.draw(gfx.gContext.size);
        }

        // the state changed
        if (state != gameStates.getPtr(currentState)) {
            try state.deinit();

            try sb.clear();
        } else {
            // render this is in else to fix single frame bugs
            try blit();

            // update the time
            lastFrameTime = currentTime;
        }
    }

    // deinit the current state
    try gameStates.getPtr(currentState).deinit();

    // free the disk if allocated
    if (disk) |toFree| {
        allocator.alloc.free(toFree);
    }

    gfx.close(ctx);
    events.deinit();
    sb.deinit();
}

test "headless.zig" {
    _ = @import("system/headless.zig");
    _ = @import("system/vm.zig");
}
