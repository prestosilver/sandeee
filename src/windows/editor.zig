const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../spritebatch.zig");
const tex = @import("../texture.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../shader.zig");
const sp = @import("../drawers/sprite2d.zig");

const EditorData = struct {
    file: ?*files.File,
    menuTop: sp.Sprite,
    menuDiv: sp.Sprite,
    shader: shd.Shader,
    numLeft: sp.Sprite,
    numDiv: sp.Sprite,
    icons: [1]sp.Sprite,
};

pub fn drawEditor(c: *[]u8, batch: *sb.SpriteBatch, shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*EditorData, c);

    self.menuTop.data.size.x = bnds.w + 4;
    self.menuDiv.data.size.x = bnds.w + 4;

    self.numLeft.data.size.y = bnds.h - 36;
    self.numDiv.data.size.y = bnds.h - 36;

    batch.draw(sp.Sprite, &self.menuTop, self.shader, vecs.newVec3(bnds.x - 2, bnds.y - 2, 0));
    batch.draw(sp.Sprite, &self.menuDiv, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 34, 0));
    batch.draw(sp.Sprite, &self.numLeft, self.shader, vecs.newVec3(bnds.x, bnds.y + 36, 0));
    batch.draw(sp.Sprite, &self.numDiv, self.shader, vecs.newVec3(bnds.x + 64, bnds.y + 36, 0));

    batch.draw(sp.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

    if (self.file == null) return;

    var y = bnds.y + 32;
    var line = std.ArrayList(u8).init(allocator.alloc);
    var nr: i32 = 1;
    defer line.deinit();

    for (self.file.?.contents) |char| {
        if (char == '\n') {
            font.draw(batch, shader, line.items, vecs.newVec2(bnds.x + 70, y), col.newColor(0, 0, 0, 1));
            var linenr = std.fmt.allocPrint(allocator.alloc, "{}", .{nr}) catch "";
            defer allocator.alloc.free(linenr);
            font.draw(batch, shader, linenr, vecs.newVec2(bnds.x + 6, y), col.newColor(0, 0, 0, 1));
            line.clearAndFree();
            y += font.size;
            nr += 1;
        } else {
            line.append(char) catch {};
        }
    }
    font.draw(batch, shader, line.items, vecs.newVec2(bnds.x + 70, y), col.newColor(0, 0, 0, 1));
    var linenr = std.fmt.allocPrint(allocator.alloc, "{}", .{nr}) catch "";
    defer allocator.alloc.free(linenr);
    font.draw(batch, shader, linenr, vecs.newVec2(bnds.x + 6, y), col.newColor(0, 0, 0, 1));
}

pub fn clickEditor(c: *[]u8, _: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) bool {
    _ = @ptrCast(*EditorData, c);
    _ = mousepos;
    switch (btn) {
        else => {},
    }

    return true;
}

fn deleteEditor(cself: *[]u8) void {
    var self = @ptrCast(*EditorData, cself);
    allocator.alloc.destroy(self);
}

pub fn new(texture: tex.Texture, shader: shd.Shader) win.WindowContents {
    const self = allocator.alloc.create(EditorData) catch undefined;

    self.menuTop = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(0, 0.0 / 32.0, 1.0, 2.0 / 32.0),
        vecs.newVec2(100, 36),
    ));
    self.menuDiv = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(0, 2.0 / 32.0, 1.0, 1.0 / 32.0),
        vecs.newVec2(100, 2),
    ));
    self.numLeft = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(16.0 / 32.0, 3.0 / 32.0, 2.0 / 32.0, 16.0 / 32.0),
        vecs.newVec2(64, 100),
    ));
    self.numDiv = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(18.0 / 32.0, 3.0 / 32.0, 1.0 / 32.0, 16.0 / 32.0),
        vecs.newVec2(2, 100),
    ));
    self.icons[0] = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(0, 3.0 / 32.0, 16.0 / 32.0, 16.0 / 32.0),
        vecs.newVec2(32, 32),
    ));
    self.shader = shader;
    self.file = &files.root.contents.items[0];

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .drawFn = drawEditor,
        .clickFn = clickEditor,
        .deleteFn = deleteEditor,
        .name = "EEEDT",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
