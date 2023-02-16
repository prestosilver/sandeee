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
const cc = @import("../c.zig");

pub const EditorData = struct {
    file: ?*files.File,
    buffer: std.ArrayList(u8),
    menuTop: sp.Sprite,
    menuDiv: sp.Sprite,
    shader: shd.Shader,
    numLeft: sp.Sprite,
    numDiv: sp.Sprite,
    icons: [2]sp.Sprite,
    cursor: vecs.Vector2,
    cursorIdx: usize,
    prevIdx: usize,
    modified: bool,

    clickPos: ?vecs.Vector2,
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

    batch.draw(sp.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 34, bnds.y, 0));
    batch.draw(sp.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

    if (self.file == null) return;

    var y = bnds.y + 32;
    var line = std.ArrayList(u8).init(allocator.alloc);
    var nr: i32 = 1;
    defer line.deinit();

    var cx: f32 = 0;
    var cy: f32 = 0;

    for (self.buffer.items) |char, idx| {
        if (char == '\n') {
            if (cy == self.cursor.y and cx <= self.cursor.x) {
                var size = font.sizeText(line.items);
                self.cursor.x = cx;

                font.draw(batch, shader, "|", vecs.newVec2(bnds.x + 64 + size.x, y), col.newColor(0, 0, 0, 1));
                self.cursorIdx = idx;
            } else if (self.cursor.x <= 0 and self.cursor.y == cy) {
                self.cursor.x = 0;

                font.draw(batch, shader, "|", vecs.newVec2(bnds.x + 64, y), col.newColor(0, 0, 0, 1));
                self.cursorIdx = idx - line.items.len;
            }
            font.draw(batch, shader, line.items, vecs.newVec2(bnds.x + 70, y), col.newColor(0, 0, 0, 1));
            var linenr = std.fmt.allocPrint(allocator.alloc, "{}", .{nr}) catch "";
            defer allocator.alloc.free(linenr);
            font.draw(batch, shader, linenr, vecs.newVec2(bnds.x + 6, y), col.newColor(0, 0, 0, 1));
            line.clearAndFree();
            y += font.size;

            nr += 1;
            cy += 1;
            if (cy == self.cursor.y) {
                self.prevIdx = @floatToInt(usize, cx);
            }
            cx = 0;
        } else {
            if (cx == self.cursor.x and cy == self.cursor.y) {
                var size = font.sizeText(line.items);

                font.draw(batch, shader, "|", vecs.newVec2(bnds.x + 64 + size.x, y), col.newColor(0, 0, 0, 1));
                self.cursorIdx = idx;
            }
            if (char < 32 or char == 255) {
                if (char == '\n' or char == '\r') {
                    line.append('\n') catch {};
                } else {
                    line.append('?') catch {};
                }
            } else {
                line.append(char) catch {};
            }

            cx += 1;
        }
    }
    if (cy < self.cursor.y) {
        self.cursor.y = cy;
    }
    if (cy == self.cursor.y and cx <= self.cursor.x) {
        var size = font.sizeText(line.items);
        self.cursor.x = cx;

        font.draw(batch, shader, "|", vecs.newVec2(bnds.x + 64 + size.x, y), col.newColor(0, 0, 0, 1));
        self.cursorIdx = self.buffer.items.len;
    }
    if (self.cursor.x <= 0 and self.cursor.y == cy) {
        self.cursor.x = 0;

        font.draw(batch, shader, "|", vecs.newVec2(bnds.x + 64, y), col.newColor(0, 0, 0, 1));
        self.cursorIdx = self.buffer.items.len - (line.items.len);
    }
    font.draw(batch, shader, line.items, vecs.newVec2(bnds.x + 70, y), col.newColor(0, 0, 0, 1));
    var linenr = std.fmt.allocPrint(allocator.alloc, "{}", .{nr}) catch "";
    defer allocator.alloc.free(linenr);
    font.draw(batch, shader, linenr, vecs.newVec2(bnds.x + 6, y), col.newColor(0, 0, 0, 1));

    if (self.buffer.items.len == 0) {
        self.cursorIdx = 0;
    }
}

pub fn clickEditor(c: *[]u8, _: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) bool {
    var self = @ptrCast(*EditorData, c);
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

fn focusEditor(c: *[]u8) void {
    var self = @ptrCast(*EditorData, c);
    if (!self.modified and self.file != null) {
        self.buffer.clearAndFree();
        self.buffer.appendSlice(self.file.?.read()) catch {};
        return;
    }
}

fn deleteEditor(cself: *[]u8) void {
    var self = @ptrCast(*EditorData, cself);
    self.buffer.deinit();
    allocator.alloc.destroy(self);
}

pub fn keyEditor(cself: *[]u8, key: i32, mods: i32) void {
    var self = @ptrCast(*EditorData, cself);

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
        cc.GLFW_KEY_MINUS => {
            self.buffer.insert(self.cursorIdx, '-') catch {};
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
    const self = allocator.alloc.create(EditorData) catch undefined;

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
    self.file = null;
    self.buffer = std.ArrayList(u8).init(allocator.alloc);
    self.cursor.x = 0;
    self.cursor.y = 0;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .drawFn = drawEditor,
        .clickFn = clickEditor,
        .keyFn = keyEditor,
        .deleteFn = deleteEditor,
        .focusFn = focusEditor,
        .name = "EEEDT",
        .kind = "editor",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
