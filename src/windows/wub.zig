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
    icon: sprite.Sprite,
    divx: sprite.Sprite,
    divy: sprite.Sprite,
    shader: shd.Shader,
};

pub fn drawWeb(c: *[]u8, batch: *sb.SpriteBatch, font_shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*WebData, c);

    self.divy.data.size.y = bnds.h + 4;

    batch.draw(sprite.Sprite, &self.divy, self.shader, vecs.newVec3(bnds.x + 100, bnds.y - 2, 0));

    self.divx.data.size.x = 104;

    batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 100, 0));

    batch.draw(sprite.Sprite, &self.icon, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

    font.draw(batch, font_shader, "Inbox", vecs.newVec2(bnds.x + 6, bnds.y + 106), col.newColor(0, 0, 0, 1));
}

pub fn new(texture: tex.Texture, shader: shd.Shader) win.WindowContents {
    const self = allocator.alloc.alloc(WebData, 1) catch &[0]WebData{};

    self[0].text = "Web";
    self[0].divy = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0, 3.0 / 32.0, 3.0 / 32.0, 29.0 / 32.0),
        vecs.newVec2(6, 100),
    ));
    self[0].divx = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(3.0 / 32.0, 0, 29.0 / 32.0, 3.0 / 32.0),
        vecs.newVec2(100, 6),
    ));
    self[0].icon = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(3.0 / 32.0, 3.0 / 32.0, 13.0 / 32.0, 13.0 / 32.0),
        vecs.newVec2(100, 100),
    ));
    self[0].shader = shader;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, &self[0]),
        .drawFn = drawWeb,
        .name = "The Wub",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
