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

const SettingPanel = struct {
    name: []const u8,
    icon: u8,
};

const SettingsData = struct {
    shader: shd.Shader,
    icons: [3]sprite.Sprite,
    scroll: [3]sprite.Sprite,
    focus: sprite.Sprite,
    focused: ?u64,

    const panels = [_]SettingPanel{
        SettingPanel{ .name = "Graphics", .icon = 1 },
        SettingPanel{ .name = "Sounds", .icon = 2 },
    };
};

pub fn drawSettings(c: *[]u8, batch: *sb.SpriteBatch, font_shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*SettingsData, c);

    self.scroll[1].data.size.y = bnds.h - 20;

    batch.draw(sprite.Sprite, &self.scroll[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y - 2, 0));
    batch.draw(sprite.Sprite, &self.scroll[1], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 10, 0));
    batch.draw(sprite.Sprite, &self.scroll[2], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + bnds.h - 10, 0));

    var x: f32 = 0;
    var y: f32 = 0;

    for (SettingsData.panels) |panel| {
        var size = font.sizeText(panel.name);
        var xo = (128 - size.x) / 2;

        font.draw(batch, font_shader, panel.name, vecs.newVec2(bnds.x + x + xo + 6, bnds.y + 64 + y + 6), col.newColor(0, 0, 0, 1));

        batch.draw(sprite.Sprite, &self.icons[panel.icon], self.shader, vecs.newVec3(bnds.x + x + 6 + 32, bnds.y + y + 6, 0));

        x += 128;
        if (x + 128 + 16 > bnds.w) {
            y += 64 + font.size;
            x = 0;
        }
    }
}

fn deleteSettings(cself: *[]u8) void {
    var self = @ptrCast(*SettingsData, cself);
    allocator.alloc.destroy(self);
}

pub fn new(texture: tex.Texture, shader: shd.Shader) win.WindowContents {
    var self = allocator.alloc.create(SettingsData) catch undefined;

    for (self.icons) |_, idx| {
        var i = @intToFloat(f32, idx);

        self.icons[idx] = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(0 / 32.0, i / @intToFloat(f32, self.icons.len), 1.0, 1.0 / @intToFloat(f32, self.icons.len)),
            vecs.newVec2(64, 64),
        ));
    }

    var ym = @intToFloat(f32, self.icons.len);

    self.scroll[0] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0 / 32.0, 0 / 32.0 / ym, 7.0 / 32.0, 6.0 / 32.0 / ym),
        vecs.newVec2(14.0, 12.0),
    ));

    self.scroll[1] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0 / 32.0, 6.0 / 32.0 / ym, 7.0 / 32.0, 4.0 / 32.0 / ym),
        vecs.newVec2(14.0, 64),
    ));

    self.scroll[2] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0 / 32.0, 10.0 / 32.0 / ym, 7.0 / 32.0, 6.0 / 32.0 / ym),
        vecs.newVec2(14.0, 12.0),
    ));

    self.shader = shader;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .deleteFn = deleteSettings,
        .drawFn = drawSettings,
        .name = "Settings",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
