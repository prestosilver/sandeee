const std = @import("std");
const builtin = @import("builtin");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const tex = @import("../util/texture.zig");
const shd = @import("../util/shader.zig");
const fnt = @import("../util/font.zig");
const spr = @import("../drawers/sprite2d.zig");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../util/graphics.zig");
const vm = @import("../system/vm.zig");
const c = @import("../c.zig");
const va = @import("../util/vertArray.zig");

const SpriteBatch = @import("../util/spritebatch.zig");
const TextureManager = @import("../util/texmanager.zig");

const DEFAULT_SIZE: vecs.Vector2 = .{ .x = 600, .y = 400 };

pub const VMData = struct {
    const Self = @This();

    //rects: [2]std.ArrayList(VMDataEntry),
    texture: tex.Texture,
    framebuffer: c.GLuint,
    renderbuffer: c.GLuint,
    arraybuffer: c.GLuint,

    spritebatch: SpriteBatch,
    size: vecs.Vector2,

    font_shader: ?*shd.Shader = null,
    font: ?*fnt.Font = null,

    idx: u8,
    shader: *shd.Shader,

    total_counter: usize = 0,
    frame_counter: usize = 0,
    time: f32 = 0,
    fps: f32 = 0,
    debug: bool = @import("builtin").mode == .Debug,
    input: []i32 = &.{},
    mousebtn: ?i32 = null,
    mousepos: vecs.Vector2 = .{},

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
        try self.spritebatch.draw(
            spr.Sprite,
            &.atlas(texture, .{
                .source = src,
                .size = .{ .x = dst.w, .y = dst.h },
            }),
            self.shader,
            .{ .x = dst.x, .y = dst.y },
        );
    }

    pub fn addText(self: *VMData, dst: vecs.Vector2, text: []const u8) !void {
        if (self.font == null or self.font_shader == null)
            return;

        try self.font.?.draw(
            .{
                .batch = &self.spritebatch,
                .shader = self.font_shader.?,
                .pos = dst,
                .text = text,
            },
        );
    }

    pub fn flip(self: *VMData) !void {
        {
            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            if (self.texture.size.x != self.size.x or
                self.texture.size.y != self.size.y)
            {
                var old_renderbuffer: c.GLuint = 0;
                c.glGetIntegerv(c.GL_RENDERBUFFER_BINDING, @ptrCast(&old_renderbuffer));
                c.glBindRenderbuffer(c.GL_RENDERBUFFER, self.renderbuffer);
                defer c.glBindRenderbuffer(c.GL_RENDERBUFFER, old_renderbuffer);

                c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH24_STENCIL8, @intFromFloat(self.size.x), @intFromFloat(self.size.y));

                c.glBindTexture(c.GL_TEXTURE_2D, self.texture.tex);
                c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intFromFloat(self.size.x), @intFromFloat(self.size.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

                self.texture.size = self.size;
            }

            var old_framebuffer: c.GLuint = 0;
            c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, @ptrCast(&old_framebuffer));
            defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, old_framebuffer);
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.framebuffer);

            const old_size = gfx.Context.instance.size;
            defer gfx.Context.resize(@intFromFloat(old_size.x), @intFromFloat(old_size.y));

            gfx.Context.resize(@intFromFloat(self.size.x), @intFromFloat(self.size.y));

            try self.spritebatch.render();
        }

        self.frame_counter +%= 1;
        self.total_counter +%= 1;
    }

    pub fn clear(self: *VMData) !void {
        try self.spritebatch.addEntry(&.{
            .texture = .none,
            .verts = .none,
            .shader = self.shader.*,
            .clear = std.mem.zeroes(col.Color),
        });
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, _: *win.WindowContents.WindowProps) !void {
        self.font_shader = font_shader;
        self.font = font;

        try SpriteBatch.global.draw(spr.Sprite, &.override(self.texture, .{
            .source = .{ .y = 1, .w = 1, .h = -1 },
            .size = .{ .x = bnds.w, .y = bnds.h },
        }), self.shader, .{ .x = bnds.x, .y = bnds.y });

        self.size = .{ .x = bnds.w, .y = bnds.h };

        self.time += 1.0 / 60.0;
        if (self.time > 1.0) {
            self.fps = @as(f32, @floatFromInt(self.frame_counter)) / self.time;
            self.frame_counter = 0;
            self.time = 0;
        }

        if (self.debug) {
            var y: f32 = 0;

            {
                const val = try std.fmt.allocPrint(allocator.alloc, "BNDS: {}x{}+{}+{}", .{
                    @as(i32, @intFromFloat(bnds.w)),
                    @as(i32, @intFromFloat(bnds.h)),
                    @as(i32, @intFromFloat(bnds.x)),
                    @as(i32, @intFromFloat(bnds.y)),
                });
                defer allocator.alloc.free(val);

                try font.draw(.{
                    .shader = font_shader,
                    .text = val,
                    .pos = .{ .x = bnds.x, .y = bnds.y + y },
                });

                y += font.size;
            }

            {
                const val = try std.fmt.allocPrint(allocator.alloc, "FRAME: {}", .{self.total_counter});
                defer allocator.alloc.free(val);

                try font.draw(.{
                    .shader = font_shader,
                    .text = val,
                    .pos = .{ .x = bnds.x, .y = bnds.y + y },
                });

                y += font.size;
            }

            {
                const val = try std.fmt.allocPrint(allocator.alloc, "FPS: {}", .{@as(i32, @intFromFloat(self.fps))});
                defer allocator.alloc.free(val);

                try font.draw(.{
                    .shader = font_shader,
                    .text = val,
                    .pos = .{ .x = bnds.x, .y = bnds.y + y },
                });

                y += font.size;
            }
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

        self.spritebatch.deinit();
        self.texture.deinit();

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

        var texture: c.GLuint = 0;
        c.glGenTextures(1, &texture);
        errdefer c.glDeleteTextures(1, &texture);

        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, DEFAULT_SIZE.x, DEFAULT_SIZE.y, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

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

            c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH24_STENCIL8, DEFAULT_SIZE.x, DEFAULT_SIZE.y);
        }

        var fbo: c.GLuint = 0;
        c.glGenFramebuffers(1, &fbo);
        errdefer c.glDeleteFramebuffers(1, &fbo);

        {
            var old_framebuffer: c.GLuint = 0;
            c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, @ptrCast(&old_framebuffer));
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);
            defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, old_framebuffer);

            c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, texture, 0);
            c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_STENCIL_ATTACHMENT, c.GL_RENDERBUFFER, rbo);

            if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE)
                return error.OutOfMemory;
        }

        self.* = .{
            .idx = idx,
            .shader = shader,
            .size = DEFAULT_SIZE,
            .spritebatch = .{ .size = &self.texture.size },
            .texture = .{ .size = DEFAULT_SIZE, .tex = texture, .buffer = &.{} },
            .framebuffer = fbo,
            .renderbuffer = rbo,
            .arraybuffer = vab,
        };
    }

    return win.WindowContents.init(self, "vm", "VM Window", .{ .r = 1, .g = 1, .b = 1 });
}
