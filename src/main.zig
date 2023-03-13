const std = @import("std");
const builtin = @import("builtin");

const states = @import("states/manager.zig");
const diskState = @import("states/disks.zig");
const loadingState = @import("states/loading.zig");
const windowedState = @import("states/windowed.zig");
const crashState = @import("states/crash.zig");

const fm = @import("util/files.zig");
const font = @import("util/font.zig");
const audio = @import("util/audio.zig");
const events = @import("util/events.zig");
const allocator = @import("util/allocator.zig");

const inputEvs = @import("events/input.zig");
const windowEvs = @import("events/window.zig");
const systemEvs = @import("events/system.zig");

const gfx = @import("graphics.zig");
const shd = @import("shader.zig");
const batch = @import("spritebatch.zig");
const tex = @import("texture.zig");

const worker = @import("loaders/worker.zig");

const vecs = @import("math/vecs.zig");
const rect = @import("math/rects.zig");

const wall = @import("drawers/wall2d.zig");
const sprite = @import("drawers/sprite2d.zig");
const bar = @import("drawers/bar2d.zig");

const conf = @import("system/config.zig");

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

const STATES = 4;
var gameStates: [STATES]states.GameState = undefined;
var currentState: u8 = 0;

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
    currentState = event.targetState;

    return false;
}

pub fn keyDown(event: inputEvs.EventKeyDown) bool {
    if (event.key == c.GLFW_KEY_F1) {
        @panic("JorjeOp");
    }

    return gameStates[currentState].keypress(event.key, event.mods) catch false;
}

pub fn mouseDown(event: inputEvs.EventMouseDown) bool {
    gameStates[currentState].mousepress(event.btn) catch return false;
    return false;
}

pub fn mouseUp(_: inputEvs.EventMouseUp) bool {
    gameStates[currentState].mouserelease() catch return false;
    return false;
}

pub fn mouseMove(event: inputEvs.EventMouseMove) bool {
    gameStates[currentState].mousemove(vecs.newVec2(@floatCast(f32, event.x), @floatCast(f32, event.y))) catch return false;
    return false;
}

pub fn mouseScroll(event: inputEvs.EventMouseScroll) bool {
    gameStates[currentState].mousescroll(vecs.newVec2(@floatCast(f32, event.x), @floatCast(f32, event.y))) catch return false;
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
    while (self.done == false) {
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

pub fn panic(msg: []const u8, st: ?*std.builtin.StackTrace, addr: ?usize) noreturn {
    currentState = 3;
    std.log.err("crash: {s}, {?}, {?any}", .{ msg, addr, st });
    while (gfx.poll(&ctx)) {
        var state = currentState;

        if (!gameStates[state].isSetup) {
            inputEvs.setup(ctx.window, state != 1);
            gameStates[state].setup() catch {};
        }

        gameStates[state].update(1.0 / 60.0) catch {};
        gameStates[state].draw(size) catch {};

        blit() catch {};
    }
    std.os.exit(0);
}

pub fn main() anyerror!void {
    defer if (!builtin.link_libc or !allocator.useclib) {
        std.debug.assert(!allocator.gpa.deinit());
        std.log.info("no leaks! :)", .{});
    };

    // init graphics
    ctx = try gfx.init("Sandeee");
    gfx.gContext = &ctx;
    size = ctx.size;

    var bigfontpath = fm.getContentPath("content/bios.ttf");
    var biosFace: font.Font = undefined;
    var mainFace: font.Font = undefined;

    loader_queue = std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)).init();

    // shaders
    try loader.enqueue(&shader_files, &shader, worker.shader.loadShader);
    try loader.enqueue(&font_shader_files, &font_shader, worker.shader.loadShader);

    // fonts
    try loader.enqueue(&bigfontpath.items, &biosFace, worker.font.loadFont);

    audioman = try audio.Audio.init();

    // load bios
    var prog: f32 = 0;
    loader.run(&prog) catch {
        @panic("BIOS Load Failed");
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
        .bar_logo_sprite = .{
            .texture = &barlogotex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(36, 464),
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
        .sb = &sb,
        .sad_sprite = .{
            .texture = &sadTex,
            .data = sprite.SpriteData.new(
                rect.newRect(0, 0, 1, 1),
                vecs.newVec2(150, 150),
            ),
        },
    };

    // done states setup
    ctx.makeNotCurrent();

    // setup event system
    try setupEvents();

    // setup game states
    gameStates[0] = states.GameState.init(&gsDisks);
    gameStates[1] = states.GameState.init(&gsLoading);
    gameStates[2] = states.GameState.init(&gsWindowed);
    gameStates[3] = states.GameState.init(&gsCrash);

    // main loop
    while (gfx.poll(&ctx)) {
        var state = currentState;

        // setup the current state if not already
        if (!gameStates[state].isSetup) {
            // disable events on loading screen
            inputEvs.setup(ctx.window, state != 1);

            // run setup
            try gameStates[state].setup();
        }

        // TODO: actual time?
        try gameStates[state].update(1.0 / 60.0);

        // get tris
        try gameStates[state].draw(size);

        // render
        try blit();
    }
}
