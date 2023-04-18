const std = @import("std");
const builtin = @import("builtin");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const tex = @import("../util/texture.zig");
const sb = @import("../util/spritebatch.zig");
const shd = @import("../util/shader.zig");
const fnt = @import("../util/font.zig");
const spr = @import("../drawers/sprite2d.zig");
const allocator = @import("../util/allocator.zig");
const c = @import("../c.zig");

pub const VMData = struct {
    const Self = @This();

    rects: [2]std.ArrayList(VMDataEntry),
    idx: u8,
    shader: *shd.Shader,

    back: bool = true,
    frameCounter: f32 = 0,
    time: f32 = 0,
    fps: f32 = 0,
    debug: bool = builtin.mode == .Debug,

    const VMDataEntry = struct {
        loc: vecs.Vector3,
        s: spr.Sprite,
    };

    pub fn addRect(self: *VMData, texture: *tex.Texture, src: rect.Rectangle, dst: rect.Rectangle) !void {
        var appends: VMDataEntry = .{
            .loc = vecs.newVec3(dst.x, dst.y, 0),
            .s = spr.Sprite{
                .texture = texture,
                .data = spr.SpriteData.new(src, vecs.newVec2(dst.w, dst.h)),
            },
        };

        if (self.back) try self.rects[0].append(appends);
        if (!self.back) try self.rects[1].append(appends);
    }

    pub fn flip(self: *VMData) void {
        self.frameCounter += 1;
        self.back = !self.back;
        self.clear();
    }

    pub fn clear(self: *VMData) void {
        var rects = &self.rects[0];
        if (!self.back) rects = &self.rects[1];
        rects.*.clearAndFree();
    }

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;
        var rects = self.rects[0];
        if (self.back) rects = self.rects[1];

        for (rects.items, 0..) |_, idx| {
            try batch.draw(spr.Sprite, &rects.items[idx].s, self.shader, vecs.newVec3(bnds.x, bnds.y, 0).add(rects.items[idx].loc));
        }

        self.time += 1.0 / 60.0;
        if (self.time > 1.0) {
            self.fps = self.frameCounter / self.time;
            self.frameCounter = 0;
            self.time = 0;
        }

        if (self.debug) {
            var val = try std.fmt.allocPrint(allocator.alloc, "FPS: {}", .{@floatToInt(i32, self.fps)});
            defer allocator.alloc.free(val);

            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = val,
                .pos = bnds.location(),
            });
        }
    }

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        _ = mods;
        _ = code;
        _ = self;
    }

    pub fn key(self: *Self, keycode: i32, _: i32) !void {
        if (keycode == c.GLFW_KEY_F1) {
            self.debug = !self.debug;
        }
    }
    pub fn click(_: *Self, _: vecs.Vector2, _: vecs.Vector2, _: i32) !void {}
    pub fn scroll(_: *Self, _: f32, _: f32) !void {}
    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}

    pub fn deinit(self: *Self) void {
        self.rects[0].deinit();
        self.rects[1].deinit();

        allocator.alloc.destroy(self);
    }
};

pub fn new(idx: u8, shader: *shd.Shader) !win.WindowContents {
    var self = try allocator.alloc.create(VMData);

    self.* = .{
        .idx = idx,
        .shader = shader,
        .rects = .{
            std.ArrayList(VMData.VMDataEntry).init(allocator.alloc),
            std.ArrayList(VMData.VMDataEntry).init(allocator.alloc),
        },
    };

    return win.WindowContents.init(self, "vm", "VM Window", col.newColor(1, 1, 1, 1));
}
