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
const shell = @import("../system/shell.zig");

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
    scroll: [4]sprite.Sprite,
    text_box: [2]sprite.Sprite,
    menubar: sprite.Sprite,

    scrollVal: f32,
    focus: sprite.Sprite,
    focused: ?u64,
    selected: usize,
    maxy: f32,
    lastAction: ?ExplorerMouseAction,
    shell: shell.Shell,

    pub fn getIcons(self: *ExplorerData) []const Icon {
        var result = allocator.alloc.alloc(Icon, self.shell.root.subfolders.items.len + self.shell.root.contents.items.len) catch undefined;
        var idx: usize = 0;

        for (self.shell.root.subfolders.items) |folder| {
            result[idx] = Icon{
                .name = folder.name[self.shell.root.name.len .. folder.name.len - 1],
                .icon = 3,
            };
            idx += 1;
        }

        for (self.shell.root.contents.items) |file| {
            result[idx] = Icon{
                .name = file.name[self.shell.root.name.len..],
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

    if (self.shell.vm != null) {
        var result = self.shell.updateVM() catch null;
        if (result != null) {
            result.?.data.deinit();
        }
    }

    var x: f32 = 0;
    var y: f32 = -self.scrollVal + 36;

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
            if (rect.newRect(x + 2 + 16, y + 2, 64, 64).contains(self.lastAction.?.pos)) {
                switch (self.lastAction.?.kind) {
                    .SingleLeft => {
                        self.selected = idx + 1;
                    },
                    .DoubleLeft => {
                        var newPath = self.shell.root.getFolder(icon.name);
                        if (newPath != null) {
                            self.shell.root = newPath.?;
                            self.selected = 0;
                        } else {
                            _ = self.shell.run(icon.name, icon.name) catch {
                                //TODO: popup
                            };
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

    // draw menubar
    self.menubar.data.size.x = bnds.w;
    batch.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

    batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 32, bnds.y + 2, 0));
    self.text_box[1].data.size.x = bnds.w - 4 - 34;

    batch.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 34, bnds.y + 2, 0));
    batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 4, bnds.y + 2, 0));

    var tmp = batch.scissor;
    batch.scissor = rect.newRect(bnds.x + 34, bnds.y + 4, bnds.w - 4 - 34, 28);
    font.drawScale(batch, font_shader, self.shell.root.name, vecs.newVec2(bnds.x + 36, bnds.y + 2), col.newColor(0, 0, 0, 1), 1.0);

    batch.scissor = tmp;

    batch.draw(sprite.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 6, bnds.y + 6, 0));

    // draw scrollbar
    var scrollPc = self.scrollVal / self.maxy;

    self.scroll[1].data.size.y = bnds.h - 20 - 36;

    batch.draw(sprite.Sprite, &self.scroll[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 34, 0));
    batch.draw(sprite.Sprite, &self.scroll[1], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 46, 0));
    batch.draw(sprite.Sprite, &self.scroll[2], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + bnds.h - 10, 0));
    batch.draw(sprite.Sprite, &self.scroll[3], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, (bnds.h - 82) * scrollPc + bnds.y + 46, 0));
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

    if (mousepos.y < 36) {
        if (rect.newRect(0, 0, 28, 28).contains(mousepos)) {
            self.shell.root = self.shell.root.parent;
            self.selected = 0;
        }

        return false;
    }

    switch (btn) {
        0 => {
            if (self.lastAction != null and vecs.distSq(mousepos, self.lastAction.?.pos) < 100) {
                self.lastAction = .{
                    .kind = .DoubleLeft,
                    .pos = mousepos,
                    .time = 10,
                };
            } else {
                self.lastAction = .{
                    .kind = .SingleLeft,
                    .pos = mousepos,
                    .time = 100,
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
            self.shell.root = self.shell.root.parent;
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

    self.scroll[3] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(10.0 / 32.0, 0.0 / 32.0 / ym, 7.0 / 32.0, 14.0 / 32.0 / ym),
        vecs.newVec2(14.0, 28.0),
    ));

    self.focus = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(7.0 / 32.0, 3.0 / 32.0 / ym, 3.0 / 32.0, 3.0 / 32.0 / ym),
        vecs.newVec2(72.0, 72.0),
    ));

    self.menubar = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(17.0 / 32.0, 0.0 / 32.0 / ym, 1.0 / 32.0, 18.0 / 32.0 / ym),
        vecs.newVec2(0.0, 36.0),
    ));

    self.text_box[0] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(18.0 / 32.0, 0.0 / 32.0 / ym, 0.0 / 32.0, 14.0 / 32.0 / ym),
        vecs.newVec2(2.0, 28.0),
    ));

    self.text_box[1] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(19.0 / 32.0, 0.0 / 32.0 / ym, 0.0 / 32.0, 14.0 / 32.0 / ym),
        vecs.newVec2(2.0, 28.0),
    ));

    self.icons[0] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0.0 / 32.0, 21.0 / 32.0 / ym, 10.0 / 32.0, 11.0 / 32.0 / ym),
        vecs.newVec2(20.0, 22.0),
    ));

    self.shader = shader;
    self.selected = 0;

    self.shell.root = files.home;
    self.shell.vm = null;

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
