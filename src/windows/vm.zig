const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const tex = @import("../texture.zig");
const sb = @import("../spritebatch.zig");
const shd = @import("../shader.zig");
const fnt = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");

pub const VMData = struct{
    tex: tex.Texture,
    idx: u16,
};

fn drawVM(c: *[]u8, batch: *sb.SpriteBatch, font_shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*VMData, c);

    _ = self;
    _ = batch;
    _ = font_shader;
    _ = bnds;
    _ = font;
}

fn deleteVM(cself: *[]u8) void {
    var self = @ptrCast(*VMData, cself);
    allocator.alloc.destroy(self);
}

pub fn new(idx: u16) win.WindowContents {
    var self = allocator.alloc.create(VMData) catch undefined;

    self.idx = idx;
    self.tex = tex.newTextureSize(vecs.newVec2(32, 32));

    return win.WindowContents{
        .self = @ptrCast(*[]u8, @alignCast(8, self)),
        .deleteFn = deleteVM,
        .drawFn = drawVM,
        .name = "VM Window",
        .kind = "vm",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
