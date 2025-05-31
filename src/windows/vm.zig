const std = @import("std");
const builtin = @import("builtin");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const tex = @import("../util/texture.zig");
const batch = @import("../util/spritebatch.zig");
const shd = @import("../util/shader.zig");
const fnt = @import("../util/font.zig");
const spr = @import("../drawers/sprite2d.zig");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../util/graphics.zig");
const vm = @import("../system/vm.zig");
const c = @import("../c.zig");
const va = @import("../util/vertArray.zig");

const TextureManager = @import("../util/texmanager.zig").TextureManager;

pub const VMData = struct {
    const Self = @This();

    //rects: [2]std.ArrayList(VMDataEntry),
    textures: [2]tex.Texture,
    framebuffer: c.GLuint,
    renderbuffer: c.GLuint,
    arraybuffer: c.GLuint,

    back: bool = true,

    idx: u8,
    shader: *shd.Shader,

    frame_counter: f32 = 0,
    time: f32 = 0,
    fps: f32 = 0,
    debug: bool = false,
    input: []i32 = &.{},
    mousebtn: ?i32 = null,
    mousepos: vecs.Vector2 = .{},
    size: vecs.Vector2 = .{ .x = 600, .y = 400 },

    const VMDataKind = enum {
        rect,
        text,
    };

    const VMDataRect = struct {
        loc: vecs.Vector3,
        s: spr.Sprite,
    };

    const VMDataText = struct {
        pos: vecs.Vector2,
        text: []const u8,
    };

    const VMDataEntry = union(VMDataKind) {
        rect: VMDataRect,
        text: VMDataText,
    };

    pub fn addRect(self: *VMData, texture: []const u8, src: rect.Rectangle, dst: rect.Rectangle) !void {
        const fetched = TextureManager.instance.get(texture) orelse return;

        var verts = try va.VertArray.init(6);
        defer verts.deinit();

        try verts.appendQuad(dst, src, .{});

        {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            const old_size = gfx.Context.instance.size;

            gfx.Context.resize(@intFromFloat(self.size.x), @intFromFloat(self.size.y));
            defer gfx.Context.resize(@intFromFloat(old_size.x), @intFromFloat(old_size.y));

            var old_framebuffer: c.GLuint = 0;
            c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, @ptrCast(&old_framebuffer));
            defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, old_framebuffer);
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.framebuffer);

            c.glBindTexture(c.GL_TEXTURE_2D, fetched.tex);
            defer c.glBindTexture(c.GL_TEXTURE_2D, 0);

            c.glUseProgram(self.shader.id);
            defer c.glUseProgram(0);

            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.arraybuffer);
            c.glBufferData(c.GL_ARRAY_BUFFER, @as(c.GLsizeiptr, @intCast(verts.items().len * @sizeOf(va.Vert))), verts.items().ptr, c.GL_STREAM_DRAW);

            c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 9 * @sizeOf(f32), null);
            c.glVertexAttribPointer(1, 2, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
            c.glVertexAttribPointer(2, 4, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @ptrFromInt(5 * @sizeOf(f32)));
            c.glEnableVertexAttribArray(0);
            c.glEnableVertexAttribArray(1);
            c.glEnableVertexAttribArray(2);

            c.glDrawArrays(c.GL_TRIANGLES, 0, @as(c.GLsizei, @intCast(verts.items().len)));
        }

        // const appends: VMDataEntry = .{
        //     .rect = .{
        //         .loc = .{ .x = dst.x, .y = dst.y },
        //         .s = spr.Sprite{
        //             .texture = try allocator.alloc.dupe(u8, texture),
        //             .data = .{
        //                 .source = src,
        //                 .size = .{ .x = dst.w, .y = dst.h },
        //             },
        //         },
        //     },
        // };

        // if (self.back) try self.rects[0].append(appends);
        // if (!self.back) try self.rects[1].append(appends);
    }

    pub fn addText(self: *VMData, dst: vecs.Vector2, text: []const u8) !void {
        _ = dst;
        _ = text;

        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        var old_framebuffer: c.GLuint = 0;
        c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, @ptrCast(&old_framebuffer));
        defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, old_framebuffer);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.framebuffer);

        // const appends: VMDataEntry = .{
        //     .text = .{
        //         .pos = dst,
        //         .text = try allocator.alloc.dupe(u8, text),
        //     },
        // };

        // if (self.back) try self.rects[0].append(appends);
        // if (!self.back) try self.rects[1].append(appends);
    }

    pub fn flip(self: *VMData) void {
        self.frame_counter += 1;
        self.back = !self.back;

        {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            const back = &if (self.back) self.textures[0] else self.textures[1];

            var old_framebuffer: c.GLuint = 0;
            c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, @ptrCast(&old_framebuffer));
            defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, old_framebuffer);
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.framebuffer);

            c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, back.tex, 0);

            if (back.size.x != self.size.x or
                back.size.y != self.size.y)
            {
                c.glBindTexture(c.GL_TEXTURE_2D, back.tex);

                c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intFromFloat(self.size.x), @intFromFloat(self.size.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

                back.size = self.size;
            }
        }
    }

    pub fn clear(self: *VMData) void {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        var old_framebuffer: c.GLuint = 0;
        c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, @ptrCast(&old_framebuffer));

        defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, old_framebuffer);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.framebuffer);

        const back = if (self.back) self.textures[0] else self.textures[1];
        c.glBindTexture(c.GL_TEXTURE_2D, back.tex);

        c.glClearColor(0, 0, 0, 0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        // const rects = if (!self.back) &self.rects[1] else &self.rects[0];
        // for (rects.items) |item| {
        //     switch (item) {
        //         .text => {
        //             allocator.alloc.free(item.text.text);
        //         },
        //         .rect => {
        //             allocator.alloc.free(item.rect.s.texture);
        //         },
        //     }
        // }

        // rects.*.clearAndFree();
    }

    pub fn moveResize(self: *Self, bnds: rect.Rectangle) void {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        self.size = .{ .x = bnds.w, .y = bnds.h };

        {
            var old_renderbuffer: c.GLuint = 0;
            c.glGetIntegerv(c.GL_RENDERBUFFER_BINDING, @ptrCast(&old_renderbuffer));
            c.glBindRenderbuffer(c.GL_RENDERBUFFER, self.renderbuffer);
            defer c.glBindRenderbuffer(c.GL_RENDERBUFFER, old_renderbuffer);

            c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH24_STENCIL8, @intFromFloat(self.size.x), @intFromFloat(self.size.y));
        }

        {
            const back = if (self.back) self.textures[0] else self.textures[1];

            c.glBindTexture(c.GL_TEXTURE_2D, back.tex);
            c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intFromFloat(self.size.x), @intFromFloat(self.size.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);
        }
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, _: *win.WindowContents.WindowProps) !void {
        if (self.size.x == 0 and self.size.y == 0)
            self.moveResize(bnds.*);

        // // vm.syslock.lock();
        // // defer vm.syslock.unlock();

        const front = if (self.back) self.textures[1] else self.textures[0];

        try batch.SpriteBatch.instance.draw(spr.Sprite, &.override(front, .{
            .source = .{ .y = 1, .w = 1, .h = -1 },
            .size = .{ .x = bnds.w, .y = bnds.h },
        }), self.shader, .{ .x = bnds.x, .y = bnds.y, .z = 0 });

        // const rects = if (self.back) self.rects[1] else self.rects[0];

        // for (rects.items, 0..) |_, idx| {
        //     switch (rects.items[idx]) {
        //         .rect => {
        //             try batch.SpriteBatch.instance.draw(spr.Sprite, &rects.items[idx].rect.s, self.shader, .{ .x = bnds.x + rects.items[idx].rect.loc.x, .y = bnds.y + rects.items[idx].rect.loc.y, .z = rects.items[idx].rect.loc.z });
        //         },
        //         .text => {
        //             try font.draw(
        //                 .{
        //                     .shader = font_shader,
        //                     .pos = rects.items[idx].text.pos.add(bnds.location()),
        //                     .text = rects.items[idx].text.text,
        //                 },
        //             );
        //         },
        //     }
        // }

        self.time += 1.0 / 60.0;
        if (self.time > 1.0) {
            self.fps = self.frame_counter / self.time;
            self.frame_counter = 0;
            self.time = 0;
        }

        if (self.debug) {
            const val = try std.fmt.allocPrint(allocator.alloc, "FPS: {}", .{@as(i32, @intFromFloat(self.fps))});
            defer allocator.alloc.free(val);

            try font.draw(.{
                .shader = font_shader,
                .text = val,
                .pos = bnds.location(),
            });
        }
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (!down) {
            const old_input = self.input;
            defer allocator.alloc.free(old_input);

            self.input = try allocator.alloc.alloc(i32, std.mem.replacementSize(i32, self.input, &.{keycode}, &.{}));
            _ = std.mem.replace(i32, old_input, &.{keycode}, &.{}, self.input);

            return;
        }

        self.input = try allocator.alloc.realloc(self.input, self.input.len + 1);
        self.input[self.input.len - 1] = keycode;

        if (keycode == c.GLFW_KEY_F10) {
            self.debug = !self.debug;
        }
    }

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, btn: ?i32) !void {
        self.mousebtn = btn;
        self.mousepos = pos;
    }

    pub fn move(self: *Self, x: f32, y: f32) !void {
        self.mousepos = .{ .x = x, .y = y };
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.free(self.input);

        {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            c.glDeleteFramebuffers(1, &self.framebuffer);
            c.glDeleteRenderbuffers(1, &self.framebuffer);
            c.glDeleteBuffers(1, &self.arraybuffer);
        }

        allocator.alloc.destroy(self);
    }
};

pub fn init(idx: u8, shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(VMData);

    {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        var textures: [2]c.GLuint = .{ 0, 0 };
        c.glGenTextures(2, &textures);
        errdefer c.glDeleteTextures(2, &textures);

        inline for (textures) |texture| {
            c.glBindTexture(c.GL_TEXTURE_2D, texture);

            c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, 600, 400, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        }

        var vab: c.GLuint = 0;
        c.glGenBuffers(1, &vab);
        errdefer c.glDeleteBuffers(1, &vab);

        var rbo: c.GLuint = 0;
        c.glGenRenderbuffers(1, &rbo);
        errdefer c.glDeleteRenderbuffers(1, &rbo);

        {
            var old_renderbuffer: c.GLuint = 0;
            c.glGetIntegerv(c.GL_RENDERBUFFER_BINDING, @ptrCast(&old_renderbuffer));
            c.glBindRenderbuffer(c.GL_RENDERBUFFER, rbo);
            defer c.glBindRenderbuffer(c.GL_RENDERBUFFER, old_renderbuffer);

            c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH24_STENCIL8, 600, 400);
        }

        var fbo: c.GLuint = 0;
        c.glGenFramebuffers(1, &fbo);
        errdefer c.glDeleteFramebuffers(1, &fbo);

        {
            var old_framebuffer: c.GLuint = 0;
            c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, @ptrCast(&old_framebuffer));
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);
            defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, old_framebuffer);

            c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, textures[0], 0);
            c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_STENCIL_ATTACHMENT, c.GL_RENDERBUFFER, rbo);

            if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE)
                return error.OutOfMemory;
        }

        self.* = .{
            .idx = idx,
            .shader = shader,
            .textures = .{
                .{ .size = .{ .x = 600, .y = 400 }, .tex = textures[0], .buffer = &.{} },
                .{ .size = .{ .x = 600, .y = 400 }, .tex = textures[1], .buffer = &.{} },
            },
            .framebuffer = fbo,
            .renderbuffer = rbo,
            .arraybuffer = vab,
        };
    }

    return win.WindowContents.init(self, "vm", "VM Window", .{ .r = 1, .g = 1, .b = 1 });
}
