const std = @import("std");

const qoi = @import("qoi");
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
const cc = @import("../c.zig");

const PixData = struct {
    file: ?*files.File,
};

pub fn drawPix(c: *[]u8, batch: *sb.SpriteBatch, _: shd.Shader, bnds: *rect.Rectangle, _: *fnt.Font) void {
    var self = @ptrCast(*PixData, c);

    _ = bnds;
    _ = self;
}

pub fn clickPix(c: *[]u8, _: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) bool {
    var self = @ptrCast(*PixData, c);
    switch (btn) {
        0 => {
            var open = rect.newRect(0, 0, 32, 32);
            if (open.contains(mousepos)) {
                std.log.info("open", .{});
            }
            var save = rect.newRect(32, 0, 32, 32);
            if (save.contains(mousepos)) {
                if (self.file != null) {
                    allocator.alloc.free(self.file.?.contents);
                    var buff = allocator.alloc.alloc(u8, self.buffer.items.len) catch {
                        return true;
                    };
                    std.mem.copy(u8, buff, self.buffer.items);
                    self.file.?.contents = buff;
                    std.log.info("saved", .{});
                    self.modified = false;
                }
            }
        },
        else => {},
    }

    return true;
}

fn focusPix(c: *[]u8) void {
    var self = @ptrCast(*PixData, c);
    if (!self.modified) {
        self.buffer.clearAndFree();
        self.buffer.appendSlice(self.file.?.contents) catch {};
        return;
    }
}

fn deletePix(cself: *[]u8) void {
    var self = @ptrCast(*PixData, cself);
    self.buffer.deinit();
    allocator.alloc.destroy(self);
}

pub fn keyPix(cself: *[]u8, key: i32, mods: i32) void {
    var self = @ptrCast(*PixData, cself);

    switch (key) {
        cc.GLFW_KEY_A...cc.GLFW_KEY_Z => {
            if ((mods & cc.GLFW_MOD_SHIFT) != 0) {
                self.buffer.insert(self.cursorIdx, @intCast(u8, key - cc.GLFW_KEY_A) + 'A') catch {};
            } else {
                self.buffer.insert(self.cursorIdx, @intCast(u8, key - cc.GLFW_KEY_A) + 'a') catch {};
            }
            self.cursor.x += 1;
            self.modified = true;
        },
        cc.GLFW_KEY_0...cc.GLFW_KEY_9 => {
            if ((mods & cc.GLFW_MOD_SHIFT) != 0) {
                self.buffer.insert(self.cursorIdx, ")!@#$%^&*("[@intCast(u8, key - cc.GLFW_KEY_0)]) catch {};
            } else {
                self.buffer.insert(self.cursorIdx, @intCast(u8, key - cc.GLFW_KEY_0) + '0') catch {};
            }
            self.cursor.x += 1;
            self.modified = true;
        },
        cc.GLFW_KEY_ENTER => {
            self.buffer.insert(self.cursorIdx, '\n') catch {};
            self.cursor.x = 0;
            self.cursor.y += 1;
            self.modified = true;
        },
        cc.GLFW_KEY_COMMA => {
            self.buffer.insert(self.cursorIdx, ',') catch {};
            self.cursor.x += 1;
            self.modified = true;
        },
        cc.GLFW_KEY_PERIOD => {
            self.buffer.insert(self.cursorIdx, '.') catch {};
            self.cursor.x += 1;
            self.modified = true;
        },
        cc.GLFW_KEY_SPACE => {
            self.buffer.insert(self.cursorIdx, ' ') catch {};
            self.cursor.x += 1;
            self.modified = true;
        },
        cc.GLFW_KEY_DELETE => {
            if (self.cursorIdx < self.buffer.items.len) {
                _ = self.buffer.orderedRemove(self.cursorIdx);
            }
            self.modified = true;
        },
        cc.GLFW_KEY_BACKSPACE => {
            if (self.cursorIdx > 0) {
                var char = self.buffer.orderedRemove(self.cursorIdx - 1);
                self.cursor.x -= 1;
                if (char == '\n') {
                    self.cursor.y -= 1;
                    self.cursor.x = @intToFloat(f32, self.prevIdx);
                }
            }
            self.modified = true;
        },
        cc.GLFW_KEY_LEFT => {
            self.cursor.x -= 1;
        },
        cc.GLFW_KEY_RIGHT => {
            self.cursor.x += 1;
        },
        cc.GLFW_KEY_UP => {
            self.cursor.y -= 1;
        },
        cc.GLFW_KEY_DOWN => {
            self.cursor.y += 1;
        },
        else => {},
    }
}

pub fn new(texture: tex.Texture, shader: shd.Shader) win.WindowContents {
    const self = allocator.alloc.create(PixData) catch undefined;

    self.menuTop = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(19.0 / 32.0, 0.0 / 32.0, 13.0 / 32.0, 2.0 / 32.0),
        vecs.newVec2(100, 36),
    ));
    self.menuDiv = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(19.0 / 32.0, 2.0 / 32.0, 13.0 / 32.0, 1.0 / 32.0),
        vecs.newVec2(100, 2),
    ));
    self.numLeft = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(16.0 / 32.0, 3.0 / 32.0, 2.0 / 32.0, 13.0 / 32.0),
        vecs.newVec2(64, 100),
    ));
    self.numDiv = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(18.0 / 32.0, 3.0 / 32.0, 1.0 / 32.0, 13.0 / 32.0),
        vecs.newVec2(2, 100),
    ));
    self.icons[0] = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(0, 0, 16.0 / 32.0, 16.0 / 32.0),
        vecs.newVec2(32, 32),
    ));
    self.icons[1] = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(0, 16.0 / 32.0, 16.0 / 32.0, 16.0 / 32.0),
        vecs.newVec2(32, 32),
    ));
    self.shader = shader;
    self.file = &files.root.contents.items[0];
    self.buffer = std.ArrayList(u8).init(allocator.alloc);
    self.buffer.appendSlice(self.file.?.contents) catch {};
    self.cursor.x = 0;
    self.cursor.y = 0;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .drawFn = drawPix,
        .clickFn = clickPix,
        .keyFn = keyPix,
        .deleteFn = deletePix,
        .focusFn = focusPix,
        .name = "EEEDT",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
