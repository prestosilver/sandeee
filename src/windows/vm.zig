const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const tex = @import("../texture.zig");
const sb = @import("../spritebatch.zig");
const shd = @import("../shader.zig");
const fnt = @import("../util/font.zig");
const spr = @import("../drawers/sprite2d.zig");
const allocator = @import("../util/allocator.zig");

pub const VMData = struct {
    const VMDataEntry = struct {
        loc: vecs.Vector3,
        s: spr.Sprite,
    };

    pub fn addRect(self: *VMData, texture: tex.Texture, src: rect.Rectangle, dst: rect.Rectangle) void {
        var appends: VMDataEntry = .{
            .loc = vecs.newVec3(dst.x, dst.y, 0),
            .s = spr.Sprite{
                .texture = texture,
                .data = spr.SpriteData.new(src, vecs.newVec2(dst.w, dst.h)),
            }
        };
        self.rects.append(appends) catch {};
    }

    rects: std.ArrayList(VMDataEntry),
    idx: u16,
    shd: *shd.Shader,
};

fn drawVM(c: *[]u8, batch: *sb.SpriteBatch, _: shd.Shader, bnds: *rect.Rectangle, _: *fnt.Font) void {
    var self = @ptrCast(*VMData, c);

    for (self.rects.items) |_, idx| {
        batch.draw(spr.Sprite, &self.rects.items[idx].s, self.shd.*, vecs.newVec3(bnds.x, bnds.y, 0).add(self.rects.items[idx].loc));
    }
}

fn deleteVM(cself: *[]u8) void {
    var self = @ptrCast(*VMData, cself);

    self.rects.deinit();

    allocator.alloc.destroy(self);
}

pub fn new(idx: u16, shader: *shd.Shader) win.WindowContents {
    var self = allocator.alloc.create(VMData) catch undefined;

    self.idx = idx;
    self.shd = shader;
    self.rects = std.ArrayList(VMData.VMDataEntry).init(allocator.alloc);

    return win.WindowContents{
        .self = @ptrCast(*[]u8, @alignCast(8, self)),
        .deleteFn = deleteVM,
        .drawFn = drawVM,
        .name = "VM Window",
        .kind = "vm",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
