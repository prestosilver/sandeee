// modules
const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");
const steam = @import("steam");

// states
const states = @import("states/manager.zig");
const diskState = @import("states/disks.zig");
const loadingState = @import("states/loading.zig");
const windowedState = @import("states/windowed.zig");
const crashState = @import("states/crash.zig");
const installState = @import("states/installer.zig");
const recoveryState = @import("states/recovery.zig");
const logoutState = @import("states/logout.zig");

// utilitieS
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
const shell = @import("system/shell.zig");
const vmManager = @import("system/vmmanager.zig");

// not-op programming lang
const c = @import("c.zig");

pub const useSteam = options.IsSteam;

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

const full_quad = [_]c.GLfloat{
    -0.5, -0.5, 0.0,
    0.5,  -0.5, 0.0,
    -0.5, 0.5,  0.0,
    -0.5, 0.5,  0.0,
    0.5,  -0.5, 0.0,
    0.5,  0.5,  0.0,
};

// fps tracking
var last_frame_time: f64 = 0;

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

// wallpaper stuff
var wallpaper: wall.Wallpaper = undefined;

// managers
var emailManager: emails.EmailManager = undefined;

// sounds
var audio_man: audio.Audio = undefined;
var message_snd: audio.Sound = undefined;
var logout_snd: audio.Sound = undefined;

// for panic
var errorMsg: []const u8 = "Error: Unknown error";
var errorState: u8 = 0;
var panicLock = std.Thread.Mutex{};
var paniced = false;

// for shader rect
var framebufferName: c.GLuint = 0;
var quad_VertexArrayID: c.GLuint = 0;
var renderedTexture: c.GLuint = 0;
var depthrenderbuffer: c.GLuint = 0;

// fps tracking
var finalFps: u32 = 60;
var showFps: bool = false;

// steam
var steamUserStats: *const steam.SteamUserStats = undefined;
var steamUtils: *const steam.SteamUtils = undefined;

var crt_enable = true;

pub fn blit() !void {
    // actual gl calls start here
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    if (c.glfwGetWindowAttrib(gfx.Context.instance.window, c.GLFW_ICONIFIED) != 0) {
        // for when minimized render nothing
        gfx.Context.clear();

        gfx.Context.swap();

        return;
    }

    if (showFps and biosFace.setup) {
        const text = try std.fmt.allocPrint(allocator.alloc, "{s}FPS: {}\n{s}VMS: {}\n\xf9VMT: {}%\nSTA: {}", .{
            if (finalFps < 50) "\xFA" else "\xF9",
            finalFps,
            if (vmManager.VMManager.instance.vms.count() == 0) "\xF1" else "\xF9",
            vmManager.VMManager.instance.vms.count(),
            @as(u8, @intFromFloat(vmManager.VMManager.vm_time * 100)),
            @intFromEnum(currentState),
        });
        defer allocator.alloc.free(text);

        try biosFace.draw(.{
            .text = text,
            .shader = &font_shader,
            .pos = vecs.newVec2(0, 0),
            .color = col.newColor(1, 1, 1, 1),
        });
    }

    if (false) {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebufferName);

        c.glBindRenderbuffer(c.GL_RENDERBUFFER, depthrenderbuffer);
        c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)));
        c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depthrenderbuffer);

        c.glFramebufferTexture(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, renderedTexture, 0);

        c.glDrawBuffers(1, &[_]c.GLenum{c.GL_COLOR_ATTACHMENT0});

        if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE)
            return error.FramebufferSetupFail;

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebufferName);

        gfx.Context.clear();

        // finish render
        try batch.SpriteBatch.instance.render();

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_VertexArrayID);
        c.glBindTexture(c.GL_TEXTURE_2D, renderedTexture);

        c.glUseProgram(crt_shader.id);
        crt_shader.setFloat("time", @as(f32, @floatCast(c.glfwGetTime())));

        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 3 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        // swap buffer
        gfx.Context.swap();

        // rerender the last frame
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_VertexArrayID);
        c.glBindTexture(c.GL_TEXTURE_2D, renderedTexture);

        c.glUseProgram(crt_shader.id);

        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 3 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    } else {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebufferName);

        c.glBindRenderbuffer(c.GL_RENDERBUFFER, depthrenderbuffer);
        c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)));
        c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depthrenderbuffer);

        c.glFramebufferTexture(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, renderedTexture, 0);

        c.glDrawBuffers(1, &[_]c.GLenum{c.GL_COLOR_ATTACHMENT0});

        if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE)
            return error.FramebufferSetupFail;

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebufferName);

        gfx.Context.clear();

        // finish render
        try batch.SpriteBatch.instance.render();

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_VertexArrayID);
        c.glBindTexture(c.GL_TEXTURE_2D, renderedTexture);

        c.glUseProgram(crt_shader.id);
        crt_shader.setFloat("time", @as(f32, @floatCast(c.glfwGetTime())));

        c.glDisable(c.GL_BLEND);

        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 3 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glEnable(c.GL_BLEND);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        // swap buffer
        gfx.Context.swap();
    }
    c.glFinish();
}

pub fn changeState(event: systemEvs.EventStateChange) !void {
    std.log.debug("ChangeState: {s}", .{@tagName(event.targetState)});
    currentState = event.targetState;
}

pub fn keyDown(event: inputEvs.EventKeyDown) !void {
    if (event.key == c.GLFW_KEY_F12) {
        showFps = !showFps;
    }

    if (event.key == c.GLFW_KEY_V and event.mods == (c.GLFW_MOD_CONTROL)) {
        try events.EventManager.instance.sendEvent(systemEvs.EventPaste{});

        return;
    }

    try gameStates.getPtr(currentState).keypress(event.key, event.mods, true);
}

pub fn keyUp(event: inputEvs.EventKeyUp) !void {
    try gameStates.getPtr(currentState).keypress(event.key, event.mods, false);
}

pub fn keyChar(event: inputEvs.EventKeyChar) !void {
    try gameStates.getPtr(currentState).keychar(event.codepoint, event.mods);
}

pub fn mouseDown(event: inputEvs.EventMouseDown) !void {
    try gameStates.getPtr(currentState).mousepress(event.btn);
}

pub fn mouseUp(_: inputEvs.EventMouseUp) !void {
    try gameStates.getPtr(currentState).mouserelease();
}

pub fn mouseMove(event: inputEvs.EventMouseMove) !void {
    try gameStates.getPtr(currentState).mousemove(vecs.newVec2(@as(f32, @floatCast(event.x)), @as(f32, @floatCast(event.y))));
}

pub fn mouseScroll(event: inputEvs.EventMouseScroll) !void {
    try gameStates.getPtr(currentState).mousescroll(vecs.newVec2(@as(f32, @floatCast(event.x)), @as(f32, @floatCast(event.y))));
}

pub fn notification(_: windowEvs.EventNotification) !void {
    try audio_man.playSound(message_snd);
}

pub fn copy(event: systemEvs.EventCopy) !void {
    const toCopy = try allocator.alloc.dupeZ(u8, event.value);
    defer allocator.alloc.free(toCopy);

    c.glfwSetClipboardString(gfx.Context.instance.window, toCopy);
}

pub fn paste(_: systemEvs.EventPaste) !void {
    const tmp = c.glfwGetClipboardString(gfx.Context.instance.window);
    if (tmp == null) return;

    const len = std.mem.len(tmp);
    for (tmp[0..len]) |ch| {
        if (ch == '\n') {
            try gameStates.getPtr(currentState).keypress(c.GLFW_KEY_ENTER, 0, true);
            try gameStates.getPtr(currentState).keypress(c.GLFW_KEY_ENTER, 0, false);
        } else try gameStates.getPtr(currentState).keychar(ch, 0);
    }
}

pub fn settingSet(event: systemEvs.EventSetSetting) !void {
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

        return;
    }

    if (std.mem.eql(u8, event.setting, "sound_volume")) {
        audio_man.volume = @as(f32, @floatFromInt(std.fmt.parseInt(i32, event.value, 0) catch 100)) / 100.0;

        return;
    }

    if (std.mem.eql(u8, event.setting, "sound_muted")) {
        audio_man.muted = std.ascii.eqlIgnoreCase("yes", event.value);

        return;
    }

    if (std.mem.eql(u8, event.setting, "crt_shader")) {
        const val: c_int = if (std.ascii.eqlIgnoreCase("yes", event.value)) 1 else 0;

        if (isCrt) {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            crt_shader.setInt("crt_enable", val);
            crt_shader.setInt("dither_enable", val);

            crt_enable = val == 1;
        }

        return;
    }
}

pub fn runCmdEvent(event: systemEvs.EventRunCmd) !void {
    for (emailManager.emails.items) |*email| {
        if (!emailManager.getEmailVisible(email)) continue;
        if (email.condition != .Run) continue;

        if (std.ascii.eqlIgnoreCase(email.conditionData, event.cmd)) {
            try emailManager.setEmailComplete(email);
        }
    }
}

pub fn syscall(event: systemEvs.EventSys) !void {
    for (emailManager.emails.items) |*email| {
        if (!emailManager.getEmailVisible(email)) continue;
        if (email.condition != .SysCall) continue;

        const num = std.fmt.parseInt(u64, email.conditionData, 0) catch 0;

        if (num == event.sysId) {
            try emailManager.setEmailComplete(email);
        }
    }
}

pub fn drawLoading(self: *loadingState.GSLoading) void {
    while (!self.done.load(.SeqCst) and !paniced) {
        {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            if (!gfx.Context.poll())
                self.done.storeUnchecked(true);
        }

        // render loading screen
        self.draw(gfx.Context.instance.size) catch {};

        blit() catch {};
        std.Thread.yield() catch {};
    }
}

pub fn windowResize(event: inputEvs.EventWindowResize) !void {
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    try gfx.Context.resize(event.w, event.h);

    c.glfwSetTime(0);
    last_frame_time = 0;

    // clear the window
    c.glBindTexture(c.GL_TEXTURE_2D, renderedTexture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    // Poor filtering. Needed !
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    paniced = true;

    if (paniced) std.os.exit(0);

    panicLock.lock();

    batch.SpriteBatch.instance.scissor = null;

    errorState = @intFromEnum(currentState);
    gameStates.getPtr(@as(systemEvs.State, @enumFromInt(errorState))).deinit() catch {};

    const st = panicHandler.log();
    errorMsg = std.fmt.allocPrint(allocator.alloc, "{s}\n{s}", .{ msg, st }) catch {
        std.os.exit(0);
    };

    std.fs.cwd().writeFile("CrashLog.txt", errorMsg) catch {};

    // no display on headless
    if (isHeadless) {
        std.os.exit(0);
    }

    // disable events on loading screen
    inputEvs.setup(gfx.Context.instance.window, true);

    // update game state
    currentState = .Crash;

    // run setup
    gameStates.getPtr(.Crash).setup() catch {};

    // get crash state
    const state = gameStates.getPtr(.Crash);

    while (gfx.Context.poll()) {
        state.update(1.0 / 60.0) catch break;
        state.draw(gfx.Context.instance.size) catch break;
        blit() catch break;
    }

    std.os.exit(0);
}

var isHeadless = false;
var isCrt = true;

pub fn main() void {
    defer if (!builtin.link_libc or !allocator.useclib) {
        if (allocator.gpa.deinit() == .ok)
            std.log.debug("no leaks! :)", .{});
    };

    mainErr() catch |err| {
        panic(@errorName(err), @errorReturnTrace(), null);
    };
}

pub fn mainErr() anyerror!void {
    std.log.info("Sandeee " ++ options.VersionText, .{options.SandEEEVersion});

    if (steam.restartIfNeeded(steam.STEAM_APP_ID)) {
        std.log.info("Restarting for steam", .{});
        return; // steam will relaunch the game from the steam client.
    }

    if (steam.init()) {
        var user = steam.getUser();
        const steamId = user.getSteamId();
        steamUtils = steam.getSteamUtils();
        steamUserStats = steam.getUserStats();
        _ = steamId;
        _ = steamUtils;
    }

    // setup the headless command
    var headlessCmd: ?[]const u8 = null;

    // check arguments
    var args = try std.process.ArgIterator.initWithAllocator(allocator.alloc);

    // ignore first arg
    _ = args.next();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--cwd")) {
            const path = args.next().?;
            std.log.debug("chdir: {s}", .{path});

            try std.process.changeCurDir(path);
        } else if (std.mem.eql(u8, arg, "--no-crt")) {
            isCrt = false;
        } else if (std.mem.eql(u8, arg, "--headless")) {
            isHeadless = true;
        } else if (std.mem.eql(u8, arg, "--headless-cmd")) {
            const script = args.next().?;
            const buff = try allocator.alloc.alloc(u8, 1024);
            const file = try std.fs.cwd().openFile(script, .{});

            const len = try file.readAll(buff);
            headlessCmd = buff[0..len];
            file.close();

            isHeadless = true;
        }
    }

    // free the argument iterator
    args.deinit();

    // setup vm manager
    vmManager.VMManager.init();

    // switch to headless main function if nessessary
    if (isHeadless) {
        return headless.headlessMain(headlessCmd, false, null);
    }

    // setup the texture manager
    texMan.TextureManager.init();

    // init graphics
    try gfx.Context.init("SandEEE");

    audio_man = try audio.Audio.init();

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
    try loader.run(&prog);

    // start setup states
    gfx.Context.makeCurrent();

    // enable crt by default
    crt_shader.setInt("crt_enable", if (isCrt) 1 else 0);
    crt_shader.setInt("dither_enable", if (isCrt) 1 else 0);

    // setup render texture for shaders
    c.glGenFramebuffers(1, &framebufferName);
    c.glGenBuffers(1, &quad_VertexArrayID);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_VertexArrayID);
    c.glBufferData(c.GL_ARRAY_BUFFER, @as(c.GLsizeiptr, @intCast(full_quad.len * @sizeOf(f32))), &full_quad, c.GL_DYNAMIC_DRAW);
    c.glGenTextures(1, &renderedTexture);
    c.glGenRenderbuffers(1, &depthrenderbuffer);

    // clear the window
    c.glBindTexture(c.GL_TEXTURE_2D, renderedTexture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    // Poor filtering. Needed !
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    // create the sprite batch
    try batch.SpriteBatch.init(&gfx.Context.instance.size);
    defer batch.SpriteBatch.deinit();

    // load some textures
    try texMan.TextureManager.instance.putMem("bios", biosImage);
    try texMan.TextureManager.instance.putMem("logo", logoImage);
    try texMan.TextureManager.instance.putMem("load", loadImage);
    try texMan.TextureManager.instance.putMem("sad", sadImage);
    try texMan.TextureManager.instance.putMem("error", errorImage);

    wallpaper = wall.Wallpaper.new("wall", wall.WallData{
        .dims = &gfx.Context.instance.size,
        .mode = .Center,
    });

    // disks state
    var gsDisks = diskState.GSDisks{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &biosFace,
        .disk = &disk,
        .blipSound = &blipSound,
        .selectSound = &selectSound,
        .audioMan = &audio_man,
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
        .face = &mainFace,
        .audio_man = &audio_man,
        .emailManager = &emailManager,
        .loading = drawLoading,
        .logout_snd = &logout_snd,
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
                vecs.newVec2(0, 15),
            ),
        },
        .shader = &shader,
        .disk = &disk,
        .loader = &loader,
    };

    // windowed state
    var gsWindowed = windowedState.GSWindowed{
        .shader = &shader,
        .font_shader = &font_shader,
        .clearShader = &clear_shader,
        .face = &mainFace,
        .emailManager = &emailManager,
        .bar_logo_sprite = .{
            .texture = "barlogo",
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(36, 464),
            ),
        },
        .desk = .{
            .texture = "big_icons",
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
        .wallpaper = &wallpaper,
        .bar = bar.Bar.new("bar", bar.BarData{
            .height = 38,
            .screendims = &gfx.Context.instance.size,
        }),
    };

    // crashed state
    var gsCrash = crashState.GSCrash{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &biosFace,
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
        .font_shader = &font_shader,
        .face = &biosFace,
        .selectSound = &selectSound,
        .audioMan = &audio_man,
        .load_sprite = .{
            .texture = "load",
            .data = sprite.SpriteData.new(
                rect.newRect(1.0 / 5.0, 1.0 / 5.0, 1.0 / 5.0, 1.0 / 5.0),
                vecs.newVec2(20, 32),
            ),
        },
    };

    // logout state
    var gsLogout = logoutState.GSLogout{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &biosFace,
        .logout_sound = &logout_snd,
        .audio_man = &audio_man,
        .wallpaper = &wallpaper,
        .clearShader = &clear_shader,
    };

    // recovery state
    var gsRecovery = recoveryState.GSRecovery{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &biosFace,
        .blipSound = &blipSound,
        .selectSound = &selectSound,
        .audioMan = &audio_man,
    };

    // done states setup
    gfx.Context.makeNotCurrent();

    // setup event system
    events.EventManager.init();
    defer events.EventManager.deinit();

    // add input management event handlers
    try events.EventManager.instance.registerListener(inputEvs.EventWindowResize, windowResize);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseScroll, mouseScroll);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseMove, mouseMove);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseDown, mouseDown);
    try events.EventManager.instance.registerListener(inputEvs.EventMouseUp, mouseUp);
    try events.EventManager.instance.registerListener(inputEvs.EventKeyDown, keyDown);
    try events.EventManager.instance.registerListener(inputEvs.EventKeyChar, keyChar);
    try events.EventManager.instance.registerListener(inputEvs.EventKeyUp, keyUp);

    // add system event handlers
    try events.EventManager.instance.registerListener(systemEvs.EventSetSetting, settingSet);
    try events.EventManager.instance.registerListener(systemEvs.EventStateChange, changeState);
    try events.EventManager.instance.registerListener(windowEvs.EventNotification, notification);
    try events.EventManager.instance.registerListener(systemEvs.EventRunCmd, runCmdEvent);
    try events.EventManager.instance.registerListener(systemEvs.EventPaste, paste);
    try events.EventManager.instance.registerListener(systemEvs.EventCopy, copy);
    try events.EventManager.instance.registerListener(systemEvs.EventSys, syscall);

    // setup game states
    gameStates.set(.Disks, states.GameState.init(&gsDisks));
    gameStates.set(.Loading, states.GameState.init(&gsLoading));
    gameStates.set(.Windowed, states.GameState.init(&gsWindowed));
    gameStates.set(.Crash, states.GameState.init(&gsCrash));
    gameStates.set(.Logout, states.GameState.init(&gsLogout));
    gameStates.set(.Recovery, states.GameState.init(&gsRecovery));
    gameStates.set(.Installer, states.GameState.init(&gsInstall));

    // run setup
    try gameStates.getPtr(.Disks).setup();
    inputEvs.setup(gfx.Context.instance.window, true);

    // setup state machine
    var prev = currentState;

    // fps tracker stats
    var fps: usize = 0;
    var timer: f64 = 0;

    c.glfwSetTime(0);
    last_frame_time = 0;

    // main loop
    while (gfx.Context.poll()) {

        // get the current state
        const state = gameStates.getPtr(prev);

        // get the time & update
        const currentTime = c.glfwGetTime();

        // pause the game on minimize
        if (c.glfwGetWindowAttrib(gfx.Context.instance.window, c.GLFW_ICONIFIED) == 0) {
            const cb = struct {
                fn callback(callbackMsg: steam.CallbackMsg) anyerror!void {
                    std.log.warn("steam callback {}", .{callbackMsg.callback});
                }
            }.callback;

            // update the game state
            try state.update(@max(1 / 60, @as(f32, @floatCast(currentTime - last_frame_time))));
            try steam.manualCallback(cb);

            // get tris
            try state.draw(gfx.Context.instance.size);
        }

        timer += currentTime - last_frame_time;
        if (timer > 1.00) {
            finalFps = @as(u32, @intFromFloat(@as(f64, @floatFromInt(fps)) / timer));
            if (vmManager.VMManager.instance.vms.count() != 0 and finalFps != 0) {
                const adj: f64 = std.math.clamp((@as(f64, @floatFromInt(fps)) / timer) / 58.0, 0.95, 1.05);
                vmManager.VMManager.vm_time = std.math.clamp(vmManager.VMManager.vm_time * adj, 0.1, 0.9);
            }

            fps = 0;
            timer = 0;
        }

        // the state changed
        if (currentState != prev) {
            prev = currentState;

            try state.deinit();

            // run setup
            try gameStates.getPtr(currentState).setup();

            try batch.SpriteBatch.instance.clear();
        } else {
            // render this is in else to fix single frame bugs
            try blit();
            fps += 1;
        }

        // update the time
        last_frame_time = currentTime;
    }

    // deinit the current state
    try gameStates.getPtr(currentState).deinit();

    try biosFace.deinit();
    texMan.TextureManager.deinit();

    gfx.Context.deinit();
}

test "headless.zig" {
    _ = @import("system/headless.zig");
    _ = @import("system/vm.zig");
}
