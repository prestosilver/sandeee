const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../util/spritebatch.zig");
const tex = @import("../util/texture.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const sp = @import("../drawers/sprite2d.zig");
const cc = @import("../c.zig");

const SCROLL = 30;

pub const EditorData = struct {
    const Self = @This();

    file: ?*files.File,
    buffer: std.ArrayList(u8),
    menuTop: sp.Sprite,
    menuDiv: sp.Sprite,
    shader: *shd.Shader,
    numLeft: sp.Sprite,
    numDiv: sp.Sprite,
    scrollSp: [4]sp.Sprite,
    icons: [2]sp.Sprite,
    cursor: vecs.Vector2,
    cursorIdx: usize,
    prevIdx: usize,
    modified: bool,
    scrollVal: f32,
    maxy: f32,

    clickPos: ?vecs.Vector2,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) !void {
        self.menuTop.data.size.x = bnds.w + 4;
        self.menuDiv.data.size.x = bnds.w + 4;

        self.numLeft.data.size.y = bnds.h - 36;
        self.numDiv.data.size.y = bnds.h - 36;

        if (self.file != null) {
            // draw lines
            var y = bnds.y + 32 - self.scrollVal;
            var line = std.ArrayList(u8).init(allocator.alloc);
            var nr: i32 = 1;
            defer line.deinit();

            self.maxy = -bnds.h + 36;

            var cx: f32 = 0;
            var cy: f32 = 0;

            for (self.buffer.items, 0..) |char, idx| {
                if (char == '\n') {
                    if (cy == self.cursor.y and cx <= self.cursor.x) {
                        var size = font.sizeText(.{ .text = line.items });
                        self.cursor.x = cx;

                        try font.draw(.{
                            .batch = batch,
                            .shader = shader,
                            .text = "|",
                            .pos = vecs.newVec2(bnds.x + 64 + size.x, y),
                        });
                        self.cursorIdx = idx;
                    } else if (self.cursor.x <= 0 and self.cursor.y == cy) {
                        self.cursor.x = 0;

                        try font.draw(.{
                            .batch = batch,
                            .shader = shader,
                            .text = "|",
                            .pos = vecs.newVec2(bnds.x + 64, y),
                        });
                        self.cursorIdx = idx - line.items.len;
                    }
                    try font.draw(.{
                        .batch = batch,
                        .shader = shader,
                        .text = line.items,
                        .pos = vecs.newVec2(bnds.x + 70, y),
                    });
                    var linenr = try std.fmt.allocPrint(allocator.alloc, "{}", .{nr});
                    defer allocator.alloc.free(linenr);
                    try font.draw(.{
                        .batch = batch,
                        .shader = shader,
                        .text = linenr,
                        .pos = vecs.newVec2(bnds.x + 6, y),
                    });
                    line.clearAndFree();
                    y += font.size;
                    self.maxy += font.size;

                    nr += 1;
                    cy += 1;
                    if (cy == self.cursor.y) {
                        self.prevIdx = @floatToInt(usize, cx);
                    }
                    cx = 0;
                } else {
                    if (cx == self.cursor.x and cy == self.cursor.y) {
                        var size = font.sizeText(.{ .text = line.items });

                        try font.draw(.{
                            .batch = batch,
                            .shader = shader,
                            .text = "|",
                            .pos = vecs.newVec2(bnds.x + 64 + size.x, y),
                        });
                        self.cursorIdx = idx;
                    }
                    if (char < 32 or char == 255) {
                        if (char == '\n' or char == '\r') {
                            try line.append('\n');
                        } else {
                            try line.append('?');
                        }
                    } else {
                        try line.append(char);
                    }

                    cx += 1;
                }
            }
            if (cy < self.cursor.y) {
                self.cursor.y = cy;
            }
            if (cy == self.cursor.y and cx <= self.cursor.x) {
                var size = font.sizeText(.{ .text = line.items });
                self.cursor.x = cx;

                try font.draw(.{
                    .batch = batch,
                    .shader = shader,
                    .text = "|",
                    .pos = vecs.newVec2(bnds.x + 64 + size.x, y),
                });
                self.cursorIdx = self.buffer.items.len;
            }
            if (self.cursor.x <= 0 and self.cursor.y == cy) {
                self.cursor.x = 0;

                try font.draw(.{
                    .batch = batch,
                    .shader = shader,
                    .text = "|",
                    .pos = vecs.newVec2(bnds.x + 64, y),
                });
                self.cursorIdx = self.buffer.items.len - (line.items.len);
            }
            try font.draw(.{
                .batch = batch,
                .shader = shader,
                .text = line.items,
                .pos = vecs.newVec2(bnds.x + 70, y),
            });
            var linenr = try std.fmt.allocPrint(allocator.alloc, "{}", .{nr});
            defer allocator.alloc.free(linenr);
            try font.draw(.{
                .batch = batch,
                .shader = shader,
                .text = linenr,
                .pos = vecs.newVec2(bnds.x + 6, y),
            });

            if (self.buffer.items.len == 0) {
                self.cursorIdx = 0;
            }

            if (self.maxy < 0) {
                self.maxy = 0;
            }
        }

        // draw toolbar
        try batch.draw(sp.Sprite, &self.menuTop, self.shader, vecs.newVec3(bnds.x - 2, bnds.y - 2, 0));
        try batch.draw(sp.Sprite, &self.menuDiv, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 34, 0));
        try batch.draw(sp.Sprite, &self.numLeft, self.shader, vecs.newVec3(bnds.x, bnds.y + 36, 0));
        try batch.draw(sp.Sprite, &self.numDiv, self.shader, vecs.newVec3(bnds.x + 64, bnds.y + 36, 0));

        try batch.draw(sp.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 34, bnds.y, 0));
        try batch.draw(sp.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        // draw scrollbar
        if (self.maxy != 0) {
            var scrollPc = self.scrollVal / self.maxy;

            self.scrollSp[1].data.size.y = bnds.h - 20 - 36;

            try batch.draw(sp.Sprite, &self.scrollSp[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 34, 0));
            try batch.draw(sp.Sprite, &self.scrollSp[1], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 46, 0));
            try batch.draw(sp.Sprite, &self.scrollSp[2], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + bnds.h - 10, 0));
            try batch.draw(sp.Sprite, &self.scrollSp[3], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, (bnds.h - 84) * scrollPc + bnds.y + 46, 0));
        }
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) !void {
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
                        var buff = try allocator.alloc.alloc(u8, self.buffer.items.len);
                        std.mem.copy(u8, buff, self.buffer.items);
                        self.file.?.contents = buff;
                        std.log.info("saved", .{});
                        self.modified = false;
                    }
                }
            },
            else => {},
        }

        return;
    }

    pub fn move(_: *Self, _: f32, _: f32) !void {}

    pub fn focus(self: *Self) !void {
        if (!self.modified and self.file != null) {
            self.buffer.clearAndFree();
            try self.buffer.appendSlice(try self.file.?.read(null));

            return;
        }
    }

    pub fn deinit(self: *Self) !void {
        self.buffer.deinit();
        allocator.alloc.destroy(self);
    }

    pub fn key(self: *Self, keycode: i32, mods: i32) !void {
        if (self.file == null) return;

        switch (keycode) {
            cc.GLFW_KEY_A...cc.GLFW_KEY_Z => {
                if ((mods & cc.GLFW_MOD_SHIFT) != 0) {
                    try self.buffer.insert(self.cursorIdx, @intCast(u8, keycode - cc.GLFW_KEY_A) + 'A');
                } else {
                    try self.buffer.insert(self.cursorIdx, @intCast(u8, keycode - cc.GLFW_KEY_A) + 'a');
                }
                self.cursor.x += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_0...cc.GLFW_KEY_9 => {
                if ((mods & cc.GLFW_MOD_SHIFT) != 0) {
                    try self.buffer.insert(self.cursorIdx, ")!@#$%^&*("[@intCast(u8, keycode - cc.GLFW_KEY_0)]);
                } else {
                    try self.buffer.insert(self.cursorIdx, @intCast(u8, keycode - cc.GLFW_KEY_0) + '0');
                }
                self.cursor.x += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_ENTER => {
                try self.buffer.insert(self.cursorIdx, '\n');
                self.cursor.x = 0;
                self.cursor.y += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_COMMA => {
                try self.buffer.insert(self.cursorIdx, ',');
                self.cursor.x += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_PERIOD => {
                try self.buffer.insert(self.cursorIdx, '.');
                self.cursor.x += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_MINUS => {
                try self.buffer.insert(self.cursorIdx, '-');
                self.cursor.x += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_SPACE => {
                try self.buffer.insert(self.cursorIdx, ' ');
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

    pub fn scroll(self: *Self, _: f32, y: f32) void {
        self.scrollVal -= y * SCROLL;

        if (self.scrollVal > self.maxy)
            self.scrollVal = self.maxy;
        if (self.scrollVal < 0)
            self.scrollVal = 0;
    }
};

pub fn new(texture: *tex.Texture, shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(EditorData);

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

    self.scrollSp[0] = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(16.0 / 32.0, 16.0 / 32.0, 7.0 / 32.0, 6.0 / 32.0),
        vecs.newVec2(14.0, 12.0),
    ));

    self.scrollSp[1] = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(16.0 / 32.0, 22.0 / 32.0, 7.0 / 32.0, 4.0 / 32.0),
        vecs.newVec2(14.0, 64),
    ));

    self.scrollSp[2] = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(16.0 / 32.0, 26.0 / 32.0, 7.0 / 32.0, 6.0 / 32.0),
        vecs.newVec2(14.0, 12.0),
    ));

    self.scrollSp[3] = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(23.0 / 32.0, 16.0 / 32.0, 7.0 / 32.0, 14.0 / 32.0),
        vecs.newVec2(14.0, 28.0),
    ));
    self.shader = shader;
    self.file = null;
    self.buffer = std.ArrayList(u8).init(allocator.alloc);
    self.cursor.x = 0;
    self.cursor.y = 0;
    self.scrollVal = 0;
    self.maxy = 0;

    return win.WindowContents.init(self, "editor", "EEEDT", col.newColor(1, 1, 1, 1));
}
