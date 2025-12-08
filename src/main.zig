// modules
const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");
const steam = @import("steam");

pub const drawers = @import("drawers/mod.zig");
pub const loaders = @import("loaders/mod.zig");
pub const system = @import("system/mod.zig");
pub const events = @import("events/mod.zig");
pub const states = @import("states/mod.zig");
pub const math = @import("math/mod.zig");
pub const util = @import("util/mod.zig");
pub const data = @import("data/mod.zig");

// not-op programming lang
const c = @import("c.zig");

// states
const GameState = states.GameState;
const StateManager = states.Manager;
const DiskState = states.Disks;
const LoadingState = states.Loading;
const WindowedState = states.Windowed;
const CrashState = states.Crashed;
const InstallState = states.Installer;
const RecoveryState = states.Recovery;
const LogoutState = states.Logout;

// utilities
const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const panic_handler = util.panic;
const allocator = util.allocator;
const graphics = util.graphics;
const storage = util.storage;
const audio = util.audio;
const log = util.logger;

// events
const EventManager = events.EventManager;
const input_events = events.input;
const window_events = events.windows;
const system_events = events.system;

// loader
const Loader = loaders.Loader;

// op math
const Color = math.Color;
const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

// drawers
const Notification = drawers.Notification;
const Window = drawers.Window;
const Cursor = drawers.Cursor;
const Sprite = drawers.Sprite;
const Wall = drawers.Wall;
const Desk = drawers.Desk;
const Bar = drawers.Bar;

// misc system stuff
const VmManager = system.VmManager;
const Shell = system.Shell;
const headless = system.headless;
const config = system.config;
const files = system.files;
const mail = system.mail;

// data
const strings = data.strings;

pub const std_options = std.Options{
    // Define logFn to override the std implementation
    .logFn = log.sandEEELogFn,
    .log_level = .debug,
};

pub const steam_options = struct {
    pub const fake_steam = options.fakeSteam;
    pub const use_steam = options.IsSteam;
    pub const app_id = 4124360;
    pub const alloc = allocator.alloc;
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

const SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    Shader.ShaderFile{ .contents = VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
};

const FONT_SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = FONT_FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    Shader.ShaderFile{ .contents = FONT_VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
};

const CRT_SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = CRT_FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    Shader.ShaderFile{ .contents = CRT_VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
};

const CLEAR_SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = CLEAR_FRAG_SHADER, .kind = c.GL_FRAGMENT_SHADER },
    Shader.ShaderFile{ .contents = CLEAR_VERT_SHADER, .kind = c.GL_VERTEX_SHADER },
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
var game_states: std.EnumArray(system_events.State, GameState) = .initUndefined();
var current_state: system_events.State = .Disks;

// create some fonts
var bios_font: Font = undefined;
var main_font: Font = undefined;

// shaders
var font_shader: Shader = undefined;
var crt_shader: Shader = undefined;
var clear_shader: Shader = undefined;
var shader: Shader = undefined;

// the selected disk
var disk: ?[]u8 = null;

// wallpaper stuff
var wallpaper: Wall = undefined;

// sounds
var message_snd: audio.Sound = undefined;
var logout_snd: audio.Sound = undefined;

// for panic
var error_message: []const u8 = "Error: Unknown Error";
var error_state: u8 = 0;
var paniced = false;

// for Shader rect
var framebuffer_name: c.GLuint = 0;
var quad_vertex_array_id: c.GLuint = 0;
var rendered_texture: c.GLuint = 0;
var depth_render_buffer: c.GLuint = 0;

// fps tracking
var final_fps: u32 = 60;
var show_fps: bool = false;

// steam
var steam_user_stats: *const steam.UserStats = undefined;
var steam_utils: *const steam.Utils = undefined;

var crt_enable = true;

pub fn blit() !void {
    const start_time = c.glfwGetTime();

    // actual gl calls start here
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    if (c.glfwGetWindowAttrib(graphics.Context.instance.window, c.GLFW_ICONIFIED) != 0) {
        // for when minimized render nothing
        graphics.Context.clear();

        graphics.Context.swap();

        return;
    }

    if (show_fps and bios_font.setup) {
        const text = try std.fmt.allocPrint(allocator.alloc, "{s}FPS: {}\n{s}VMS: {}\n{s}VMT: {}%\nSTA: {}", .{
            if (final_fps < 50)
                strings.COLOR_RED
            else
                strings.COLOR_WHITE,
            final_fps,
            if (VmManager.instance.vms.count() == 0)
                strings.COLOR_GRAY
            else
                strings.COLOR_WHITE,
            VmManager.instance.vms.count(),
            strings.COLOR_WHITE,
            @as(u8, @intFromFloat(VmManager.vm_time * 100)),
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

    if (crt_enable)
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, framebuffer_name);

    graphics.Context.clear();

    // finish render
    try SpriteBatch.global.render();

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

    VmManager.last_render_time = c.glfwGetTime() - start_time;

    // swap buffer
    graphics.Context.swap();
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
    try audio.instance.playSound(message_snd);
}

pub fn copy(event: system_events.EventCopy) !void {
    const to_copy = try allocator.alloc.dupeZ(u8, event.value);
    defer allocator.alloc.free(to_copy);

    c.glfwSetClipboardString(graphics.Context.instance.window, to_copy);
}

pub fn paste(_: system_events.EventPaste) !void {
    const tmp = c.glfwGetClipboardString(graphics.Context.instance.window);
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
        audio.instance.volume = @as(f32, @floatFromInt(std.fmt.parseInt(i32, event.value, 0) catch 100)) / 100.0;

        return;
    }

    if (std.mem.eql(u8, event.setting, "sound_muted")) {
        audio.instance.muted = std.ascii.eqlIgnoreCase("yes", event.value);

        return;
    }

    if (std.mem.eql(u8, event.setting, "crt_shader")) {
        const val: c_int = if (std.ascii.eqlIgnoreCase("yes", event.value)) 1 else 0;

        if (is_crt) {
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            crt_shader.setInt("crt_enable", val);
            crt_shader.setInt("dither_enable", val);

            crt_enable = val == 1;
        }

        return;
    }
}

pub fn runCmdEvent(event: system_events.EventRunCmd) !void {
    for (mail.EmailManager.instance.emails.items) |*email| {
        if (!mail.EmailManager.instance.getEmailVisible(email, "admin@eee.org")) continue;

        for (email.condition) |condition| {
            if (condition != .ShellRun) continue;

            if (std.ascii.eqlIgnoreCase(condition.ShellRun.cmd, event.cmd)) {
                try mail.EmailManager.instance.setEmailComplete(email);
            }
        }
    }
}

pub fn syscall(event: system_events.EventSys) !void {
    for (mail.EmailManager.instance.emails.items) |*email| {
        if (!mail.EmailManager.instance.getEmailVisible(email, "admin@eee.org")) continue;
        for (email.condition) |condition| {
            if (condition != .SysCall) continue;

            const num = condition.SysCall.id;

            if (num == event.sysId) {
                try mail.EmailManager.instance.setEmailComplete(email);
            }
        }
    }
}

pub fn drawLoading(self: *LoadingState) void {
    while (!self.done.load(.monotonic) and !paniced) {
        {
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            if (!graphics.Context.poll())
                self.done.store(true, .monotonic);

            // if (paniced)
            //     self.done.store(true, .monotonic);
        }

        // render loading screen
        self.draw(graphics.Context.instance.size) catch {};

        if (!self.done.load(.monotonic) and !paniced) {
            blit() catch {};
        }

        std.Thread.yield() catch {};
    }
}

pub fn windowResize(event: input_events.EventWindowResize) !void {
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    graphics.Context.resize(event.w, event.h);

    // clear the window
    c.glBindTexture(c.GL_TEXTURE_2D, rendered_texture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @as(i32, @intFromFloat(graphics.Context.instance.size.x)), @as(i32, @intFromFloat(graphics.Context.instance.size.y)), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    // Poor filtering. Needed !
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    c.glBindRenderbuffer(c.GL_RENDERBUFFER, depth_render_buffer);
    c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, @as(i32, @intFromFloat(graphics.Context.instance.size.x)), @as(i32, @intFromFloat(graphics.Context.instance.size.y)));
}

var graphics_init = false;

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    defer {
        log.deinit();

        if (!builtin.link_libc or !allocator.useclib) {
            std.debug.assert(allocator.gpa.deinit() == .ok);
        }
    }

    paniced = true;

    SpriteBatch.global.scissor = null;

    error_state = @intFromEnum(current_state);

    // panic log asap
    const st = panic_handler.log(trace);
    error_message = std.fmt.allocPrint(allocator.alloc, "{s}\n{s}\n\n{?}", .{ msg, st, trace }) catch {
        std.process.exit(1);
    };

    std.fs.cwd().writeFile(.{
        .sub_path = "CrashLog.txt",
        .data = error_message,
    }) catch {};

    // no display on headless
    if (!graphics_init) {
        std.process.exit(1);
    }

    // disable events on loading screen
    input_events.setup(graphics.Context.instance.window, true);

    // update game state
    current_state = .Crash;

    // run setup
    game_states.getPtr(.Crash).setup() catch {};

    SpriteBatch.global.clear() catch {};

    while (graphics.Context.poll()) {
        // get crash state
        const state = game_states.getPtr(.Crash);

        state.update(1.0 / 60.0) catch |err| {
            log.log.err("crash draw failed, {!}", .{err});

            break;
        };
        state.draw(graphics.Context.instance.size) catch |err| {
            log.log.err("crash draw failed, {!}", .{err});

            break;
        };
        blit() catch |err| {
            log.log.err("crash blit failed {!}", .{err});

            break;
        };
    }

    log.log.info("Exiting", .{});

    std.process.exit(1);
}

var is_crt = true;

pub fn print_help(path: []const u8, comptime reason: []const u8, reason_params: anytype) noreturn {
    std.debug.print(reason ++
        \\
        \\usage: 
        \\ {s} [args]
        \\
        \\--help           Display this message and exit
        \\--cwd            Set the current working directory of the game
        \\--no-crt         Disable the crt shader
        \\--no-thread      Disable threading
        \\--headless       Headless mode
        \\--headless-cmd   Run a command in headless mode then exit
        \\
    , reason_params ++ .{path});

    std.process.exit(1);
}

pub fn main() void {
    defer {
        log.deinit();

        if (!builtin.link_libc or !allocator.useclib) {
            std.debug.assert(allocator.gpa.deinit() == .ok);
        }
    }

    // setup the headless command
    var headless_cmd: ?[]const u8 = null;
    var cwd_change = false;

    {
        // check arguments
        var args = std.process.ArgIterator.initWithAllocator(allocator.alloc) catch @panic("Out of memory");
        defer args.deinit();

        const cmd_path = args.next().?;

        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--help"))
                print_help(cmd_path, "SandEEE help:", .{})
            else if (std.mem.eql(u8, arg, "--cwd")) {
                if (args.next()) |path|
                    std.process.changeCurDir(path) catch |err|
                        print_help(cmd_path, "Invalid cwd path '{s}' ({!}):", .{ path, err })
                else
                    print_help(cmd_path, "Expected cwd argument", .{});

                cwd_change = true;
            } else if (std.mem.eql(u8, arg, "--no-crt")) {
                is_crt = false;
            } else if (std.mem.eql(u8, arg, "--no-thread")) {
                LoadingState.no_load_thread = true;
            } else if (std.mem.eql(u8, arg, "--headless")) {
                headless.is_headless = true;
            } else if (std.mem.eql(u8, arg, "--headless-cmd")) {
                if (args.next()) |script| {
                    const buff = allocator.alloc.alloc(u8, 1024) catch @panic("out of memory");
                    const file = std.fs.cwd().openFile(script, .{}) catch |err|
                        print_help(cmd_path, "Headless script '{s}' couldnt be read ({!})", .{ script, err });
                    defer file.close();

                    const len = file.readAll(buff) catch @panic("couldnt read file");
                    headless_cmd = buff[0..len];

                    headless.is_headless = true;
                } else print_help(cmd_path, "Expected headless cmd argument", .{});
            } else {
                print_help(cmd_path, "Invalid paramter '{s}':", .{arg});
            }
        }
    }

    // switch to headless main function if nessessary
    if (headless.is_headless) {
        return headless.main(headless_cmd orelse &.{}, false, null) catch |err| {
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

            panic(msg, @errorReturnTrace(), null);
        };
    }

    runGame() catch |err| {
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

        panic(msg, @errorReturnTrace(), null);
    };

    std.log.info("Done", &.{});
}

pub fn runGame() anyerror!void {
    if (options.IsSteam) {
        if (steam.restartIfNeeded(steam.STEAM_APP_ID)) {
            log.log.err("Restarting for steam", .{});
            return; // steam will relaunch the game from the steam client.
        }

        try steam.init();

        steam_utils = steam.getSteamUtils();
        steam_user_stats = steam.getUserStats();

        // TODO: cleanup downloads maybe?
    }

    defer if (options.IsSteam)
        steam.deinit();

    // if (!cwd_change)
    // if (std.mem.lastIndexOf(u8, first orelse "", "/")) |last_slash|
    //     try std.process.changeCurDir(first.?[0..last_slash]);

    log.log_file = try std.fs.cwd().createFile("SandEEE.log", .{});
    defer log.log_file.?.close();

    log.log.info("Sandeee " ++ options.VersionText, .{options.SandEEEVersion});

    // init graphics
    var graphics_loader = try Loader.init(Loader.Graphics{});
    graphics_init = true;

    try audio.AudioManager.init();

    // setup fonts deinit
    bios_font.setup = false;
    main_font.setup = false;

    var blip_sound = audio.Sound.init(BLIP_SOUND_DATA);
    var select_sound = audio.Sound.init(SELECT_SOUND_DATA);

    // create the loaders queue
    var base_shader_loader = try Loader.init(Loader.Shader{
        .files = SHADER_FILES,
        .out = &shader,
    });
    try base_shader_loader.require(&graphics_loader);

    var font_shader_loader = try Loader.init(Loader.Shader{
        .files = FONT_SHADER_FILES,
        .out = &font_shader,
    });
    try font_shader_loader.require(&graphics_loader);

    var crt_shader_loader = try Loader.init(Loader.Shader{
        .files = CRT_SHADER_FILES,
        .out = &crt_shader,
    });
    try crt_shader_loader.require(&graphics_loader);

    var clear_shader_loader = try Loader.init(Loader.Shader{
        .files = CLEAR_SHADER_FILES,
        .out = &clear_shader,
    });
    try clear_shader_loader.require(&graphics_loader);

    var texture_loader = try Loader.init(Loader.Group{});
    try texture_loader.require(&base_shader_loader);
    try texture_loader.require(&font_shader_loader);
    try texture_loader.require(&crt_shader_loader);
    try texture_loader.require(&clear_shader_loader);

    // fonts
    var font_loader = try Loader.init(Loader.Font{
        .data = .{ .mem = BIOS_FONT_DATA },
        .output = &bios_font,
    });
    try font_loader.require(&graphics_loader);

    var loader = try Loader.init(Loader.Group{});
    try loader.require(&texture_loader);
    try loader.require(&font_loader);

    // load bios
    var prog: f32 = 0;
    var unloader = try loader.load(&prog, 0.0, 1.0);
    defer unloader.run();

    // start setup states
    graphics.Context.makeCurrent();

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
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @as(i32, @intFromFloat(graphics.Context.instance.size.x)), @as(i32, @intFromFloat(graphics.Context.instance.size.y)), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    // Poor filtering. Needed !
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    // create depth texture
    c.glGenRenderbuffers(1, &depth_render_buffer);

    c.glBindRenderbuffer(c.GL_RENDERBUFFER, depth_render_buffer);
    c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, @as(i32, @intFromFloat(graphics.Context.instance.size.x)), @as(i32, @intFromFloat(graphics.Context.instance.size.y)));
    c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depth_render_buffer);

    c.glFramebufferTexture(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, rendered_texture, 0);

    c.glDrawBuffers(1, &[_]c.GLenum{c.GL_COLOR_ATTACHMENT0});

    if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE)
        return error.FramebufferSetupFail;

    // give spritebatch size
    SpriteBatch.global.size = &graphics.Context.instance.size;

    // done states setup
    graphics.Context.makeNotCurrent();

    // load some textures
    try TextureManager.instance.putMem("bios", BIOS_IMAGE);
    try TextureManager.instance.putMem("logo", LOGO_IMAGE);
    try TextureManager.instance.putMem("load", LOAD_IMAGE);
    try TextureManager.instance.putMem("sad", SAD_IMAGE);
    try TextureManager.instance.putMem("error", ERROR_IMAGE);
    try TextureManager.instance.putMem("white", &WHITE_IMAGE);

    wallpaper = .atlas("wall", .{
        .dims = &graphics.Context.instance.size,
        .mode = .Center,
    });

    // disks state
    var gs_disks = DiskState{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .disk = &disk,
        .blip_sound = &blip_sound,
        .select_sound = &select_sound,
        .logo_sprite = .atlas("bios", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = 168, .y = 84 },
        }),
    };

    // loading state
    var gs_loading = LoadingState{
        .face = &main_font,
        .logout_snd = &logout_snd,
        .message_snd = &message_snd,
        .logo_sprite = .atlas("logo", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = 320, .y = 64 },
        }),
        .load_sprite = .atlas("load", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = 0, .y = 16 },
        }),
        .shader = &shader,
        .disk = &disk,
    };

    // windowed state
    var gs_windowed = WindowedState{
        .shader = &shader,
        .font_shader = &font_shader,
        .clear_shader = &clear_shader,
        .face = &main_font,
        .shell = .{
            .root = .root,
        },
        .bar_logo_sprite = .atlas("barlogo", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = 36, .y = 464 },
        }),
        .desk = .atlas("big_icons", .{
            .shell = .{
                .root = .home,
            },
        }),
        .cursor = .atlas("cursor", .{
            .source = .{ .w = 1, .h = 1 },
            .total = 6,
        }),
        .wallpaper = &wallpaper,
        .bar = .atlas("bar", .{
            .height = 38,
            .screendims = &graphics.Context.instance.size,
            .shell = .{
                .root = .home,
            },
            .shader = &shader,
        }),
    };

    // crashed state
    const gs_crash = try allocator.alloc.create(CrashState);
    gs_crash.* = .{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .message = &error_message,
        .prev_state = &error_state,
        .sad_sprite = .atlas("sad", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = 150, .y = 150 },
        }),
    };

    // install state
    var gs_install = InstallState{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .select_sound = &select_sound,
        .load_sprite = .atlas("white", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = 20, .y = 32 },
        }),
    };

    // logout state
    var gs_logout = LogoutState{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .logout_sound = &logout_snd,
        .wallpaper = &wallpaper,
        .clear_shader = &clear_shader,
    };

    // recovery state
    var gsRecovery = RecoveryState{
        .shader = &shader,
        .font_shader = &font_shader,
        .face = &bios_font,
        .blip_sound = &blip_sound,
        .select_sound = &select_sound,
    };

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
    input_events.setup(graphics.Context.instance.window, true);

    // setup state machine
    var prev = current_state;

    // fps tracker stats
    var fps: usize = 0;
    var timer: std.time.Timer = try std.time.Timer.start();
    var last_frame_end: f64 = 0;

    c.glfwSetTime(0);

    // main loop
    while (graphics.Context.poll()) {
        // get the time & update
        const start_time = c.glfwGetTime();

        // get the current state
        const state = game_states.getPtr(prev);

        // pause the game on minimize
        if (c.glfwGetWindowAttrib(graphics.Context.instance.window, c.GLFW_ICONIFIED) == 0) {

            // steam callbacks
            // if (options.IsSteam) {
            //     const cb = struct {
            //         fn callback(callbackMsg: steam.CallbackMsg) anyerror!void {
            //             _ = callbackMsg;
            //             //log.log.warn("steam callback {}", .{callbackMsg.callback});
            //         }
            //     }.callback;

            //     try steam.manualCallback(cb);
            // }

            // update the game state
            try state.update(@max(1 / 60, @as(f32, @floatCast(VmManager.last_frame_time))));

            // get tris
            try state.draw(graphics.Context.instance.size);
        }

        // track fps
        if (timer.read() > @as(u64, @intFromFloat(std.time.ns_per_s * state_refresh_rate))) {
            try events.EventManager.instance.sendEvent(system_events.EventTelemUpdate{});

            const lap = timer.lap();

            try state.refresh();

            // log.log.debug("Rendered in {d:.6}ms", .{VmManager.last_render_time * 1000});

            try VmManager.instance.runGc();

            final_fps = @as(u32, @intFromFloat(@as(f64, @floatFromInt(fps)) / @as(f64, @floatFromInt(lap)) * @as(f64, @floatFromInt(std.time.ns_per_s))));
            if (VmManager.instance.vms.count() != 0 and final_fps != 0) {
                if (final_fps < 55) {
                    VmManager.vm_time -= 0.01;
                }

                if (final_fps > 58) {
                    VmManager.vm_time += 0.01;
                }

                VmManager.vm_time = std.math.clamp(VmManager.vm_time, 0.25, 0.9);
            }

            fps = 0;
        }

        // the state changed
        if (current_state != prev) {
            prev = current_state;

            state.deinit();

            // run setup
            try game_states.getPtr(current_state).setup();

            // try batch.SpriteBatch.instance.clear();
        } else {
            // track update time
            VmManager.last_update_time = c.glfwGetTime() - start_time;

            // render this is in else to fix single frame bugs
            try blit();
            fps += 1;

            // update the time
            const frame_time = c.glfwGetTime() - last_frame_end;
            if (frame_time != 0) {
                VmManager.last_frame_time = frame_time;
                last_frame_end = c.glfwGetTime();
            }
        }
    }

    graphics_init = false;

    // deinit vm manager
    VmManager.instance.deinit();

    // deinit the current state
    game_states.getPtr(current_state).deinit();

    if (LogoutState.unloader) |*ul|
        ul.run();

    LogoutState.unloader = null;

    // free crash state bc game can no longer crash
    allocator.alloc.destroy(gs_crash);

    // deinit sb
    SpriteBatch.global.deinit();

    // deinit events
    events.EventManager.deinit();

    // deinit textures
    TextureManager.instance.deinit();

    log.log.info("graceful deinit", .{});
}

test "headless.zig" {
    _ = @import("util/mod.zig");
    _ = @import("system/mod.zig");
    _ = @import("util/url.zig");
    _ = @import("util/rope.zig");
}
