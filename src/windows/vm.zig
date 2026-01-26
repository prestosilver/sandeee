const std = @import("std");
const builtin = @import("builtin");
const glfw = @import("glfw");
const zgl = @import("zgl");

const Windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const Vm = system.Vm;
const files = system.files;

const DEFAULT_SIZE: Vec2 = .{ .x = 600, .y = 400 };

pub const VMData = struct {
    const Self = @This();

    texture: Texture,
    framebuffer: zgl.Framebuffer,
    renderbuffer: zgl.Renderbuffer,
    arraybuffer: zgl.Buffer,

    spritebatch: SpriteBatch,
    size: Vec2,

    font_shader: ?*Shader = null,
    font: ?*Font = null,

    idx: u8,
    shader: *Shader,

    total_counter: usize = 0,
    frame_counter: usize = 0,
    time: f32 = 0,
    fps: f32 = 0,
    debug: bool = false,
    input: []i32 = &.{},
    mousebtn: ?i32 = null,
    mousepos: Vec2 = .{},

    const VMDataKind = enum {
        rect,
        text,
    };

    const VMDataRect = struct {
        loc: Vec3,
        s: Sprite,
    };

    const VMDataText = struct {
        pos: Vec2,
        text: []const u8,
    };

    const VMDataEntry = union(VMDataKind) {
        rect: VMDataRect,
        text: VMDataText,
    };

    pub fn addRect(self: *VMData, texture: []const u8, src: Rect, dst: Rect) !void {
        try self.spritebatch.draw(
            Sprite,
            &.atlas(texture, .{
                .source = src,
                .size = .{ .x = dst.w, .y = dst.h },
            }),
            self.shader,
            .{ .x = dst.x, .y = dst.y },
        );
    }

    pub fn addText(self: *VMData, dst: Vec2, text: []const u8) !void {
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
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            if (self.texture.size.x != self.size.x or
                self.texture.size.y != self.size.y)
            {
                const old_renderbuffer: zgl.Renderbuffer = @enumFromInt(zgl.getInteger(.renderbuffer_binding));
                defer old_renderbuffer.bind(.buffer);

                self.renderbuffer.bind(.buffer);
                self.renderbuffer.storage(.buffer, .depth_stencil, @intFromFloat(self.size.x), @intFromFloat(self.size.y));

                self.texture.tex.bind(.@"2d");
                zgl.textureImage2D(.@"2d", 0, .rgba, @intFromFloat(self.size.x), @intFromFloat(self.size.y), .rgba, .unsigned_byte, null);

                self.texture.size = self.size;
            }

            const old_framebuffer: zgl.Framebuffer = @enumFromInt(zgl.getInteger(.draw_framebuffer_binding));
            defer old_framebuffer.bind(.buffer);

            self.framebuffer.bind(.buffer);

            const old_size = graphics.Context.instance.size;
            defer graphics.Context.resize(@intFromFloat(old_size.x), @intFromFloat(old_size.y));

            graphics.Context.resize(@intFromFloat(self.size.x), @intFromFloat(self.size.y));

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
            .clear = std.mem.zeroes(Color),
        });
    }

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, _: *Window.Data.WindowContents.WindowProps) !void {
        self.font_shader = font_shader;
        self.font = font;

        try SpriteBatch.global.draw(Sprite, &.override(self.texture, .{
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
                const val = try std.fmt.allocPrint(allocator, "BNDS: {}x{}+{}+{}", .{
                    @as(i32, @intFromFloat(bnds.w)),
                    @as(i32, @intFromFloat(bnds.h)),
                    @as(i32, @intFromFloat(bnds.x)),
                    @as(i32, @intFromFloat(bnds.y)),
                });
                defer allocator.free(val);

                try font.draw(.{
                    .shader = font_shader,
                    .text = val,
                    .pos = .{ .x = bnds.x, .y = bnds.y + y },
                });

                y += font.size;
            }

            {
                const val = try std.fmt.allocPrint(allocator, "FRAME: {}", .{self.total_counter});
                defer allocator.free(val);

                try font.draw(.{
                    .shader = font_shader,
                    .text = val,
                    .pos = .{ .x = bnds.x, .y = bnds.y + y },
                });

                y += font.size;
            }

            {
                const val = try std.fmt.allocPrint(allocator, "FPS: {}", .{@as(i32, @intFromFloat(self.fps))});
                defer allocator.free(val);

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
            defer allocator.free(old_input);

            self.input = try allocator.alloc(i32, std.mem.replacementSize(i32, self.input, &.{keycode}, &.{}));
            _ = std.mem.replace(i32, old_input, &.{keycode}, &.{}, self.input);

            return;
        }

        self.input = try allocator.realloc(self.input, self.input.len + 1);
        self.input[self.input.len - 1] = keycode;

        if (keycode == glfw.KeyF10) {
            self.debug = !self.debug;
        }
    }

    pub fn click(self: *Self, _: Vec2, pos: Vec2, btn: i32, kind: events.input.ClickKind) !void {
        if (kind == .down)
            self.mousebtn = btn
        else if (kind == .up)
            self.mousebtn = null;

        self.mousepos = pos;
    }

    pub fn move(self: *Self, x: f32, y: f32) !void {
        self.mousepos = .{ .x = x, .y = y };
    }

    pub fn deinit(self: *Self) void {
        allocator.free(self.input);

        self.spritebatch.deinit();
        self.texture.deinit();

        {
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            self.framebuffer.delete();
            self.renderbuffer.delete();
            self.arraybuffer.delete();
        }

        allocator.destroy(self);
    }
};

pub fn init(idx: u8, shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(VMData);

    {
        graphics.Context.makeCurrent();
        defer graphics.Context.makeNotCurrent();

        const texture: zgl.Texture = zgl.genTexture();
        errdefer texture.delete();

        texture.bind(.@"2d");
        texture.parameter(.min_filter, .nearest);
        texture.parameter(.mag_filter, .nearest);

        zgl.textureImage2D(.@"2d", 0, .rgba, DEFAULT_SIZE.x, DEFAULT_SIZE.y, .rgba, .unsigned_byte, null);

        const vab = zgl.genBuffer();
        errdefer vab.delete();

        const rbo = zgl.genRenderbuffer();
        errdefer rbo.delete();

        {
            const old_renderbuffer: zgl.Renderbuffer = @enumFromInt(zgl.getInteger(.renderbuffer_binding));
            defer old_renderbuffer.bind(.buffer);

            rbo.storage(.buffer, .depth_stencil, DEFAULT_SIZE.x, DEFAULT_SIZE.y);
        }

        const fbo = zgl.genFramebuffer();
        errdefer fbo.delete();

        {
            const old_framebuffer: zgl.Framebuffer = @enumFromInt(zgl.getInteger(.draw_framebuffer_binding));
            defer old_framebuffer.bind(.buffer);

            fbo.texture2D(.buffer, .color0, .@"2d", texture, 0);
            fbo.renderbuffer(.buffer, .depth_stencil, .buffer, rbo);

            if (zgl.checkFramebufferStatus(.buffer) != .complete)
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

    return Window.Data.WindowContents.init(self, "vm", "VM Window", .{ .r = 1, .g = 1, .b = 1 });
}
