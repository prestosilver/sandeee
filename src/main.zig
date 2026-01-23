// modules
const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");
const steam = @import("steam");
const glfw = @import("glfw");
const zgl = @import("zgl");
const flags = @import("flags");

pub const drawers = @import("drawers.zig");
pub const loaders = @import("loaders.zig");
pub const system = @import("system.zig");
pub const events = @import("events.zig");
pub const states = @import("states.zig");
pub const math = @import("math.zig");
pub const util = @import("util.zig");
pub const data = @import("data.zig");

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
const Shell = system.Shell;
const Vm = system.Vm;
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
    pub const fake_steam = options.fake_steam;
    pub const use_steam = options.is_steam;
    pub const app_id = 4124360;
    pub const alloc = allocator;
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
const LOGO_IMAGE = @embedFile("logo.eia");
const LOAD_IMAGE = @embedFile("load.eia");
const BIOS_IMAGE = @embedFile("bios.eia");
const SAD_IMAGE = @embedFile("sad.eia");
const ERROR_IMAGE = @embedFile("error.eia");
const WHITE_IMAGE = [_]u8{ 'e', 'i', 'm', 'g', 1, 0, 1, 0, 255, 255, 255, 255 };

const BIOS_FONT_DATA: []const u8 = @embedFile("bios.eff");

const BLIP_SOUND_DATA = @embedFile("bios-blip.era");
const SELECT_SOUND_DATA = @embedFile("bios-select.era");

const SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = FRAG_SHADER, .kind = .fragment },
    Shader.ShaderFile{ .contents = VERT_SHADER, .kind = .vertex },
};

const FONT_SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = FONT_FRAG_SHADER, .kind = .fragment },
    Shader.ShaderFile{ .contents = FONT_VERT_SHADER, .kind = .vertex },
};

const CRT_SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = CRT_FRAG_SHADER, .kind = .fragment },
    Shader.ShaderFile{ .contents = CRT_VERT_SHADER, .kind = .vertex },
};

const CLEAR_SHADER_FILES = [2]Shader.ShaderFile{
    Shader.ShaderFile{ .contents = CLEAR_FRAG_SHADER, .kind = .fragment },
    Shader.ShaderFile{ .contents = CLEAR_VERT_SHADER, .kind = .vertex },
};

const FULL_QUAD = [_]zgl.Float{
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
var framebuffer_name: zgl.Framebuffer = .invalid;
var quad_vertex_array_id: zgl.Buffer = .invalid;
var rendered_texture: zgl.Texture = .invalid;
var depth_render_buffer: zgl.Renderbuffer = .invalid;

// fps tracking
var final_fps: f32 = 60;
var show_fps: bool = false;

// steam
var steam_user_stats: *const steam.UserStats = undefined;
var steam_utils: *const steam.Utils = undefined;

var crt_enable = true;

pub fn blit() !void {
    const start_time = glfw.getTime();

    // actual gl calls start here
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    if (glfw.getWindowAttrib(graphics.Context.instance.window, glfw.Iconified) != 0) {
        // for when minimized render nothing
        graphics.Context.clear();

        graphics.Context.swap();

        return;
    }

    if (show_fps and bios_font.setup) {
        const text = try std.fmt.allocPrint(allocator, "{s}FPS: {}\n{s}VMS: {}\n{s}VMT: {}%\nSTA: {}", .{
            if (final_fps < graphics.Context.instance.refresh_rate - 5)
                strings.COLOR_RED
            else
                strings.COLOR_WHITE,
            final_fps,
            if (Vm.Manager.instance.vms.count() == 0)
                strings.COLOR_GRAY
            else
                strings.COLOR_WHITE,
            Vm.Manager.instance.vms.count(),
            strings.COLOR_WHITE,
            @as(u8, @intFromFloat(Vm.Manager.vm_time * 100)),
            @intFromEnum(current_state),
        });
        defer allocator.free(text);

        try bios_font.draw(.{
            .text = text,
            .shader = &font_shader,
            .pos = .{},
            .color = .{ .r = 1, .g = 1, .b = 1 },
        });
    }

    if (crt_enable)
        framebuffer_name.bind(.buffer);

    graphics.Context.clear();

    // finish render
    try SpriteBatch.global.render();

    if (crt_enable) {
        zgl.Framebuffer.bind(.invalid, .buffer);
        quad_vertex_array_id.bind(.array_buffer);
        rendered_texture.bind(.@"2d");

        crt_shader.program.use();
        crt_shader.setFloat("time", @as(f32, @floatCast(glfw.getTime())));

        zgl.disable(.blend);

        zgl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(zgl.Float), 0);
        zgl.enableVertexAttribArray(0);
        zgl.drawArrays(.triangles, 0, 6);
        zgl.enable(.blend);

        zgl.bindBuffer(.invalid, .array_buffer);
    }

    Vm.Manager.last_render_time = glfw.getTime() - start_time;

    // swap buffer
    graphics.Context.swap();
}

pub fn changeState(event: system_events.EventStateChange) !void {
    current_state = event.target_state;
}

pub fn keyDown(event: input_events.EventKeyDown) !void {
    if (event.key == glfw.KeyF12) {
        show_fps = !show_fps;
    }

    if (event.key == glfw.KeyF12 and event.mods & glfw.ModifierControl != 0) {
        const fdsa: ?*u32 = null;
        log.log.info("{}", fdsa.?);
    }

    if (event.key == glfw.KeyV and event.mods == glfw.ModifierControl) {
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
    const to_copy = try allocator.dupeZ(u8, event.value);
    defer allocator.free(to_copy);

    glfw.setClipboardString(graphics.Context.instance.window, to_copy);
}

pub fn paste(_: system_events.EventPaste) !void {
    if (glfw.getClipboardString(graphics.Context.instance.window)) |clipboard_text| {
        for (clipboard_text) |ch| {
            if (ch == '\n') {
                try game_states.getPtr(current_state).keypress(glfw.KeyEnter, 0, true);
                try game_states.getPtr(current_state).keypress(glfw.KeyEnter, 0, false);
            } else try game_states.getPtr(current_state).keychar(ch, 0);
        }
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

            if (paniced)
                self.done.store(true, .monotonic);
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

    graphics.Context.resize(@intCast(event.w), @intCast(event.h));

    // clear the window
    rendered_texture.bind(.@"2d");

    zgl.textureImage2D(.@"2d", 0, .rgb, @intFromFloat(graphics.Context.instance.size.x), @intFromFloat(graphics.Context.instance.size.y), .rgb, .unsigned_byte, null);

    // Poor filtering. Needed !
    rendered_texture.parameter(.mag_filter, .linear);
    rendered_texture.parameter(.min_filter, .linear);
    rendered_texture.parameter(.wrap_s, .clamp_to_edge);
    rendered_texture.parameter(.wrap_t, .clamp_to_edge);

    depth_render_buffer.bind(.buffer);
    depth_render_buffer.storage(.buffer, .depth_component, @intFromFloat(graphics.Context.instance.size.x), @intFromFloat(graphics.Context.instance.size.y));
}

pub const panic = std.debug.FullPanic(
    if (builtin.is_test or options.default_panic)
        std.debug.defaultPanic
    else
        fullPanic,
);

fn fullPanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    defer {
        log.deinit();

        util.deinitAllocator();
    }

    if (paniced) std.process.exit(1);

    paniced = true;

    SpriteBatch.global.scissor = null;

    error_state = @intFromEnum(current_state);

    // panic log asap
    const st = panic_handler.log(msg, first_trace_addr);
    error_message = std.fmt.allocPrint(allocator, "{s}\n{s}\n", .{ msg, st }) catch {
        std.process.exit(1);
    };

    std.fs.cwd().writeFile(.{
        .sub_path = "CrashLog.txt",
        .data = error_message,
    }) catch {};

    // no display on headless
    if (!graphics.is_init) {
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

        state.update(1.0 / graphics.Context.instance.refresh_rate) catch |err| {
            log.log.err("crash draw failed, {any}", .{err});

            break;
        };
        state.draw(graphics.Context.instance.size) catch |err| {
            log.log.err("crash draw failed, {any}", .{err});

            break;
        };
        blit() catch |err| {
            log.log.err("crash blit failed {any}", .{err});

            break;
        };
    }

    log.log.info("Exiting", .{});

    std.process.exit(1);
}

var is_crt = true;
var real_fullscreen = false;

pub fn main() void {
    defer {
        log.deinit();

        util.deinitAllocator();
    }

    // setup the headless command
    var headless_cmd: ?[]const u8 = null;
    var cwd_change = false;

    const args = std.process.argsAlloc(allocator) catch std.debug.panic("Out of memory", .{});
    defer std.process.argsFree(allocator, args);

    const cli = flags.parse(
        args,
        "SandEEE",

        struct {
            pub const description =
                \\SandEEE OS: a virtual fantasy desktop.
            ;

            pub const descriptions = .{
                .no_crt = "Disable the crt filter.",
                .no_threads = "Disable loading threads.",
                .real_fullscreen = "Use real fullscreen instead of borderless windowed.",
                .cwd = "Set the working directory before loading anything.",
                .disk = "Automatically load a disk.",
                .extr_files = "Enable extr file system (Unsandboxed).",
                .headless = "Enable headless mode.",
                .headless_script = "Automatically run a script in headless mode.",
            };

            no_crt: bool,
            no_threads: bool,
            real_fullscreen: bool,
            cwd: ?[]const u8,
            disk: ?[]const u8,
            extr_files: bool,
            headless: bool,
            headless_script: ?[]const u8,
        },

        .{},
    );

    is_crt = !cli.no_crt;
    headless.is_headless = cli.headless;
    LoadingState.no_load_thread = cli.no_threads;
    real_fullscreen = cli.real_fullscreen;
    files.enable_extr = cli.extr_files;
    if (cli.disk) |new_disk| {
        headless.disk = new_disk;
        DiskState.autoload_disk = new_disk;
    }
    if (cli.cwd) |new_cwd| {
        std.process.changeCurDir(new_cwd) catch |err| {
            std.log.err("Failed to change cwd to '{s}', {}", .{ new_cwd, err });
            return;
        };
        cwd_change = true;
    }

    if (cli.headless_script) |script| {
        var file = std.fs.cwd().openFile(script, .{}) catch |err| {
            std.log.err("Failed to load headless script '{s}', {}", .{ script, err });
            return;
        };
        defer file.close();

        var reader = file.reader(&.{});
        headless_cmd = reader.interface.allocRemaining(allocator, .unlimited) catch {
            std.log.err("Out of memory", .{});
            return;
        };
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

            std.debug.panic("{s}\n{s}", .{ @errorName(err), name });
        };
    }

    std.fs.cwd().access("disks", .{}) catch
        std.fs.cwd().makeDir("disks") catch
        std.debug.panic("Cannot make disks directory.", .{});

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

        std.debug.panic("{s}\n{s}", .{ @errorName(err), name });
    };

    std.log.info("Done", .{});
}

pub fn runGame() anyerror!void {
    if (options.is_steam) {
        if (steam.restartIfNeeded(.this_app)) {
            log.log.err("Restarting for steam", .{});
            return; // steam will relaunch the game from the steam client.
        }

        try steam.init();

        steam_utils = steam.getSteamUtils();
        steam_user_stats = steam.getUserStats();

        // TODO: cleanup downloads maybe?
    }

    defer if (options.is_steam)
        steam.deinit();

    try log.setLogFile("SandEEE.log");

    log.log.info("Sandeee " ++ strings.SANDEEE_VERSION_TEXT, .{});

    try audio.AudioManager.init();

    // init graphics
    var graphics_loader: Loader = try .init(loaders.Graphics{ .real_fullscreen = real_fullscreen });

    // setup fonts deinit
    bios_font.setup = false;
    main_font.setup = false;

    var blip_sound: audio.Sound = .init(BLIP_SOUND_DATA);
    var select_sound: audio.Sound = .init(SELECT_SOUND_DATA);

    // create the loaders queue
    var base_shader_loader: Loader = try .init(loaders.Shader{
        .files = SHADER_FILES,
        .out = &shader,
    });
    try base_shader_loader.require(&graphics_loader);

    var font_shader_loader: Loader = try .init(loaders.Shader{
        .files = FONT_SHADER_FILES,
        .out = &font_shader,
    });
    try font_shader_loader.require(&graphics_loader);

    var crt_shader_loader: Loader = try .init(loaders.Shader{
        .files = CRT_SHADER_FILES,
        .out = &crt_shader,
    });
    try crt_shader_loader.require(&graphics_loader);

    var clear_shader_loader: Loader = try .init(loaders.Shader{
        .files = CLEAR_SHADER_FILES,
        .out = &clear_shader,
    });
    try clear_shader_loader.require(&graphics_loader);

    var texture_loader: Loader = try .init(loaders.Group{});
    try texture_loader.require(&base_shader_loader);
    try texture_loader.require(&font_shader_loader);
    try texture_loader.require(&crt_shader_loader);
    try texture_loader.require(&clear_shader_loader);

    // fonts
    var font_loader: Loader = try .init(loaders.Font{
        .data = .{ .mem = BIOS_FONT_DATA },
        .output = &bios_font,
    });
    try font_loader.require(&graphics_loader);

    var loader: Loader = try .init(loaders.Group{});
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
    framebuffer_name = zgl.genFramebuffer();
    framebuffer_name.bind(.buffer);

    quad_vertex_array_id = zgl.genBuffer();
    quad_vertex_array_id.bind(.array_buffer);
    quad_vertex_array_id.data(zgl.Float, &FULL_QUAD, .dynamic_draw);

    // create color texture
    rendered_texture = zgl.genTexture();

    // clear the windo
    rendered_texture.bind(.@"2d");

    // poor filtering needed
    rendered_texture.parameter(.mag_filter, .linear);
    rendered_texture.parameter(.min_filter, .linear);
    rendered_texture.parameter(.wrap_s, .clamp_to_edge);
    rendered_texture.parameter(.wrap_t, .clamp_to_edge);

    zgl.textureImage2D(.@"2d", 0, .rgb, @intFromFloat(graphics.Context.instance.size.x), @intFromFloat(graphics.Context.instance.size.y), .rgb, .unsigned_byte, null);

    // create depth texture
    depth_render_buffer = zgl.genRenderbuffer();
    depth_render_buffer.bind(.buffer);

    depth_render_buffer.storage(.buffer, .depth_component, @intFromFloat(graphics.Context.instance.size.x), @intFromFloat(graphics.Context.instance.size.y));

    framebuffer_name.renderbuffer(.buffer, .depth, .buffer, depth_render_buffer);
    framebuffer_name.texture(.buffer, .color0, rendered_texture, 0);

    zgl.drawBuffers(&.{.color0});

    if (zgl.checkFramebufferStatus(.buffer) != .complete)
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
    const gs_crash = try allocator.create(CrashState);
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
    var fps: f32 = 0;
    var timer: std.time.Timer = try .start();
    var last_frame_end: f64 = 0;

    glfw.setTime(0);

    // main loop
    while (graphics.Context.poll()) {
        // get the time & update
        const start_time = glfw.getTime();

        // get the current state
        const state = game_states.getPtr(prev);

        // pause the game on minimize
        if (glfw.getWindowAttrib(graphics.Context.instance.window, glfw.Iconified) == 0) {

            // update the game state
            try state.update(@max(1 / graphics.Context.instance.refresh_rate, @as(f32, @floatCast(Vm.Manager.last_frame_time))));

            // get tris
            try state.draw(graphics.Context.instance.size);
        }

        // track fps
        if (timer.read() > @as(u64, @intFromFloat(std.time.ns_per_s * state_refresh_rate))) {
            try events.EventManager.instance.sendEvent(system_events.EventTelemUpdate{});

            const lap: f32 = @floatFromInt(timer.lap());

            try state.refresh();

            // Make sure this dosent run on release, a print every frame problaby has overhead
            if (builtin.mode == .Debug)
                log.log.debug("Rendered in {d:.6}ms", .{Vm.Manager.last_render_time * 1000});

            try Vm.Manager.instance.runGc();

            final_fps = fps / lap * std.time.ns_per_s;
            if (Vm.Manager.instance.vms.count() != 0 and final_fps != 0) {
                // TODO: move these into settings
                if (final_fps < graphics.Context.instance.refresh_rate - 5.0) Vm.Manager.vm_time -= 0.01;
                if (final_fps > graphics.Context.instance.refresh_rate - 1.0) Vm.Manager.vm_time += 0.01;

                // limit goals for auto vm time calibration
                Vm.Manager.vm_time = std.math.clamp(Vm.Manager.vm_time, 0.25, 0.9);
            }

            fps = 0;
        }

        // the state changed
        if (current_state != prev) {
            prev = current_state;

            state.deinit();

            // run setup
            try game_states.getPtr(current_state).setup();
        } else {
            // track update time
            Vm.Manager.last_update_time = glfw.getTime() - start_time;

            // this render is in else to fix single frame bugs
            try blit();
            fps += 1;

            // update the time
            const frame_time = glfw.getTime() - last_frame_end;
            if (frame_time != 0) {
                Vm.Manager.last_frame_time = frame_time;
                last_frame_end = glfw.getTime();
            }
        }
    }

    // deinit vm manager
    Vm.Manager.instance.deinit();

    // deinit the current state
    game_states.getPtr(current_state).deinit();

    if (LogoutState.unloader) |*ul|
        ul.run();

    LogoutState.unloader = null;

    // free crash state bc game can no longer crash
    allocator.destroy(gs_crash);

    // deinit sb
    SpriteBatch.global.deinit();

    // deinit events
    events.EventManager.deinit();

    // deinit textures
    TextureManager.instance.deinit();

    log.log.info("graceful deinit", .{});
}

test {
    _ = util;
    _ = system;
}
