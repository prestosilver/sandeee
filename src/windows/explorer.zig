const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../texture.zig");
const c = @import("../c.zig");

const SCROLL = 30;

const Icon = struct {
    name: []const u8,
    icon: u8,
};

const ExplorerData = struct {
    const ExplorerMouseActionType = enum {
        SingleLeft,
        DoubleLeft,
    };
    const ExplorerMouseAction = struct {
        kind: ExplorerMouseActionType,
        pos: vecs.Vector2,
        time: f32,
    };

    shader: shd.Shader,
    icons: [5]sprite.Sprite,
    scroll: [3]sprite.Sprite,
    scrollVal: f32,
    focus: sprite.Sprite,
    focused: ?u64,
    selected: usize,
    path: *files.Folder,
    maxy: f32,
    lastAction: ?ExplorerMouseAction,

    pub fn getIcons(self: *ExplorerData) []const Icon {
        var result = allocator.alloc.alloc(Icon, self.path.subfolders.items.len + self.path.contents.items.len) catch undefined;
        var idx: usize = 0;

        for (self.path.subfolders.items) |folder| {
            result[idx] = Icon{
                .name = folder.name[self.path.name.len .. folder.name.len - 1],
                .icon = 3,
            };
            idx += 1;
        }

        for (self.path.contents.items) |file| {
            result[idx] = Icon{
                .name = file.name[self.path.name.len..],
                .icon = 4,
            };
            idx += 1;
        }

        return result;
    }
};

pub fn drawExplorer(cself: *[]u8, batch: *sb.SpriteBatch, font_shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*ExplorerData, cself);

    if (self.lastAction != null) {
        if (self.lastAction.?.time <= 0) {
            self.lastAction = null;
        } else {
            self.lastAction.?.time -= 5;
        }
    }

    self.scroll[1].data.size.y = bnds.h - 20;

    batch.draw(sprite.Sprite, &self.scroll[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y - 2, 0));
    batch.draw(sprite.Sprite, &self.scroll[1], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 10, 0));
    batch.draw(sprite.Sprite, &self.scroll[2], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + bnds.h - 10, 0));

    var x: f32 = 0;
    var y: f32 = -self.scrollVal;

    var icons = self.getIcons();
    defer allocator.alloc.free(icons);

    for (icons) |icon, idx| {
        var size = font.sizeText(icon.name);
        var xo = (128 - size.x) / 2;

        font.draw(batch, font_shader, icon.name, vecs.newVec2(bnds.x + x + xo - 10, bnds.y + 64 + y + 6), col.newColor(0, 0, 0, 1));

        batch.draw(sprite.Sprite, &self.icons[icon.icon], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

        if (idx + 1 == self.selected)
            batch.draw(sprite.Sprite, &self.focus, self.shader, vecs.newVec3(bnds.x + x + 2 + 16, bnds.y + y + 2, 0));

        if (self.lastAction != null) {
            if (rect.newRect(x + 2 + 16, y + 2 + 16, 64, 64).contains(self.lastAction.?.pos)) {
                switch (self.lastAction.?.kind) {
                    .SingleLeft => {
                        self.selected = idx + 1;
                    },
                    .DoubleLeft => {
                        var newPath = self.path.getFolder(icon.name);
                        if (newPath != null) {
                            self.path = newPath.?;
                            self.selected = 0;
                        }
                        self.lastAction = null;
                    },
                }
            }
        }

        x += 128;
        if (x + 128 > bnds.w) {
            y += 72 + font.size;
            x = 0;
        }
    }

    self.maxy = y + 64 + font.size + font.size + self.scrollVal - bnds.h;

    if (self.scrollVal > self.maxy)
        self.scrollVal = self.maxy;
    if (self.scrollVal < 0)
        self.scrollVal = 0;
}

fn deleteExplorer(cself: *[]u8) void {
    var self = @ptrCast(*ExplorerData, cself);
    allocator.alloc.destroy(self);
}

fn scrollExplorer(cself: *[]u8, _: f32, y: f32) void {
    var self = @ptrCast(*ExplorerData, cself);

    self.scrollVal -= y * SCROLL;

    if (self.scrollVal > self.maxy)
        self.scrollVal = self.maxy;
    if (self.scrollVal < 0)
        self.scrollVal = 0;
}

pub fn clickExplorer(cself: *[]u8, _: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) bool {
    var self = @ptrCast(*ExplorerData, cself);

    switch (btn) {
        0 => {
            if (self.lastAction != null) {
                self.lastAction = .{
                    .kind = .DoubleLeft,
                    .pos = mousepos,
                    .time = 10,
                };
            } else {
                self.lastAction = .{
                    .kind = .SingleLeft,
                    .pos = mousepos,
                    .time = 40,
                };
            }
        },
        else => {},
    }

    return true;
}

pub fn keyExplorer(cself: *[]u8, key: i32, _: i32) void {
    var self = @ptrCast(*ExplorerData, cself);

    switch (key) {
        c.GLFW_KEY_BACKSPACE => {
            self.path = self.path.parent;
            self.selected = 0;
        },
        else => {},
    }
}

pub fn new(texture: tex.Texture, shader: shd.Shader) win.WindowContents {
    var self = allocator.alloc.create(ExplorerData) catch undefined;

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

    self.focus = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(7.0 / 32.0, 3.0 / 32.0 / ym, 3.0 / 32.0, 3.0 / 32.0 / ym),
        vecs.newVec2(72.0, 72.0),
    ));

    self.shader = shader;
    self.selected = 0;

    self.path = files.root;

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .deleteFn = deleteExplorer,
        .drawFn = drawExplorer,
        .keyFn = keyExplorer,
        .clickFn = clickExplorer,
        .scrollFn = scrollExplorer,
        .name = "Files",
        .kind = "explorer",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
