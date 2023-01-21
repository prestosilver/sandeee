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
const input = @import("util/input.zig");
const allocator = @import("util/allocator.zig");
const vm = @import("system/vm.zig");
const mail = @import("system/mail.zig");
const wins = @import("windows/all.zig");
const c = @import("c.zig");

var ctx: gfx.Context = undefined;
var wintex: tex.Texture = undefined;
var bartex: tex.Texture = undefined;
var emailtex: tex.Texture = undefined;
var editortex: tex.Texture = undefined;
var explorertex: tex.Texture = undefined;
var sprite: sp.Sprite = undefined;
var sb: batch.SpriteBatch = undefined;
var shader: shd.Shader = undefined;
var font_shader: shd.Shader = undefined;
var face: font.Font = undefined;
var windows: std.ArrayList(win.Window) = undefined;
var bar: bars.Bar = undefined;

var dragging: ?*win.Window = null;
var draggingStart: vecs.Vector2 = vecs.newVec2(0, 0);
var dragmode: win.DragMode = win.DragMode.None;
var mousepos: vecs.Vector2 = vecs.newVec2(0, 0);

const vertShader = @embedFile("shaders/vert.glsl");
const fragShader = @embedFile("shaders/frag.glsl");
const fontVertShader = @embedFile("shaders/fvert.glsl");
const fontFragShader = @embedFile("shaders/ffrag.glsl");

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

pub fn draw() void {
    gfx.clear(ctx);

    for (windows.items) |window, idx| {
        sb.draw(win.Window, &windows.items[idx], shader, vecs.newVec3(0, 0, 0));
        windows.items[idx].data.drawName(font_shader, &face, &sb);

        sb.scissor = window.data.scissor();
        windows.items[idx].data.drawContents(font_shader, &face, &sb);
        sb.scissor = null;
    }

    sb.draw(bars.Bar, &bar, shader, vecs.newVec3(0, 0, 0));
    bar.data.drawName(font_shader, &face, &sb, &windows);

    sb.render();

    c.glFlush();
    c.glFinish();

    gfx.swap(ctx);
}

pub fn mouseDown(event: input.EventMouseDown) bool {
    for (windows.items) |_, idx| {
        var i = windows.items.len - idx - 1;

        if (!windows.items[i].data.active) continue;

        if (windows.items[i].data.click(mousepos, event.btn)) {
            return false;
        }
    }

    if (event.btn == 0) {
        if (bar.data.doClick(wintex, emailtex, editortex, explorertex, shader, &windows, mousepos)) {
            return false;
        }

        var newTop: i32 = -1;
        for (windows.items) |_, idx| {
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

pub fn mouseUp(event: input.EventMouseUp) bool {
    _ = event;

    dragging = null;

    return false;
}

pub fn mouseMove(event: input.EventMouseMove) bool {
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

pub fn keyDown(event: input.EventKeyDown) bool {
    for (windows.items) |_, idx| {
        var i = windows.items.len - idx - 1;

        if (!windows.items[i].data.active) continue;

        if (windows.items[i].data.key(event.key, event.mods)) {
            return false;
        }
    }
    return false;
}

pub fn keyUp(event: input.EventKeyUp) bool {
    _ = event;
    return false;
}

pub fn windowResize(event: input.EventWindowResize) bool {
    gfx.resize(event.w, event.h);

    var size = vecs.newVec2(@intToFloat(f32, event.w), @intToFloat(f32, event.h));

    bar.data.screendims = size;
    sb.size = size;
    win.deskSize = size;

    return false;
}

pub fn main() anyerror!void {
    //defer std.debug.assert(!allocator.gpa.deinit());
    defer if(!builtin.link_libc) {
        std.log.info("arena", .{});
        allocator.arena.deinit();
    };

    ctx = gfx.init("Programing Simulator");
    gfx.gContext = &ctx;

    sb = batch.newSpritebatch();

    var path: std.ArrayList(u8) = undefined;
    path = fm.getContentPath("content/window.png");
    wintex = tex.newTextureFile(path.items);
    path.deinit();

    path = fm.getContentPath("content/bar.png");
    bartex = tex.newTextureFile(path.items);
    path.deinit();

    path = fm.getContentPath("content/editor.png");
    editortex = tex.newTextureFile(path.items);
    path.deinit();

    path = fm.getContentPath("content/email.png");
    emailtex = tex.newTextureFile(path.items);
    path.deinit();

    path = fm.getContentPath("content/explorer.png");
    explorertex = tex.newTextureFile(path.items);
    path.deinit();

    path = fm.getContentPath("content/font.ttf");
    face = try font.Font.init(path.items, 22);
    path.deinit();

    input.setup(ctx.window);

    files.Folder.init();

    mail.init();
    mail.load() catch {};

    shader = shd.Shader.new(2, shader_files);
    font_shader = shd.Shader.new(2, font_shader_files);
    gfx.regShader(&ctx, shader);
    gfx.regShader(&ctx, font_shader);

    windows = std.ArrayList(win.Window).init(allocator.alloc);

    input.em.registerListener(input.EventMouseMove, mouseMove);
    input.em.registerListener(input.EventMouseDown, mouseDown);
    input.em.registerListener(input.EventMouseUp, mouseUp);
    input.em.registerListener(input.EventKeyDown, keyDown);
    input.em.registerListener(input.EventKeyUp, keyUp);
    input.em.registerListener(input.EventWindowResize, windowResize);

    bar = bars.Bar.new(bartex, bars.BarData{
        .height = 38,
        .screendims = vecs.newVec2(640, 480),
    });

    while (gfx.poll(ctx)) draw();

    for (windows.items) |_, idx| {
        windows.items[idx].data.deinit();
    }

    files.write("disk.eee");

    windows.deinit();
    gfx.close(ctx);
    files.deinit();
    sb.deinit();
    input.em.deinit();
    mail.deinit();
}
