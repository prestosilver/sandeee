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
    input: []i32,
    mousebtn: ?i32 = null,
    mousepos: vecs.Vector2 = vecs.newVec2(0, 0),

    const VMDataKind = enum {
        Rect,
        Text,
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
        Rect: VMDataRect,
        Text: VMDataText,
    };

    pub fn addRect(self: *VMData, texture: []const u8, src: rect.Rectangle, dst: rect.Rectangle) !void {
        var appends: VMDataEntry = .{
            .Rect = .{
                .loc = vecs.newVec3(dst.x, dst.y, 0),
                .s = spr.Sprite{
                    .texture = try allocator.alloc.dupe(u8, texture),
                    .data = spr.SpriteData.new(src, vecs.newVec2(dst.w, dst.h)),
                },
            },
        };

        if (self.back) try self.rects[0].append(appends);
        if (!self.back) try self.rects[1].append(appends);
    }

    pub fn addText(self: *VMData, dst: vecs.Vector2, text: []const u8) !void {
        var appends: VMDataEntry = .{
            .Text = .{
                .pos = dst,
                .text = try allocator.alloc.dupe(u8, text),
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
        for (rects.items) |item| {
            switch (item) {
                .Text => {
                    allocator.alloc.free(item.Text.text);
                },
                .Rect => {
                    allocator.alloc.free(item.Rect.s.texture);
                },
            }
        }

        rects.*.clearAndFree();
    }

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;
        var rects = self.rects[0];
        if (self.back) rects = self.rects[1];

        for (rects.items, 0..) |_, idx| {
            switch (rects.items[idx]) {
                .Rect => {
                    try batch.draw(spr.Sprite, &rects.items[idx].Rect.s, self.shader, vecs.newVec3(bnds.x, bnds.y, 0).add(rects.items[idx].Rect.loc));
                },
                .Text => {
                    try font.draw(
                        .{
                            .batch = batch,
                            .shader = font_shader,
                            .pos = rects.items[idx].Text.pos.add(bnds.location()),
                            .text = rects.items[idx].Text.text,
                        },
                    );
                },
            }
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
        _ = code;
        _ = self;
        _ = mods;
        // self.input = code;
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (!down) {
            var newInput = try allocator.alloc.alloc(i32, std.mem.replacementSize(i32, self.input, &.{keycode}, &.{}));
            _ = std.mem.replace(i32, self.input, &.{keycode}, &.{}, newInput);
            allocator.alloc.free(self.input);
            self.input = newInput;

            return;
        }

        self.input = try allocator.alloc.realloc(self.input, self.input.len + 1);
        self.input[self.input.len - 1] = keycode;

        if (keycode == c.GLFW_KEY_F1) {
            self.debug = !self.debug;
        }
    }

    pub fn click(self: *Self, pos: vecs.Vector2, _: vecs.Vector2, btn: i32) !void {
        self.mousebtn = btn;
        self.mousepos = pos;
    }

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
        .input = try allocator.alloc.alloc(i32, 0),
    };

    return win.WindowContents.init(self, "vm", "VM Window", col.newColor(1, 1, 1, 1));
}
