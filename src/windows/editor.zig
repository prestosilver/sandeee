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
    icons: [2]sp.Sprite,
    cursor: vecs.Vector2,
    cursorIdx: usize,
    prevIdx: usize,
    modified: bool,

    clickPos: ?vecs.Vector2,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 34,
            };
        }

        if (self.file) |file| {
            if (!std.mem.eql(u8, props.info.name, "EEEDT")) {
                allocator.alloc.free(props.info.name);
            }
            var idx = std.mem.lastIndexOf(u8, file.name, "/") orelse 0;
            props.info.name = try std.fmt.allocPrint(allocator.alloc, "EEEDT - {s}{s}", .{ file.name[idx + 1 ..], if (self.modified) "*" else "" });
        }

        self.menuTop.data.size.x = bnds.w + 4;
        self.menuDiv.data.size.x = bnds.w + 4;

        self.numLeft.data.size.y = bnds.h - 34;
        self.numDiv.data.size.y = bnds.h - 34;

        // draw number sidebar
        try batch.draw(sp.Sprite, &self.numLeft, self.shader, vecs.newVec3(bnds.x, bnds.y + 34, 0));
        try batch.draw(sp.Sprite, &self.numDiv, self.shader, vecs.newVec3(bnds.x + 62, bnds.y + 34, 0));

        // draw file text
        if (self.file != null) {
            // draw lines
            var y = bnds.y + 32 - props.scroll.?.value;
            var nr: usize = 1;
            self.cursorIdx = @floatToInt(usize, self.cursor.x);
            self.prevIdx = 0;

            props.scroll.?.maxy = -bnds.h + 36;

            var splitIter = std.mem.split(u8, self.buffer.items, "\n");

            while (splitIter.next()) |line| {
                if (nr - 1 < @floatToInt(usize, self.cursor.y)) {
                    self.cursorIdx += line.len + 1;
                    self.prevIdx += line.len + 1;
                }

                if (nr - 1 == @floatToInt(usize, self.cursor.y)) {
                    self.cursor.x = @min(self.cursor.x, @intToFloat(f32, line.len));
                }

                if (y > bnds.y - font.size and y < bnds.y + bnds.h) {
                    try font.draw(.{
                        .batch = batch,
                        .shader = shader,
                        .text = line,
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

                    if (nr - 1 == @floatToInt(i32, self.cursor.y)) {
                        var posx = font.sizeText(.{
                            .text = line[0..@floatToInt(usize, self.cursor.x)],
                        }).x;
                        try font.draw(.{
                            .batch = batch,
                            .shader = shader,
                            .text = "|",
                            .pos = vecs.newVec2(bnds.x + 70 + posx - 6, y),
                        });
                    }
                }

                y += font.size;
                props.scroll.?.maxy += font.size;

                nr += 1;
            }
        }

        // draw toolbar
        try batch.draw(sp.Sprite, &self.menuTop, self.shader, vecs.newVec3(bnds.x - 2, bnds.y - 2, 0));
        try batch.draw(sp.Sprite, &self.menuDiv, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 32, 0));

        // draw toolbar icons
        try batch.draw(sp.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 34, bnds.y, 0));
        try batch.draw(sp.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x, bnds.y, 0));
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
        _ = self;
        // if (!self.modified and self.file != null) {
        //     self.buffer.clearAndFree();
        //     try self.buffer.appendSlice(try self.file.?.read(null));

        //     return;
        // }
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
                        self.cursor.x = @intToFloat(f32, self.prevIdx - 1);
                    }
                }
                self.modified = true;
            },
            cc.GLFW_KEY_SEMICOLON => {
                if ((mods & cc.GLFW_MOD_SHIFT) != 0) {
                    try self.buffer.insert(self.cursorIdx, ':');
                } else {
                    try self.buffer.insert(self.cursorIdx, ';');
                }
                self.cursor.x += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_APOSTROPHE => {
                if ((mods & cc.GLFW_MOD_SHIFT) != 0) {
                    try self.buffer.insert(self.cursorIdx, '"');
                } else {
                    try self.buffer.insert(self.cursorIdx, '\'');
                }
                self.cursor.x += 1;
                self.modified = true;
            },
            cc.GLFW_KEY_LEFT => {
                self.cursor.x -= 1;
                if (self.cursor.x < 0) self.cursor.x = 0;
            },
            cc.GLFW_KEY_RIGHT => {
                self.cursor.x += 1;
            },
            cc.GLFW_KEY_UP => {
                self.cursor.y -= 1;
                if (self.cursor.y < 0) self.cursor.y = 0;
            },
            cc.GLFW_KEY_DOWN => {
                self.cursor.y += 1;
            },
            else => {},
        }
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}
};

pub fn new(texture: *tex.Texture, shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(EditorData);

    self.menuTop = sp.Sprite.new(texture, sp.SpriteData.new(
        rect.newRect(19.0 / 32.0, 0.0 / 32.0, 13.0 / 32.0, 2.0 / 32.0),
        vecs.newVec2(100, 34),
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
    self.cursorIdx = 0;

    return win.WindowContents.init(self, "editor", "EEEDT", col.newColor(1, 1, 1, 1));
}
