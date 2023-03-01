const std = @import("std");
const builtin = @import("builtin");

const vecs = @import("math/vecs.zig");
const mat4 = @import("math/mat4.zig");
const cols = @import("math/colors.zig");
const rect = @import("math/rects.zig");
const gfx = @import("graphics.zig");
const tex = @import("texture.zig");
const batch = @import("spritebatch.zig");
const font = @import("util/font.zig");
const wall = @import("drawers/wall2d.zig");
const sp = @import("drawers/sprite2d.zig");
const win = @import("drawers/window2d.zig");
const bars = @import("drawers/bar2d.zig");
const shd = @import("shader.zig");
const fm = @import("util/files.zig");
const files = @import("system/files.zig");
const events = @import("util/events.zig");
const shell = @import("system/shell.zig");
const audio = @import("util/audio.zig");
const pseudo = @import("system/pseudo/all.zig");

const inputEvs = @import("events/input.zig");
const windowEvs = @import("events/window.zig");

const allocator = @import("util/allocator.zig");
const vm = @import("system/vm.zig");
const mail = @import("system/mail.zig");
const wins = @import("windows/all.zig");
const c = @import("c.zig");
const worker = @import("loaders/worker.zig");

var wallpaper: wall.Wallpaper = undefined;
var ctx: gfx.Context = undefined;
var wintex: tex.Texture = undefined;
var bartex: tex.Texture = undefined;
var walltex: tex.Texture = undefined;
var emailtex: tex.Texture = undefined;
var editortex: tex.Texture = undefined;
var explorertex: tex.Texture = undefined;
var sb: batch.SpriteBatch = undefined;
var shader: shd.Shader = shd.Shader{};
var font_shader: shd.Shader = shd.Shader{};
var face: font.Font = undefined;
var windows: std.ArrayList(win.Window) = undefined;
var bar: bars.Bar = undefined;
var audioMan: audio.Audio = undefined;
var logoSprite: sp.Sprite = undefined;
var loadSprite: sp.Sprite = undefined;
var loadProgress: f32 = 0;

var dragging: ?*win.Window = null;
var draggingStart: vecs.Vector2 = vecs.newVec2(0, 0);
var dragmode: win.DragMode = win.DragMode.None;
var mousepos: vecs.Vector2 = vecs.newVec2(0, 0);

const GameState = enum { Loading, Game, Crash };
var gameState: GameState = .Loading;

const vertShader = @embedFile("shaders/vert.glsl");
const fragShader = @embedFile("shaders/frag.glsl");
const fontVertShader = @embedFile("shaders/fvert.glsl");
const fontFragShader = @embedFile("shaders/ffrag.glsl");

const logoImage = @embedFile("images/logo.eia");
const loadImage = @embedFile("images/load.eia");
const paletteImage = @embedFile("images/palette.eia");

var logoOff: vecs.Vector2 = vecs.newVec2(0, 0);

const shader_files = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = fragShader, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = vertShader, .kind = c.GL_VERTEX_SHADER },
};

const font_shader_files = [2]shd.ShaderFile{
    shd.ShaderFile{ .contents = fontFragShader, .kind = c.GL_FRAGMENT_SHADER },
    shd.ShaderFile{ .contents = fontVertShader, .kind = c.GL_VERTEX_SHADER },
};

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub fn draw() !void {
    switch (gameState) {
        .Loading => {
            // make sure shader is loaded
            if (shader.id != 0) {
                // draw the logo
                sb.draw(sp.Sprite, &logoSprite, shader, vecs.newVec3(logoOff.x, logoOff.y, 0));

                // progress bar
                loadSprite.data.size.x = (loadProgress * 320 + loadSprite.data.size.x) / 2;

                sb.draw(sp.Sprite, &loadSprite, shader, vecs.newVec3(logoOff.x, logoOff.y + 100, 0));
            }
        },
        .Game => {
            sb.draw(wall.Wallpaper, &wallpaper, shader, vecs.newVec3(0, 0, 0));

            // render the windows in order
            for (windows.items) |window, idx| {
                // continue if window closed on update
                if (idx >= windows.items.len) continue;

                // draw the window border
                sb.draw(win.Window, &windows.items[idx], shader, vecs.newVec3(0, 0, 0));

                // draw the windows name
                windows.items[idx].data.drawName(font_shader, &face, &sb);

                // update scisor region
                sb.scissor = window.data.scissor();

                // draw the window contents
                windows.items[idx].data.drawContents(font_shader, &face, &sb);

                // reset scisor jic
                sb.scissor = null;
            }

            // draw the bar
            sb.draw(bars.Bar, &bar, shader, vecs.newVec3(0, 0, 0));
            bar.data.drawName(font_shader, &face, &sb, &windows);
        },
        .Crash => {
        },
    }

    // actual gl calls start here
    ctx.makeCurrent();

    // clear the window
    gfx.clear(ctx);

    // finish render
    try sb.render();

    c.glFlush();
    c.glFinish();

    // swap buffer
    gfx.swap(ctx);

    // actual gl calls done
    ctx.makeNotCurrent();
}

pub fn linuxCrashHandler(_: i32, info: *const std.os.siginfo_t, _: ?*const anyopaque) callconv(.C) noreturn {
    gameState = .Crash;
    std.log.info("seg: {}, {any}", .{@ptrToInt(info.fields.sigfault.addr), info});
    while (gfx.poll(ctx)) draw() catch {
        break;
    };

    std.os.exit(0);
}

pub fn windowsCrashHandler(_: c_int) callconv(.C) noreturn {
    gameState = .Crash;
    while (gfx.poll(ctx)) draw() catch {
        break;
    };

    std.os.exit(0);
}

pub fn setupCrashHandler() !void {
    if (builtin.target.os.tag == .linux) {
        var act = std.os.Sigaction{
            .handler = .{ .sigaction = linuxCrashHandler },
            .mask = std.os.empty_sigset,
            .flags = (std.os.SA.SIGINFO | std.os.SA.RESTART | std.os.SA.RESETHAND),
        };
        try std.os.sigaction(c.SIGSEGV, &act, null);
    } else {
        _ = c.signal(c.SIGABRT, windowsCrashHandler);
    }
}

pub fn mouseDown(event: inputEvs.EventMouseDown) bool {
    for (windows.items) |_, idx| {
        var i = windows.items.len - idx - 1;

        if (!windows.items[i].data.active) continue;

        if (windows.items[i].data.click(mousepos, event.btn)) {
            return false;
        }
    }

    if (event.btn == 0) {
        if (bar.data.doClick(wintex, emailtex, editortex, explorertex, shader, mousepos)) {
            return false;
        }

        var newTop: i32 = -1;
        for (windows.items) |_, idx| {
            if (windows.items[idx].data.min) continue;

            var pos = windows.items[idx].data.pos;
            pos.x -= 20;
            pos.y -= 20;
            pos.w += 40;
            pos.h += 40;

            if (pos.contains(mousepos)) {
                newTop = @intCast(i32, idx);
            }

            windows.items[idx].data.active = false;
        }

        if (newTop != -1) {
            var swap = windows.orderedRemove(@intCast(usize, newTop));
            swap.data.active = true;
            swap.data.contents.focus();
            var mode = swap.data.getDragMode(mousepos);

            if (mode == win.DragMode.Close) {
                swap.data.deinit();
                return false;
            }
            if (mode == win.DragMode.Full) {
                if (swap.data.full) {
                    swap.data.pos = swap.data.oldpos;
                } else {
                    swap.data.oldpos = swap.data.pos;
                }
                swap.data.full = !swap.data.full;
            }
            if (mode == win.DragMode.Min) {
                swap.data.min = !swap.data.min;
            }
            windows.append(swap) catch {};

            if (mode != win.DragMode.None) {
                if (swap.data.full) return false;
                dragmode = mode;
                dragging = &windows.items[windows.items.len - 1];
                var start = dragging.?.data.pos;

                draggingStart = switch (dragmode) {
                    win.DragMode.None => vecs.newVec2(0, 0),
                    win.DragMode.Close => vecs.newVec2(0, 0),
                    win.DragMode.Full => vecs.newVec2(0, 0),
                    win.DragMode.Min => vecs.newVec2(0, 0),
                    win.DragMode.Move => vecs.newVec2(start.x - mousepos.x, start.y - mousepos.y),
                    win.DragMode.ResizeR => vecs.newVec2(start.w - mousepos.x, 0),
                    win.DragMode.ResizeB => vecs.newVec2(0, start.h - mousepos.y),
                    win.DragMode.ResizeL => vecs.newVec2(start.w + start.x, 0),
                    win.DragMode.ResizeRB => vecs.newVec2(start.w - mousepos.x, start.h - mousepos.y),
                    win.DragMode.ResizeLB => vecs.newVec2(start.w + start.x, start.h - mousepos.y),
                };
            }
        }
    }

    return false;
}

pub fn mouseUp(event: inputEvs.EventMouseUp) bool {
    _ = event;

    dragging = null;

    return false;
}

pub fn mouseMove(event: inputEvs.EventMouseMove) bool {
    var pos = vecs.newVec2(@floatCast(f32, event.x), @floatCast(f32, event.y));

    mousepos = pos;

    if (dragging != null) {
        var old = dragging.?.data.pos;
        var winpos = vecs.add(pos, draggingStart);
        switch (dragmode) {
            win.DragMode.None => {},
            win.DragMode.Close => {},
            win.DragMode.Full => {},
            win.DragMode.Min => {},
            win.DragMode.Move => {
                dragging.?.data.pos.x = winpos.x;
                dragging.?.data.pos.y = winpos.y;
            },
            win.DragMode.ResizeR => {
                dragging.?.data.pos.w = winpos.x;
            },
            win.DragMode.ResizeL => {
                dragging.?.data.pos.x = pos.x;
                dragging.?.data.pos.w = draggingStart.x - pos.x;
            },
            win.DragMode.ResizeB => {
                dragging.?.data.pos.h = winpos.y;
            },
            win.DragMode.ResizeRB => {
                dragging.?.data.pos.w = winpos.x;
                dragging.?.data.pos.h = winpos.y;
            },
            win.DragMode.ResizeLB => {
                dragging.?.data.pos.x = pos.x;
                dragging.?.data.pos.w = draggingStart.x - pos.x;
                dragging.?.data.pos.h = winpos.y;
            },
        }
        if (dragging.?.data.pos.w < 400) {
            dragging.?.data.pos.x = old.x;
            dragging.?.data.pos.w = old.w;
        }
        if (dragging.?.data.pos.h < 300) {
            dragging.?.data.pos.y = old.y;
            dragging.?.data.pos.h = old.h;
        }
    }

    return false;
}

pub fn mouseScroll(event: inputEvs.EventMouseScroll) bool {
    for (windows.items) |_, idx| {
        var i = windows.items.len - idx - 1;

        if (!windows.items[i].data.active) continue;

        windows.items[i].data.contents.scroll(event.x, event.y);

        break;
    }
    return false;
}

pub fn keyDown(event: inputEvs.EventKeyDown) bool {
    // if the bar is open close & return
    if (bar.data.btnActive) {
        bar.data.btnActive = false;

        return false;
    }

    // send to active window
    for (windows.items) |_, idx| {
        var i = windows.items.len - idx - 1;

        if (!windows.items[i].data.active) continue;

        if (windows.items[i].data.key(event.key, event.mods)) {
            return false;
        }
    }
    return false;
}

pub fn keyUp(event: inputEvs.EventKeyUp) bool {
    _ = event;
    return false;
}

pub fn windowResize(event: inputEvs.EventWindowResize) bool {
    gfx.resize(event.w, event.h) catch {};

    var size = vecs.newVec2(@intToFloat(f32, event.w), @intToFloat(f32, event.h));

    bar.data.screendims = size;
    sb.size = size;
    win.deskSize = size;
    wallpaper.data.dims = size;

    return false;
}

pub fn createWindow(event: windowEvs.EventCreateWindow) bool {
    for (windows.items) |_, idx| {
        windows.items[idx].data.active = false;
    }

    windows.append(event.window) catch {
        std.log.err("couldnt create window!", .{});
        return false;
    };
    return false;
}

pub fn drawLoading() void {
    while (gameState == .Loading) {
        // render loading screen
        draw() catch {};
    }

    return;
}

pub fn setupEvents() !void {
    events.init();

    events.em.registerListener(inputEvs.EventWindowResize, windowResize);
    events.em.registerListener(inputEvs.EventMouseMove, mouseMove);
    events.em.registerListener(inputEvs.EventMouseDown, mouseDown);
    events.em.registerListener(inputEvs.EventMouseUp, mouseUp);
    events.em.registerListener(inputEvs.EventMouseScroll, mouseScroll);
    events.em.registerListener(inputEvs.EventKeyDown, keyDown);
    events.em.registerListener(inputEvs.EventKeyUp, keyUp);

    events.em.registerListener(windowEvs.EventCreateWindow, createWindow);

    inputEvs.setup(ctx.window);
}

pub fn setupForLoad() !void {
    var w: c_int = 0;
    var h: c_int = 0;

    ctx.makeCurrent();

    c.glfwGetWindowSize(ctx.window, &w, &h);

    sb = try batch.newSpritebatch(@intToFloat(f32, w), @intToFloat(f32, h));
    win.deskSize = vecs.newVec2(@intToFloat(f32, w), @intToFloat(f32, h));

    logoOff = vecs.newVec2(@intToFloat(f32, w - 320) / 2.0, @intToFloat(f32, h - 70) / 2.0);

    logoSprite = sp.Sprite{
        .texture = try tex.newTextureMem(logoImage),
        .data = sp.SpriteData.new(
            rect.newRect(0, 0, 1, 1),
            vecs.newVec2(320, 70),
        ),
    };

    loadSprite = sp.Sprite{
        .texture = try tex.newTextureMem(loadImage),
        .data = sp.SpriteData.new(
            rect.newRect(0, 0, 1, 1),
            vecs.newVec2(20, 20),
        ),
    };

    gfx.palette = try tex.newTextureMem(paletteImage);

    c.glActiveTexture(c.GL_TEXTURE1);
    c.glBindTexture(c.GL_TEXTURE_2D, gfx.palette.tex);
    c.glActiveTexture(c.GL_TEXTURE0);

    ctx.makeNotCurrent();

    audioMan = try audio.Audio.init();
}

pub fn setupBar() !void {
    var w: c_int = 0;
    var h: c_int = 0;

    ctx.makeCurrent();

    c.glfwGetWindowSize(ctx.window, &w, &h);

    bar = bars.Bar.new(bartex, bars.BarData{
        .height = 38,
        .screendims = vecs.newVec2(@intToFloat(f32, w), @intToFloat(f32, h)),
    });

    wallpaper = wall.Wallpaper.new(walltex, wall.WallData{
        .dims = vecs.newVec2(@intToFloat(f32, w), @intToFloat(f32, h)),
        .mode = .Center,
        .size = walltex.size,
    });

    ctx.makeNotCurrent();
}

pub fn main() anyerror!void {
    defer if (!builtin.link_libc or !allocator.useclib) {
        std.debug.assert(!allocator.gpa.deinit());
        std.log.info("no leaks! :)", .{});
    };

    // consts for loader
    const winpath: []const u8 = "/cont/imgs/window.eia";
    const wallpath: []const u8 = "/cont/imgs/wall.eia";
    const barpath: []const u8 = "/cont/imgs/bar.eia";
    const editorpath: []const u8 = "/cont/imgs/editor.eia";
    const emailpath: []const u8 = "/cont/imgs/email.eia";
    const explorerpath: []const u8 = "/cont/imgs/explorer.eia";
    const loginpath: []const u8 = "/cont/snds/login.era";
    const zero: u8 = 0;
    var fontpath = fm.getContentPath("content/font.ttf");

    // init graphics
    ctx = try gfx.init("Sandeee");
    gfx.gContext = &ctx;

    // setup load textures and stuff
    try setupForLoad();

    // create login sound
    var loginSnd: audio.Sound = undefined;

    // create loader
    var loader_queue = std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)).init();
    var loader = worker.WorkerContext{ .queue = &loader_queue };

    // shaders
    try loader.enqueue(&shader_files, &shader, worker.shader.loadShader);
    try loader.enqueue(&font_shader_files, &font_shader, worker.shader.loadShader);

    // files
    try loader.enqueue(&zero, &zero, worker.files.loadFiles);

    // textures
    try loader.enqueue(&winpath, &wintex, worker.texture.loadTexture);
    try loader.enqueue(&barpath, &bartex, worker.texture.loadTexture);
    try loader.enqueue(&wallpath, &walltex, worker.texture.loadTexture);
    try loader.enqueue(&editorpath, &editortex, worker.texture.loadTexture);
    try loader.enqueue(&emailpath, &emailtex, worker.texture.loadTexture);
    try loader.enqueue(&explorerpath, &explorertex, worker.texture.loadTexture);

    // sounds
    try loader.enqueue(&loginpath, &loginSnd, worker.sound.loadSound);

    // fonts
    try loader.enqueue(&fontpath.items, &face, worker.font.loadFont);

    var renderThread = try std.Thread.spawn(.{ .stack_size = 128 }, drawLoading, .{});
    try loader.run(&loadProgress);

    // post main load
    try setupEvents();
    try setupBar();

    // setup mail
    // TODO make loader
    mail.init();
    try mail.load();

    // create windows list
    windows = std.ArrayList(win.Window).init(allocator.alloc);

    // setup some pointers
    pseudo.window.windowsPtr = &windows;
    pseudo.window.shader = &shader;
    shell.wintex = &wintex;
    pseudo.window.wintex = &wintex;
    shell.edittex = &editortex;
    shell.shader = &shader;

    std.time.sleep(100000000);

    // loading done
    gameState = .Game;
    renderThread.join();

    // cleanup load
    fontpath.deinit();

    // set wallpaper color
    ctx.color = cols.newColorRGBA(0, 128, 128, 255);

    // play login sound
    try audioMan.playSound(loginSnd);

    // main loop
    //try setupCrashHandler();

    while (gfx.poll(ctx)) try draw();

    // save the current disk
    try files.write("disk.eee");

    // free everything
    for (windows.items) |_, idx| {
        windows.items[idx].data.deinit();
    }

    windows.deinit();
    gfx.close(ctx);
    files.deinit();
    sb.deinit();
    events.deinit();
    mail.deinit();
}
