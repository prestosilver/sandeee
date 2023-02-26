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

var ctx: gfx.Context = undefined;
var wintex: tex.Texture = undefined;
var bartex: tex.Texture = undefined;
var emailtex: tex.Texture = undefined;
var editortex: tex.Texture = undefined;
var explorertex: tex.Texture = undefined;
var sb: batch.SpriteBatch = undefined;
var shader: shd.Shader = undefined;
var font_shader: shd.Shader = undefined;
var face: font.Font = undefined;
var windows: std.ArrayList(win.Window) = undefined;
var bar: bars.Bar = undefined;
var audioMan: audio.Audio = undefined;
var logoSprite: sp.Sprite = undefined;
var loadProgress: f32 = 0;

var dragging: ?*win.Window = null;
var draggingStart: vecs.Vector2 = vecs.newVec2(0, 0);
var dragmode: win.DragMode = win.DragMode.None;
var mousepos: vecs.Vector2 = vecs.newVec2(0, 0);

const GameState = enum { Loading, Game };
var gameState: GameState = .Loading;

const vertShader = @embedFile("shaders/vert.glsl");
const fragShader = @embedFile("shaders/frag.glsl");
const fontVertShader = @embedFile("shaders/fvert.glsl");
const fontFragShader = @embedFile("shaders/ffrag.glsl");

const logoImage = @embedFile("images/logo.eia");
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
    gfx.clear(ctx);

    switch (gameState) {
        .Loading => {
            ctx.color = ctx.color.mix(cols.newColorRGBA(172, 50, 50, 255), 0.05);
            // TODO: progress bar
            sb.draw(sp.Sprite, &logoSprite, shader, vecs.newVec3(logoOff.x, logoOff.y, 0));
        },
        .Game => {
            for (windows.items) |window, idx| {
                if (idx >= windows.items.len) continue;

                sb.draw(win.Window, &windows.items[idx], shader, vecs.newVec3(0, 0, 0));
                windows.items[idx].data.drawName(font_shader, &face, &sb);

                sb.scissor = window.data.scissor();
                windows.items[idx].data.drawContents(font_shader, &face, &sb);
                sb.scissor = null;
            }

            sb.draw(bars.Bar, &bar, shader, vecs.newVec3(0, 0, 0));
            bar.data.drawName(font_shader, &face, &sb, &windows);
        },
    }

    try sb.render();

    c.glFlush();
    c.glFinish();

    gfx.swap(ctx);
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
        // get glfw access
        ctx.makeCurrent();

        // render loading screen
        draw() catch {};

        // release glfw access
        ctx.makeNotCurrent();
    }

    return;
}

pub fn main() anyerror!void {
    defer if (!builtin.link_libc or !allocator.useclib) {
        std.debug.assert(!allocator.gpa.deinit());
        std.log.info("no leaks! :)", .{});
    };

    const winpath: []const u8 = "/cont/imgs/window.eia";
    const barpath: []const u8 = "/cont/imgs/bar.eia";
    const editorpath: []const u8 = "/cont/imgs/editor.eia";
    const emailpath: []const u8 = "/cont/imgs/email.eia";
    const explorerpath: []const u8 = "/cont/imgs/explorer.eia";
    const loginpath: []const u8 = "/cont/snds/login.era";
    var fontpath = fm.getContentPath("content/font.ttf");

    ctx = try gfx.init("Sandeee");
    gfx.gContext = &ctx;

    try files.Folder.init();

    var w: c_int = 0;
    var h: c_int = 0;

    ctx.makeCurrent();

    // TODO: extract to another func
    events.init();
    events.em.registerListener(inputEvs.EventWindowResize, windowResize);
    inputEvs.setup(ctx.window);

    c.glfwGetWindowSize(ctx.window, &w, &h);

    sb = try batch.newSpritebatch(@intToFloat(f32, w), @intToFloat(f32, h));

    logoOff = vecs.newVec2(@intToFloat(f32, w - 320) / 2.0, @intToFloat(f32, h - 70) / 2.0);

    logoSprite = sp.Sprite{
        .texture = try tex.newTextureMem(logoImage),
        .data = sp.SpriteData.new(
            rect.newRect(0, 0, 1, 1),
            vecs.newVec2(320, 70),
        ),
    };

    ctx.makeNotCurrent();

    audioMan = try audio.Audio.init();

    var loginSnd: audio.Sound = undefined;

    var loader_queue = std.atomic.Queue(worker.WorkerQueueEntry(*void, *void)).init();
    var loader = worker.WorkerContext{ .queue = &loader_queue };

    // shaders
    try loader.enqueue(&shader_files, &shader, worker.shader.loadShader);
    try loader.enqueue(&font_shader_files, &font_shader, worker.shader.loadShader);

    // textures
    try loader.enqueue(&winpath, &wintex, worker.texture.loadTexture);
    try loader.enqueue(&barpath, &bartex, worker.texture.loadTexture);
    try loader.enqueue(&editorpath, &editortex, worker.texture.loadTexture);
    try loader.enqueue(&emailpath, &emailtex, worker.texture.loadTexture);
    try loader.enqueue(&explorerpath, &explorertex, worker.texture.loadTexture);

    // sounds
    try loader.enqueue(&loginpath, &loginSnd, worker.sound.loadSound);

    // fonts
    try loader.enqueue(&fontpath.items, &face, worker.font.loadFont);

    var renderThread = try std.Thread.spawn(.{ .stack_size = 128 }, drawLoading, .{});
    try loader.run(&loadProgress);

    fontpath.deinit();

    bar = bars.Bar.new(bartex, bars.BarData{
        .height = 38,
        .screendims = vecs.newVec2(@intToFloat(f32, w), @intToFloat(f32, h)),
    });

    shell.wintex = &wintex;
    pseudo.window.wintex = &wintex;
    shell.edittex = &editortex;

    mail.init();
    try mail.load();

    shell.shader = &shader;

    windows = std.ArrayList(win.Window).init(allocator.alloc);
    pseudo.window.windowsPtr = &windows;

    events.em.registerListener(inputEvs.EventMouseMove, mouseMove);
    events.em.registerListener(inputEvs.EventMouseDown, mouseDown);
    events.em.registerListener(inputEvs.EventMouseUp, mouseUp);
    events.em.registerListener(inputEvs.EventMouseScroll, mouseScroll);
    events.em.registerListener(inputEvs.EventKeyDown, keyDown);
    events.em.registerListener(inputEvs.EventKeyUp, keyUp);

    events.em.registerListener(windowEvs.EventCreateWindow, createWindow);

    try audioMan.playSound(loginSnd);

    gameState = .Game;

    renderThread.join();

    ctx.color = cols.newColorRGBA(0, 128, 128, 255);

    ctx.makeCurrent();
    while (gfx.poll(ctx)) try draw();
    ctx.makeNotCurrent();

    for (windows.items) |_, idx| {
        windows.items[idx].data.deinit();
    }

    try files.write("disk.eee");

    windows.deinit();
    gfx.close(ctx);
    files.deinit();
    sb.deinit();
    events.deinit();
    mail.deinit();
}
