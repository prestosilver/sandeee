// modules
const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

// states
const states = @import("states/manager.zig");
const diskState = @import("states/disks.zig");
const loadingState = @import("states/loading.zig");
const windowedState = @import("states/windowed.zig");
const crashState = @import("states/crash.zig");
const installState = @import("states/installer.zig");
const recoveryState = @import("states/recovery.zig");

// utilities
const fm = @import("util/files.zig");
const font = @import("util/font.zig");
const audio = @import("util/audio.zig");
const events = @import("util/events.zig");
const allocator = @import("util/allocator.zig");
const batch = @import("util/spritebatch.zig");
const gfx = @import("util/graphics.zig");
const shd = @import("util/shader.zig");
const tex = @import("util/texture.zig");
const texMan = @import("util/texmanager.zig");
const panicHandler = @import("util/panic.zig");

// events
const inputEvs = @import("events/input.zig");
const windowEvs = @import("events/window.zig");
const systemEvs = @import("events/system.zig");

// loader
const worker = @import("loaders/worker.zig");

// op math
const vecs = @import("math/vecs.zig");
const rect = @import("math/rects.zig");
const col = @import("math/colors.zig");

// drawers
const wall = @import("drawers/wall2d.zig");
const sprite = @import("drawers/sprite2d.zig");
const bar = @import("drawers/bar2d.zig");
const win = @import("drawers/window2d.zig");
const cursor = @import("drawers/cursor2d.zig");
const desk = @import("drawers/desk2d.zig");
const notifs = @import("drawers/notification2d.zig");

// misc system stuff
const conf = @import("system/config.zig");
const files = @import("system/files.zig");
const headless = @import("system/headless.zig");
const emails = @import("system/mail.zig");

// not-op programming lang
const c = @import("c.zig");

// embed shaders
const vertShader = @embedFile("shaders/vert.glsl");
const fragShader = @embedFile("shaders/frag.glsl");
const fontVertShader = @embedFile("shaders/fvert.glsl");
const fontFragShader = @embedFile("shaders/ffrag.glsl");

const crtFragShader = @embedFile("shaders/crtfrag.glsl");
const crtVertShader = @embedFile("shaders/crtvert.glsl");

const clearFragShader = @embedFile("shaders/clearfrag.glsl");
const clearVertShader = @embedFile("shaders/vert.glsl");

// embed images
const logoImage = @embedFile("images/logo.eia");
const loadImage = @embedFile("images/load.eia");
const biosImage = @embedFile("images/bios.eia");
const sadImage = @embedFile("images/sad.eia");
const errorImage = @embedFile("images/error.eia");

const blipSoundData = @embedFile("sounds/bios-blip.era");
const selectSoundData = @embedFile("sounds/bios-select.era");

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

const clear_shader_files = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = clearFragShader, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = clearVertShader, .kind = c.GL_VERTEX_SHADER },
};

var gameStates: std.EnumArray(systemEvs.State, states.GameState) = undefined;
var currentState: systemEvs.State = .Disks;

// create loader
var loader_queue: std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)) = undefined;
var loader = worker.WorkerContext{ .queue = &loader_queue };

// create some fonts
var biosFace: font.Font = undefined;
var mainFace: font.Font = undefined;

// shaders
var font_shader: shd.Shader = undefined;
var crt_shader: shd.Shader = undefined;
var clear_shader: shd.Shader = undefined;
var shader: shd.Shader = undefined;

// the selected disk
var disk: ?[]u8 = null;

var wallpaper: *wall.Wallpaper = undefined;

var message_snd: audio.Sound = undefined;

// managers
var settingManager: conf.SettingManager = undefined;
var textureManager: texMan.TextureManager = undefined;
var emailManager: emails.EmailManager = undefined;

var ctx: gfx.Context = undefined;
var sb: batch.SpriteBatch = undefined;
var audioman: audio.Audio = undefined;

var errorMsg: []const u8 = "Error: Unknown error";
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

var finalFps: u32 = 60;

pub fn blit() !void {
    // actual gl calls start here
    ctx.makeCurrent();

    if (@import("builtin").mode == .Debug and biosFace.setup) {
        var text = try std.fmt.allocPrint(allocator.alloc, "FPS: {}", .{finalFps});
        defer allocator.alloc.free(text);

        try biosFace.draw(.{
            .batch = &sb,
            .text = text,
            .shader = &font_shader,
            .pos = vecs.newVec2(0, 0),
            .color = col.newColor(1, 1, 1, 1),
        });
    }

    if (c.glfwGetWindowAttrib(gfx.gContext.window, c.GLFW_ICONIFIED) != 0) {
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
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

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

pub fn notification(_: windowEvs.EventNotification) bool {
    audioman.playSound(message_snd) catch {};
    return false;
}

pub fn settingSet(event: systemEvs.EventSetSetting) bool {
    if (std.mem.eql(u8, event.setting, "wallpaper_mode")) {
        wallpaper.data.mode = .Color;

        if (std.ascii.eqlIgnoreCase(event.value, "tile")) {
            wallpaper.data.mode = .Tile;
        }

        if (std.ascii.eqlIgnoreCase(event.value, "center")) {
            wallpaper.data.mode = .Center;
        }

        if (std.ascii.eqlIgnoreCase(event.value, "stretch")) {
            wallpaper.data.mode = .Stretch;
        }

        if (std.ascii.eqlIgnoreCase(event.value, "fill")) {
            wallpaper.data.mode = .Fill;
        }

        return true;
    }

    if (std.mem.eql(u8, event.setting, "sound_volume")) {
        audioman.volume = @intToFloat(f32, std.fmt.parseInt(i32, event.value, 0) catch 100) / 100.0;

        return true;
    }

    if (std.mem.eql(u8, event.setting, "sound_muted")) {
        audioman.muted = std.ascii.eqlIgnoreCase("yes", event.value);

        return true;
    }

    if (std.mem.eql(u8, event.setting, "crt_shader")) {
        var val: c_int = if (std.ascii.eqlIgnoreCase("yes", event.value)) 1 else 0;

        gfx.gContext.makeCurrent();
        crt_shader.setInt("crt_enable", val);
        crt_shader.setInt("dither_enable", val);
        gfx.gContext.makeNotCurrent();

        std.log.info("crt: {}", .{val});

        return true;
    }

    return false;
}

pub fn runCmdEvent(event: systemEvs.EventRunCmd) bool {
    for (emailManager.emails.items) |*email| {
        if (!emailManager.getEmailVisible(email)) continue;
        if (email.condition != .Run) continue;

        if (std.ascii.eqlIgnoreCase(email.conditionData, event.cmd)) {
            emailManager.setEmailComplete(email);
        }
    }

    return false;
}

pub fn setupEvents() !void {
    events.EventManager.init();

    try events.EventManager.instance.registerListener(inputEvs.EventWindowResize, windowResize);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseScroll, mouseScroll);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseMove, mouseMove);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseDown, mouseDown);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseUp, mouseUp);
    try events.EventManager.instance.registerListener(inputEvs.EventKeyDown, keyDown);
    try events.EventManager.instance.registerListener(inputEvs.EventKeyChar, keyChar);
    try events.EventManager.instance.registerListener(inputEvs.EventKeyUp, keyUp);

    try events.EventManager.instance.registerListener(systemEvs.EventSetSetting, settingSet);
    try events.EventManager.instance.registerListener(systemEvs.EventStateChange, changeState);
    try events.EventManager.instance.registerListener(windowEvs.EventNotification, notification);
    try events.EventManager.instance.registerListener(systemEvs.EventRunCmd, runCmdEvent);
}

pub fn drawLoading(self: *loadingState.GSLoading) void {
    while (!self.done.load(.SeqCst)) {
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

var paniced: bool = false;

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    if (paniced) {
        std.log.info("second panic", .{});
        std.os.exit(0);
    }
    paniced = true;

    sb.scissor = null;

    errorState = @enumToInt(currentState);
    gameStates.getPtr(@intToEnum(systemEvs.State, errorState)).deinit() catch {};

    var st = panicHandler.log();
    errorMsg = std.fmt.allocPrint(allocator.alloc, "{s}\n{s}", .{ msg, st }) catch {
        std.os.exit(0);
    };

    std.fs.cwd().writeFile("CrashLog.txt", errorMsg) catch {};

    // no display on headless
    if (isHeadless) {
        std.os.exit(0);
    }

    // disable events on loading screen
    inputEvs.setup(ctx.window, true);

    // update game state
    currentState = .Crash;

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
    std.log.info("Sandeee " ++ options.VersionText, .{options.SandEEEVersion});

    defer if (!builtin.link_libc or !allocator.useclib) {
        std.debug.assert(allocator.gpa.deinit() == .ok);
        std.log.debug("no leaks! :)", .{});
    };

    // setup the headless command
    var headlessCmd: ?[]const u8 = null;

    // check arguments
    var args = try std.process.ArgIterator.initWithAllocator(allocator.alloc);

    // ignore first arg
    _ = args.next();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--cwd")) {
            var path = args.next().?;
            std.log.debug("chdir: {s}", .{path});

            try std.process.changeCurDir(path);
        } else if (std.mem.eql(u8, arg, "--headless")) {
            isHeadless = true;
        } else if (std.mem.eql(u8, arg, "--headless-cmd")) {
            var script = args.next().?;
            var buff = try allocator.alloc.alloc(u8, 1024);
            var file = try std.fs.cwd().openFile(script, .{});

            var len = try file.readAll(buff);
            headlessCmd = buff[0..len];
            file.close();

            isHeadless = true;
        }
    }

    // free the argument iterator
    args.deinit();

    // switch to headless main function if nessessary
    if (isHeadless) {
        return headless.headlessMain(headlessCmd, false, null);
    }

    // setup the texture manager
    textureManager = texMan.TextureManager.init();
    batch.textureManager = &textureManager;
    audioman = try audio.Audio.init();

    // init graphics
    ctx = try gfx.init("SandEEE");
    gfx.gContext = &ctx;

    // setup fonts deinit
    biosFace.setup = false;
    mainFace.setup = false;

    var blipSound: audio.Sound = audio.Sound.init(blipSoundData);
    var selectSound: audio.Sound = audio.Sound.init(selectSoundData);

    // create the loaders queue
    loader_queue = std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)).init();

    // shaders
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &shader_files, &shader, worker.shader.loadShader);
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &font_shader_files, &font_shader, worker.shader.loadShader);
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &crt_shader_files, &crt_shader, worker.shader.loadShader);
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &clear_shader_files, &clear_shader, worker.shader.loadShader);

    // fonts
    const biosFont: []const u8 = @embedFile("images/main.eff");
    try loader.enqueue(*const []const u8, *font.Font, &biosFont, &biosFace, worker.font.loadFont);

    // load bios
    var prog: f32 = 0;
    loader.run(&prog) catch {
        @panic("Preload Failed");
    };

    // start setup states
    ctx.makeCurrent();

    // enable crt by default
    crt_shader.setInt("crt_enable", 1);
    crt_shader.setInt("dither_enable", 1);

    // setup render texture for shaders
    c.glGenFramebuffers(1, &framebufferName);
    c.glGenBuffers(1, &quad_VertexArrayID);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_VertexArrayID);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c.GLsizeiptr, full_quad.len * @sizeOf(f32)), &full_quad, c.GL_DYNAMIC_DRAW);
    c.glGenTextures(1, &renderedTexture);
    c.glGenRenderbuffers(1, &depthrenderbuffer);

    // create the sprite batch
    sb = try batch.SpriteBatch.init(&gfx.gContext.size);

    // load some textures
    try textureManager.putMem("bios", biosImage);
    try textureManager.putMem("logo", logoImage);
    try textureManager.putMem("load", loadImage);
    try textureManager.putMem("sad", sadImage);
    try textureManager.putMem("error", errorImage);

    // disks state
    var gsDisks = diskState.GSDisks{
        .sb = &sb,
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &biosFace,
        .disk = &disk,
        .blipSound = &blipSound,
        .selectSound = &selectSound,
        .audioMan = &audioman,
        .logo_sprite = .{
            .texture = "bios",
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(168, 84),
            ),
        },
    };

    // loading state
    var gsLoading = loadingState.GSLoading{
        .sb = &sb,
        .face = &mainFace,
        .audio_man = &audioman,
        .textureManager = &textureManager,
        .emailManager = &emailManager,
        .ctx = &ctx,
        .loading = drawLoading,
        .message_snd = &message_snd,
        .logo_sprite = .{
            .texture = "logo",
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(320, 64),
            ),
        },
        .load_sprite = .{
            .texture = "load",
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
        .clearShader = &clear_shader,
        .face = &mainFace,
        .settingsManager = &settingManager,
        .emailManager = &emailManager,
        .bar_logo_sprite = .{
            .texture = "barlogo",
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(36, 464),
            ),
        },
        .desk = .{
            .texture = "explorer",
            .data = .{
                .shell = .{
                    .root = undefined,
                },
            },
        },
        .cursor = .{
            .texture = "cursor",
            .data = cursor.CursorData.new(
                rect.newRect(0, 0, 1, 1),
                6,
            ),
        },
        .wallpaper = wall.Wallpaper.new("wall", wall.WallData{
            .dims = &gfx.gContext.size,
            .mode = .Center,
        }),
        .bar = bar.Bar.new("bar", bar.BarData{
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
            .texture = "sad",
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
        .selectSound = &selectSound,
        .audioMan = &audioman,
        .load_sprite = .{
            .texture = "load",
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
        .blipSound = &blipSound,
        .selectSound = &selectSound,
        .audioMan = &audioman,
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

    // set some random vars
    win.deskSize = &gfx.gContext.size;
    desk.deskSize = &gfx.gContext.size;
    windowedState.GSWindowed.deskSize = &gfx.gContext.size;
    wallpaper = &gsWindowed.wallpaper;
    bar.settingsManager = &settingManager;

    // update the frame timer
    var lastFrameTime = c.glfwGetTime();

    // setup state machine
    var prev = currentState;

    // fps tracker stats
    var fps: usize = 0;
    var timer: f64 = 0;

    // main loop
    while (gfx.poll(&ctx)) {

        // get the current state
        var state = gameStates.getPtr(prev);

        // get the time & update
        var currentTime = c.glfwGetTime();

        // pause the game on minimize
        if (c.glfwGetWindowAttrib(gfx.gContext.window, c.GLFW_ICONIFIED) == 0) {
            // update the game state
            try state.update(1.0 / 60.0);

            // get tris
            try state.draw(gfx.gContext.size);
        }

        timer += currentTime - lastFrameTime;
        if (timer > 1) {
            finalFps = @floatToInt(u32, @intToFloat(f64, fps) / timer);
            fps = 0;
            timer = 0;
        }

        // the state changed
        if (currentState != prev) {
            prev = currentState;

            try state.deinit();

            // run setup
            try gameStates.getPtr(currentState).setup();

            // disable events on loading screen
            inputEvs.setup(ctx.window, currentState != .Loading);

            sb.queueLock.lock();
            try sb.clear();
            sb.queueLock.unlock();
        } else {
            // render this is in else to fix single frame bugs
            try blit();
            fps += 1;
        }

        // upda:Telescope projects<cr>te the time
        lastFrameTime = currentTime;
    }

    // deinit the current state
    try gameStates.getPtr(currentState).deinit();

    try biosFace.deinit();
    try batch.textureManager.deinit();

    gfx.close(ctx);
    events.EventManager.deinit();
    sb.deinit();
}

test "headless.zig" {
    _ = @import("system/headless.zig");
    _ = @import("system/vm.zig");
}
