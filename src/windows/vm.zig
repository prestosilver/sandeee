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

const WindowId = u8;

pub const VMData = struct {
    const Self = @This();

    pub var used_ids = [_]?*VMData{null} ** std.math.maxInt(WindowId);
    var last_id: WindowId = 0;

    texture: Texture,
    framebuffer: zgl.Framebuffer,
    renderbuffer: zgl.Renderbuffer,
    arraybuffer: zgl.Buffer,

    spritebatch: SpriteBatch,
    size: Vec2,

    font_shader: ?*Shader = null,
    font: ?*Font = null,

    id: WindowId,
    shader: *Shader,

    total_counter: usize = 0,
    frame_counter: usize = 0,
    time: f32 = 0,
    fps: f32 = 0,
    debug: bool = false,
    input: std.array_list.Managed(i32) = .init(allocator),
    mousebtn: ?i32 = null,
    mousepos: Vec2 = .{},

    tags: struct {
        should_close: bool = false,
        title_ptr: ?*[]const u8 = null,
        set_title: ?[]const u8 = null,
        pos: ?Vec2 = null,
        size: ?Vec2 = null,
        min_size: ?Vec2 = null,
        max_size: ?Vec2 = null,
        color: ?Color = null,
    } = .{},

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

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        props.close = self.tags.should_close;
        self.tags.title_ptr = &props.info.name;

        if (self.tags.set_title) |title_value| {
            try props.setTitle(title_value);
            allocator.free(title_value);

            self.tags.set_title = null;
        }

        if (self.tags.pos) |target_pos| {
            bnds.x = target_pos.x;
            bnds.y = target_pos.y;

            self.tags.pos = null;
        }

        if (self.tags.size) |target_size| {
            bnds.w = target_size.x;
            bnds.h = target_size.y;

            self.tags.size = null;
        }

        if (self.tags.min_size) |target_min_size| {
            props.size.min = target_min_size;

            self.tags.min_size = null;
        }

        if (self.tags.max_size) |target_max_size| {
            props.size.max = target_max_size;

            self.tags.max_size = null;
        }

        if (self.tags.color) |target_color| {
            props.clear_color = target_color;

            self.tags.color = null;
        }

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
            const len = std.mem.replacementSize(i32, self.input.items, &.{keycode}, &.{});
            _ = std.mem.replace(i32, self.input.items, &.{keycode}, &.{}, self.input.items);
            self.input.shrinkRetainingCapacity(len);

            return;
        }

        try self.input.append(keycode);

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
        VMData.used_ids[self.id] = null;

        self.input.deinit();
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

pub fn init(shader: *Shader) !Window.Data.WindowContents {
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

        if (VMData.used_ids[VMData.last_id +% 1] != null)
            return error.WindowLimitReached;

        VMData.last_id +%= 1;

        VMData.used_ids[VMData.last_id] = self;

        self.* = .{
            .id = VMData.last_id,
            .shader = shader,
            .size = DEFAULT_SIZE,
            .spritebatch = .{ .size = &self.texture.size },
            .texture = .{ .size = DEFAULT_SIZE, .tex = texture, .buffer = &.{} },
            .framebuffer = fbo,
            .renderbuffer = rbo,
            .arraybuffer = vab,
        };
    }

    return .init(self, "vm", "VM Window", .{ .r = 1, .g = 1, .b = 1 });
}
