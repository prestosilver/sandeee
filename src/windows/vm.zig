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

    rects: [2]std.ArrayList(VMDataEntry),
    idx: u8,
    shader: *shd.Shader,

    back: bool = true,
    frame_counter: f32 = 0,
    time: f32 = 0,
    fps: f32 = 0,
    debug: bool = false,
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
        const appends: VMDataEntry = .{
            .rect = .{
                .loc = .{ .x = dst.x, .y = dst.y },
                .s = spr.Sprite{
                    .texture = try allocator.alloc.dupe(u8, texture),
                    .data = .{
                        .source = src,
                        .size = .{ .x = dst.w, .y = dst.h },
                    },
                },
            },
        };

        if (self.back) try self.rects[0].append(appends);
        if (!self.back) try self.rects[1].append(appends);
    }

    pub fn addText(self: *VMData, dst: vecs.Vector2, text: []const u8) !void {
        const appends: VMDataEntry = .{
            .text = .{
                .pos = dst,
                .text = try allocator.alloc.dupe(u8, text),
            },
        };

        if (self.back) try self.rects[0].append(appends);
        if (!self.back) try self.rects[1].append(appends);
    }

    pub fn flip(self: *VMData) void {
        self.frame_counter += 1;
        self.back = !self.back;
        self.clear();
    }

    pub fn clear(self: *VMData) void {
        const rects = if (!self.back) &self.rects[1] else &self.rects[0];
        for (rects.items) |item| {
            switch (item) {
                .text => {
                    allocator.alloc.free(item.text.text);
                },
                .rect => {
                    allocator.alloc.free(item.rect.s.texture);
                },
            }
        }

        rects.*.clearAndFree();
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, _: *win.WindowContents.WindowProps) !void {
        // vm.syslock.lock();
        // defer vm.syslock.unlock();

        const rects = if (self.back) self.rects[1] else self.rects[0];

        for (rects.items, 0..) |_, idx| {
            switch (rects.items[idx]) {
                .rect => {
                    try batch.SpriteBatch.instance.draw(spr.Sprite, &rects.items[idx].rect.s, self.shader, .{ .x = bnds.x + rects.items[idx].rect.loc.x, .y = bnds.y + rects.items[idx].rect.loc.y, .z = rects.items[idx].rect.loc.z });
                },
                .text => {
                    try font.draw(
                        .{
                            .shader = font_shader,
                            .pos = rects.items[idx].text.pos.add(bnds.location()),
                            .text = rects.items[idx].text.text,
                        },
                    );
                },
            }
        }

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
        self.flip();
        self.flip();

        self.rects[0].deinit();
        self.rects[1].deinit();

        allocator.alloc.free(self.input);

        allocator.alloc.destroy(self);
    }
};

pub fn init(idx: u8, shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(VMData);

    self.* = .{
        .idx = idx,
        .shader = shader,
        .rects = .{
            std.ArrayList(VMData.VMDataEntry).init(allocator.alloc),
            std.ArrayList(VMData.VMDataEntry).init(allocator.alloc),
        },
    };

    return win.WindowContents.init(self, "vm", "VM Window", .{ .r = 1, .g = 1, .b = 1 });
}
