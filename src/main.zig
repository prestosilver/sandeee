// modules
const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");
const steam = @import("steam");

// states
const states = @import("states/manager.zig");
const disk_state = @import("states/disks.zig");
const loading_state = @import("states/loading.zig");
const windowed_state = @import("states/windowed.zig");
const crash_state = @import("states/crash.zig");
const install_state = @import("states/installer.zig");
const recovery_state = @import("states/recovery.zig");
const logout_state = @import("states/logout.zig");

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
const texture_manager = @import("util/texmanager.zig");
const panic_handler = @import("util/panic.zig");
const log = @import("util/log.zig");

// events
const input_events = @import("events/input.zig");
const window_events = @import("events/window.zig");
const system_events = @import("events/system.zig");

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
const vm_manager = @import("system/vmmanager.zig");

// not-op programming lang
const c = @import("c.zig");

pub const std_options = std.Options{
    // Define logFn to override the std implementation
    .logFn = log.sandEEELogFn,
    .log_level = .debug,
};

pub const steam_options = struct {
    pub const fake_steam = options.fakeSteam;
    pub const use_steam = options.IsSteam;
    pub const app_id = 480;
};

// embed shaders
const VERT_SHADER = @embedFile("shaders/vert.glsl");
const FRAG_SHADER = @embedFile("shaders/frag.glsl");

const FONT_VERT_SHADER = @embedFile("shaders/vert.glsl");
const FONT_FRAG_SHADER = @embedFile("shaders/ffrag.glsl");

const CRT_FRAG_SHADER = @embedFile("shaders/crtfrag.glsl");
const CRT_VERT_SHADER = @embedFile("shaders/crtvert.glsl");

const CLEAR_FRAG_SHADER = @embedFile("shaders/clearfrag.glsl");
const CLEAR_VERT_SHADER = @embedFile("shaders/vert.glsl");

// embed images
const LOGO_IMAGE = @embedFile("images/logo.eia");
const LOAD_IMAGE = @embedFile("images/load.eia");
const BIOS_IMAGE = @embedFile("images/bios.eia");
const SAD_IMAGE = @embedFile("images/sad.eia");
const ERROR_IMAGE = @embedFile("images/error.eia");
const WHITE_IMAGE = [_]u8{ 'e', 'i', 'm', 'g', 1, 0, 1, 0, 255, 255, 255, 255 };

const BIOS_FONT_DATA: []const u8 = @embedFile("images/main.eff");

const BLIP_SOUND_DATA = @embedFile("sounds/bios-blip.era");
const SELECT_SOUND_DATA = @embedFile("sounds/bios-select.era");

const SHADER_FILES = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
};

const FONT_SHADER_FILES = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = FONT_FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = FONT_VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
};

const CRT_SHADER_FILES = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = CRT_FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = CRT_VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
};

const CLEAR_SHADER_FILES = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = CLEAR_FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = CLEAR_VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
};

const FULL_QUAD = [_]c.GLfloat{
    -0.5, -0.5, 0.0,
    0.5,  -0.5, 0.0,
    -0.5, 0.5,  0.0,
    -0.5, 0.5,  0.0,
    0.5,  -0.5, 0.0,
    0.5,  0.5,  0.0,
};

var state_refresh_rate: f64 = 0.5;

// misc state data
var game_states: std.EnumArray(system_events.State, states.GameState) = undefined;
var current_state: system_events.State = .Disks;

// create loader
var loader_queue: std.DoublyLinkedList(worker.WorkerQueueEntry(*void, *void)) = undefined;
var loader = worker.WorkerContext{ .queue = &loader_queue };

// create some fonts
var bios_font: font.Font = undefined;
var main_font: font.Font = undefined;

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
var email_manager: emails.EmailManager = undefined;

// sounds
var audio_manager: audio.Audio = undefined;
var message_snd: audio.Sound = undefined;
var logout_snd: audio.Sound = undefined;

// for panic
var error_message: []const u8 = "Error: Unknown Error";
var error_state: u8 = 0;
var paniced = false;

// for shader rect
var framebuffer_name: c.GLuint = 0;
var quad_vertex_array_id: c.GLuint = 0;
var rendered_texture: c.GLuint = 0;
var depth_render_buffer: c.GLuint = 0;

// fps tracking
var final_fps: u32 = 60;
var show_fps: bool = false;

// steam
var steam_user_stats: *const steam.SteamUserStats = undefined;
var steam_utils: *const steam.SteamUtils = undefined;

var crt_enable = true;

pub fn blit() !void {
    const start_time = c.glfwGetTime();

    // actual gl calls start here
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    if (c.glfwGetWindowAttrib(gfx.Context.instance.window, c.GLFW_ICONIFIED) != 0) {
        // for when minimized render nothing
        gfx.Context.clear();

        gfx.Context.swap();

        return;
    }

    if (show_fps and bios_font.setup) {
        const text = try std.fmt.allocPrint(allocator.alloc, "{s}FPS: {}\n{s}VMS: {}\n{s}VMT: {}%\nSTA: {}", .{
            if (final_fps < 50)
                font.COLOR_RED
            else
                font.COLOR_WHITE,
            final_fps,
            if (vm_manager.VMManager.instance.vms.count() == 0)
                font.COLOR_GRAY
            else
                font.COLOR_WHITE,
            vm_manager.VMManager.instance.vms.count(),
            font.COLOR_WHITE,
            @as(u8, @intFromFloat(vm_manager.VMManager.vm_time * 100)),
            @intFromEnum(current_state),
        });
        defer allocator.alloc.free(text);

        try bios_font.draw(.{
            .text = text,
            .shader = &font_shader,
            .pos = .{},
            .color = .{ .r = 1, .g = 1, .b = 1 },
        });
    }

    if (crt_enable) {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebuffer_name);
    }

    gfx.Context.clear();

    // finish render
    try batch.SpriteBatch.instance.render();

    if (crt_enable) {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_vertex_array_id);
        c.glBindTexture(c.GL_TEXTURE_2D, rendered_texture);

        c.glUseProgram(crt_shader.id);
        crt_shader.setFloat("time", @as(f32, @floatCast(c.glfwGetTime())));

        c.glDisable(c.GL_BLEND);

        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 3 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glEnable(c.GL_BLEND);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    }

    vm_manager.VMManager.last_render_time = c.glfwGetTime() - start_time;

    // swap buffer
    gfx.Context.swap();
}

pub fn changeState(event: system_events.EventStateChange) !void {
    current_state = event.target_state;
}

pub fn keyDown(event: input_events.EventKeyDown) !void {
    if (event.key == c.GLFW_KEY_F12) {
        show_fps = !show_fps;
    }

    if (event.key == c.GLFW_KEY_V and event.mods == (c.GLFW_MOD_CONTROL)) {
        try events.EventManager.instance.sendEvent(system_events.EventPaste{});

        return;
    }

    try game_states.getPtr(current_state).keypress(event.key, event.mods, true);
}

pub fn keyUp(event: input_events.EventKeyUp) !void {
    try game_states.getPtr(current_state).keypress(event.key, event.mods, false);
}

pub fn keyChar(event: input_events.EventKeyChar) !void {
    try game_states.getPtr(current_state).keychar(event.codepoint, event.mods);
}

pub fn mouseDown(event: input_events.EventMouseDown) !void {
    try game_states.getPtr(current_state).mousepress(event.btn);
}

pub fn mouseUp(_: input_events.EventMouseUp) !void {
    try game_states.getPtr(current_state).mouserelease();
}

pub fn mouseMove(event: input_events.EventMouseMove) !void {
    try game_states.getPtr(current_state).mousemove(.{ .x = @floatCast(event.x), .y = @floatCast(event.y) });
}

pub fn mouseScroll(event: input_events.EventMouseScroll) !void {
    try game_states.getPtr(current_state).mousescroll(.{ .x = @floatCast(event.x), .y = @floatCast(event.y) });
}

pub fn notification(_: window_events.EventNotification) !void {
    try audio_manager.playSound(message_snd);
}

pub fn copy(event: system_events.EventCopy) !void {
    const to_copy = try allocator.alloc.dupeZ(u8, event.value);
    defer allocator.alloc.free(to_copy);

    c.glfwSetClipboardString(gfx.Context.instance.window, to_copy);
}

pub fn paste(_: system_events.EventPaste) !void {
    const tmp = c.glfwGetClipboardString(gfx.Context.instance.window);
    if (tmp == null) return;

    const len = std.mem.len(tmp);
    for (tmp[0..len]) |ch| {
        if (ch == '\n') {
            try game_states.getPtr(current_state).keypress(c.GLFW_KEY_ENTER, 0, true);
            try game_states.getPtr(current_state).keypress(c.GLFW_KEY_ENTER, 0, false);
        } else try game_states.getPtr(current_state).keychar(ch, 0);
    }
}

pub fn settingSet(event: system_events.EventSetSetting) !void {
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

    if (std.mem.eql(u8, event.setting, "refresh_rate")) {
        state_refresh_rate = std.fmt.parseFloat(f64, event.value) catch 0.5;

        return;
    }

    if (std.mem.eql(u8, event.setting, "sound_volume")) {
        audio_manager.volume = @as(f32, @floatFromInt(std.fmt.parseInt(i32, event.value, 0) catch 100)) / 100.0;

        return;
    }

    if (std.mem.eql(u8, event.setting, "sound_muted")) {
        audio_manager.muted = std.ascii.eqlIgnoreCase("yes", event.value);

        return;
    }

    if (std.mem.eql(u8, event.setting, "crt_shader")) {
        const val: c_int = if (std.ascii.eqlIgnoreCase("yes", event.value)) 1 else 0;

        if (is_crt) {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            crt_shader.setInt("crt_enable", val);
            crt_shader.setInt("dither_enable", 0);

            crt_enable = val == 1;
        }

        return;
    }
}

pub fn runCmdEvent(event: system_events.EventRunCmd) !void {
    for (email_manager.emails.items) |*email| {
        if (!email_manager.getEmailVisible(email, "admin@eee.org")) continue;
        if (email.condition != .Run) continue;

        if (std.ascii.eqlIgnoreCase(email.condition.Run.req, event.cmd)) {
            try email_manager.setEmailComplete(email);
        }
    }
}

pub fn syscall(event: system_events.EventSys) !void {
    for (email_manager.emails.items) |*email| {
        if (!email_manager.getEmailVisible(email, "admin@eee.org")) continue;
        if (email.condition != .SysCall) continue;

        const num = email.condition.SysCall.id;

        if (num == event.sysId) {
            try email_manager.setEmailComplete(email);
        }
    }
}

pub fn drawLoading(self: *loading_state.GSLoading) void {
    while (!self.done.load(.monotonic) and !paniced) {
        {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            if (!gfx.Context.poll())
                self.done.store(true, .monotonic);
        }

        // render loading screen
        self.draw(gfx.Context.instance.size) catch {};

        blit() catch {};
        std.Thread.yield() catch {};
    }
}

pub fn windowResize(event: input_events.EventWindowResize) !void {
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    try gfx.Context.resize(event.w, event.h);

    // clear the window
    c.glBindTexture(c.GL_TEXTURE_2D, rendered_texture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    // Poor filtering. Needed !
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    c.glBindRenderbuffer(c.GL_RENDERBUFFER, depth_render_buffer);
    c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)));
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    paniced = true;

    batch.SpriteBatch.instance.scissor = null;

    error_state = @intFromEnum(current_state);

    // panic log asap
    const st = panic_handler.log();
    error_message = std.fmt.allocPrint(allocator.alloc, "{s}\n{s}", .{ msg, st }) catch {
        std.process.exit(0);
    };

    std.fs.cwd().writeFile("CrashLog.txt", error_message) catch {};

    // no display on headless
    if (is_headless) {
        std.process.exit(0);
    }

    // disable events on loading screen
    input_events.setup(gfx.Context.instance.window, true);

    // update game state
    current_state = .Crash;

    // run setup
    game_states.getPtr(.Crash).setup() catch {};

    batch.SpriteBatch.instance.clear() catch {};

    while (gfx.Context.poll()) {
        // get crash state
        const state = game_states.getPtr(.Crash);

        state.update(1.0 / 60.0) catch |err| {
            log.log.err("crash draw failed, {!}", .{err});

            break;
        };
        state.draw(gfx.Context.instance.size) catch |err| {
            log.log.err("crash draw failed, {!}", .{err});

            break;
        };
        blit() catch |err| {
            log.log.err("crash blit failed {!}", .{err});

            break;
        };
    }

    log.log.info("Exiting", .{});

    std.process.exit(0);
}

var is_headless = false;
var is_crt = true;

pub fn main() void {
    defer if (!builtin.link_libc or !allocator.useclib) {
        if (allocator.gpa.deinit() == .ok)
            log.log.debug("no leaks! :)", .{});
    };

    mainErr() catch |err| {
        const name = switch (err) {
            error.FramebufferSetupFail, error.CompileError, error.GLADInitFailed => "Your GPU might not support SandEEE.",
            error.AudioInit => "Your audio hardware might not support SandEEE.",
            error.WrongSize, error.TextureMissing => "Failed to load an internal texture.",
            error.LoadError => "Failed to load something.",
            error.NoProfFolder => "There is no prof folder on your disk.",
            error.NoExecFolder => "There is no exec folder on your disk.",
            error.BadFile => "Your disk is problaby corrupt.",
            else => "PLEASE REPORT THIS ERROR, EEE HAS NOT SEEN IT.",
        };

        const msg = std.fmt.allocPrint(allocator.alloc, "{s}\n{s}", .{ @errorName(err), name }) catch "Cannont allocate error message";

        @panic(msg);
    };
}

pub fn mainErr() anyerror!void {
    if (options.IsSteam) {
        if (steam.restartIfNeeded(steam.STEAM_APP_ID)) {
            log.log.err("Restarting for steam", .{});
            return; // steam will relaunch the game from the steam client.
        }

        try steam.init();

        var user = steam.getUser();
        const steam_id = user.getSteamId();
        steam_utils = steam.getSteamUtils();
        steam_user_stats = steam.getUserStats();
        _ = steam_id;
        _ = steam_utils;
    }

    // setup the headless command
    var headless_cmd: ?[]const u8 = null;

    // check arguments
    var args = try std.process.ArgIterator.initWithAllocator(allocator.alloc);

    // ignore first arg
    _ = args.next();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--cwd")) {
            if (args.next()) |path|
                try std.process.changeCurDir(path)
            else
                return error.MissingCwd;
        } else if (std.mem.eql(u8, arg, "--no-crt")) {
            is_crt = false;
        } else if (std.mem.eql(u8, arg, "--headless")) {
            is_headless = true;
        } else if (std.mem.eql(u8, arg, "--headless-cmd")) {
            if (args.next()) |script| {
                const buff = try allocator.alloc.alloc(u8, 1024);
                const file = try std.fs.cwd().openFile(script, .{});

                const len = try file.readAll(buff);
                headless_cmd = buff[0..len];
                file.close();

                is_headless = true;
            } else return error.MissingScript;
        }
    }

    // free the argument iterator
    args.deinit();

    // setup vm manager
    vm_manager.VMManager.init();

    // switch to headless main function if nessessary
    if (is_headless) {
        return headless.headlessMain(headless_cmd, false, null);
    }

    log.log_file = try std.fs.cwd().createFile("SandEEE.log", .{});
    defer log.log_file.?.close();

    log.log.info("Sandeee " ++ options.VersionText, .{options.SandEEEVersion});

    // setup the texture manager
    texture_manager.TextureManager.init();

    // init graphics
    try gfx.Context.init("SandEEE");

    audio_manager = try audio.Audio.init();

    // setup fonts deinit
    bios_font.setup = false;
    main_font.setup = false;

    var blip_sound: audio.Sound = audio.Sound.init(BLIP_SOUND_DATA);
    var select_sound: audio.Sound = audio.Sound.init(SELECT_SOUND_DATA);

    // create the loaders queue
    loader_queue = .{};

    // shaders
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &SHADER_FILES, &shader, worker.shader.loadShader);
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &FONT_SHADER_FILES, &font_shader, worker.shader.loadShader);
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &CRT_SHADER_FILES, &crt_shader, worker.shader.loadShader);
    try loader.enqueue(*const [2]shd.ShaderFile, *shd.Shader, &CLEAR_SHADER_FILES, &clear_shader, worker.shader.loadShader);

    // fonts
    try loader.enqueue(*const []const u8, *font.Font, &BIOS_FONT_DATA, &bios_font, worker.font.loadFont);

    // load bios
    var prog: f32 = 0;
    try loader.run(&prog);

    // start setup states
    gfx.Context.makeCurrent();

    // enable crt by default
    crt_shader.setInt("crt_enable", if (is_crt) 1 else 0);
    crt_shader.setInt("dither_enable", if (is_crt) 1 else 0);

    // setup render texture for shaders
    c.glGenFramebuffers(1, &framebuffer_name);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebuffer_name);

    c.glGenBuffers(1, &quad_vertex_array_id);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_vertex_array_id);
    c.glBufferData(c.GL_ARRAY_BUFFER, @as(c.GLsizeiptr, @intCast(FULL_QUAD.len * @sizeOf(f32))), &FULL_QUAD, c.GL_DYNAMIC_DRAW);

    // create color texture
    c.glGenTextures(1, &rendered_texture);

    // clear the windo
    c.glBindTexture(c.GL_TEXTURE_2D, rendered_texture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    // Poor filtering. Needed !
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    // create depth texture
    c.glGenRenderbuffers(1, &depth_render_buffer);

    c.glBindRenderbuffer(c.GL_RENDERBUFFER, depth_render_buffer);
    c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, @as(i32, @intFromFloat(gfx.Context.instance.size.x)), @as(i32, @intFromFloat(gfx.Context.instance.size.y)));
    c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depth_render_buffer);

    c.glFramebufferTexture(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, rendered_texture, 0);

    c.glDrawBuffers(1, &[_]c.GLenum{c.GL_COLOR_ATTACHMENT0});

    if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE)
        return error.FramebufferSetupFail;

    // create the sprite batch
    try batch.SpriteBatch.init(&gfx.Context.instance.size);

    // load some textures
    try texture_manager.TextureManager.instance.putMem("bios", BIOS_IMAGE);
    try texture_manager.TextureManager.instance.putMem("logo", LOGO_IMAGE);
    try texture_manager.TextureManager.instance.putMem("load", LOAD_IMAGE);
    try texture_manager.TextureManager.instance.putMem("sad", SAD_IMAGE);
    try texture_manager.TextureManager.instance.putMem("error", ERROR_IMAGE);
    try texture_manager.TextureManager.instance.putMem("white", &WHITE_IMAGE);

    wallpaper = .{
        .texture = "wall",
        .data = .{
            .dims = &gfx.Context.instance.size,
            .mode = .Center,
        },
    };

    // disks state
    var gs_disks = disk_state.GSDisks{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .disk = &disk,
        .blip_sound = &blip_sound,
        .select_sound = &select_sound,
        .audio_manager = &audio_manager,
        .logo_sprite = .{
            .texture = "bios",
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 168, .y = 84 },
            },
        },
    };

    // loading state
    var gs_loading = loading_state.GSLoading{
        .face = &main_font,
        .audio_man = &audio_manager,
        .email_manager = &email_manager,
        .loading = drawLoading,
        .logout_snd = &logout_snd,
        .message_snd = &message_snd,
        .logo_sprite = .{
            .texture = "logo",
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 320, .y = 64 },
            },
        },
        .load_sprite = .{
            .texture = "load",
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 0, .y = 16 },
            },
        },
        .shader = &shader,
        .disk = &disk,
        .loader = &loader,
    };

    // windowed state
    var gs_windowed = windowed_state.GSWindowed{
        .shader = &shader,
        .font_shader = &font_shader,
        .clear_shader = &clear_shader,
        .face = &main_font,
        .email_manager = &email_manager,
        .bar_logo_sprite = .{
            .texture = "barlogo",
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 36, .y = 464 },
            },
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
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .total = 6,
            },
        },
        .wallpaper = &wallpaper,
        .bar = .{
            .texture = "bar",
            .data = .{
                .height = 38,
                .screendims = &gfx.Context.instance.size,
                .shell = .{
                    .root = undefined,
                },
                .shader = &shader,
            },
        },
    };

    // crashed state
    const gs_crash = try allocator.alloc.create(crash_state.GSCrash);
    gs_crash.* = .{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .message = &error_message,
        .prev_state = &error_state,
        .sad_sprite = .{
            .texture = "sad",
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 150, .y = 150 },
            },
        },
    };

    // install state
    var gs_install = install_state.GSInstall{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .select_sound = &select_sound,
        .audio_manager = &audio_manager,
        .load_sprite = .{
            .texture = "white",
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 20, .y = 32 },
            },
        },
    };

    // logout state
    var gs_logout = logout_state.GSLogout{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .logout_sound = &logout_snd,
        .audio_man = &audio_manager,
        .wallpaper = &wallpaper,
        .clear_shader = &clear_shader,
    };

    // recovery state
    var gsRecovery = recovery_state.GSRecovery{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .blip_sound = &blip_sound,
        .select_sound = &select_sound,
        .audio_manager = &audio_manager,
    };

    // done states setup
    gfx.Context.makeNotCurrent();

    // setup event system
    events.EventManager.init();

    // add input management event handlers
    try events.EventManager.instance.registerListener(input_events.EventWindowResize, windowResize);
    try events.EventManager.instance.registerListener(input_events.EventMouseScroll, mouseScroll);
    try events.EventManager.instance.registerListener(input_events.EventMouseMove, mouseMove);
    try events.EventManager.instance.registerListener(input_events.EventMouseDown, mouseDown);
    try events.EventManager.instance.registerListener(input_events.EventMouseUp, mouseUp);
    try events.EventManager.instance.registerListener(input_events.EventKeyDown, keyDown);
    try events.EventManager.instance.registerListener(input_events.EventKeyChar, keyChar);
    try events.EventManager.instance.registerListener(input_events.EventKeyUp, keyUp);

    // add system event handlers
    try events.EventManager.instance.registerListener(system_events.EventSetSetting, settingSet);
    try events.EventManager.instance.registerListener(system_events.EventStateChange, changeState);
    try events.EventManager.instance.registerListener(window_events.EventNotification, notification);
    try events.EventManager.instance.registerListener(system_events.EventRunCmd, runCmdEvent);
    try events.EventManager.instance.registerListener(system_events.EventPaste, paste);
    try events.EventManager.instance.registerListener(system_events.EventCopy, copy);
    try events.EventManager.instance.registerListener(system_events.EventSys, syscall);

    // setup game states
    game_states.set(.Disks, states.GameState.init(&gs_disks));
    game_states.set(.Loading, states.GameState.init(&gs_loading));
    game_states.set(.Windowed, states.GameState.init(&gs_windowed));
    game_states.set(.Crash, states.GameState.init(gs_crash));
    game_states.set(.Logout, states.GameState.init(&gs_logout));
    game_states.set(.Recovery, states.GameState.init(&gsRecovery));
    game_states.set(.Installer, states.GameState.init(&gs_install));

    // run setup
    try game_states.getPtr(.Disks).setup();
    input_events.setup(gfx.Context.instance.window, true);

    // setup state machine
    var prev = current_state;

    // fps tracker stats
    var fps: usize = 0;
    var timer: std.time.Timer = try std.time.Timer.start();
    var last_frame_end: f64 = 0;

    c.glfwSetTime(0);

    // main loop
    while (gfx.Context.poll()) {
        // get the time & update
        const start_time = c.glfwGetTime();

        // get the current state
        const state = game_states.getPtr(prev);

        // pause the game on minimize
        if (c.glfwGetWindowAttrib(gfx.Context.instance.window, c.GLFW_ICONIFIED) == 0) {

            // steam callbacks
            if (options.IsSteam) {
                const cb = struct {
                    fn callback(callbackMsg: steam.CallbackMsg) anyerror!void {
                        _ = callbackMsg;
                        //log.log.warn("steam callback {}", .{callbackMsg.callback});
                    }
                }.callback;

                try steam.manualCallback(cb);
            }

            // update the game state
            try state.update(@max(1 / 60, @as(f32, @floatCast(vm_manager.VMManager.last_frame_time))));

            // get tris
            try state.draw(gfx.Context.instance.size);
        }

        // track fps
        if (timer.read() > @as(u64, @intFromFloat(std.time.ns_per_s * state_refresh_rate))) {
            try events.EventManager.instance.sendEvent(system_events.EventTelemUpdate{});

            const lap = timer.lap();

            try state.refresh();

            try vm_manager.VMManager.instance.runGc();

            final_fps = @as(u32, @intFromFloat(@as(f64, @floatFromInt(fps)) / @as(f64, @floatFromInt(lap)) * @as(f64, @floatFromInt(std.time.ns_per_s))));
            if (vm_manager.VMManager.instance.vms.count() != 0 and final_fps != 0) {
                if (final_fps < 55) {
                    vm_manager.VMManager.vm_time -= 0.01;
                }

                if (final_fps > 58) {
                    vm_manager.VMManager.vm_time += 0.01;
                }

                vm_manager.VMManager.vm_time = std.math.clamp(vm_manager.VMManager.vm_time, 0.25, 0.9);
            }

            fps = 0;
        }

        // the state changed
        if (current_state != prev) {
            prev = current_state;

            state.deinit();

            // run setup
            try game_states.getPtr(current_state).setup();

            try batch.SpriteBatch.instance.clear();
        } else {
            // track update time
            vm_manager.VMManager.last_update_time = c.glfwGetTime() - start_time;

            // render this is in else to fix single frame bugs
            try blit();
            fps += 1;

            // update the time
            const frame_time = c.glfwGetTime() - last_frame_end;
            if (frame_time != 0) {
                vm_manager.VMManager.last_frame_time = frame_time;
                last_frame_end = c.glfwGetTime();
            }
        }
    }

    // free crash state bc game can no longer crash
    allocator.alloc.destroy(gs_crash);

    // deinit sb
    batch.SpriteBatch.deinit();

    // deinit events
    events.EventManager.deinit();

    // deinit the current state
    game_states.getPtr(current_state).deinit();

    vm_manager.VMManager.instance.deinit();

    // deinit fonts
    bios_font.deinit();

    // deinit textures
    texture_manager.TextureManager.deinit();

    // close window
    gfx.Context.deinit();
}

test "headless.zig" {
    _ = @import("system/headless.zig");
    _ = @import("system/vm.zig");
}
