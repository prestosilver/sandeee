const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../texture.zig");

const WebData = struct {
    shader: shd.Shader,
    lol: u64 = 0,
};

pub fn drawWeb(c: *[]u8, batch: *sb.SpriteBatch, font_shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    _ = @ptrCast(*WebData, c);

    font.draw(batch, font_shader, "WOAH WIKIPEDIA?", vecs.newVec2(bnds.x + 6, bnds.y + 6), col.newColor(0, 0, 0, 1));
}

fn deleteWeb(cself: *[]u8) void {
    var self = @ptrCast(*WebData, cself);
    allocator.alloc.destroy(self);
}

pub fn new(_: tex.Texture, shader: shd.Shader) win.WindowContents {
    var self = allocator.alloc.create(WebData) catch undefined;


    self.shader = shader;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .deleteFn = deleteWeb,
        .drawFn = drawWeb,
        .name = "Xplorer",
        .clearColor = col.newColor(0.75, 0.75, 0.75, 1),
    };
}
