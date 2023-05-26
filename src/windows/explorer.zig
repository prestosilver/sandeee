const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../util/texture.zig");
const c = @import("../c.zig");
const shell = @import("../system/shell.zig");
const config = @import("../system/config.zig");
const settings = @import("settings.zig");

const SCROLL = 30;

const Icon = struct {
    name: []const u8,
    icon: u8,
};

pub const ExplorerData = struct {
    const Self = @This();

    const ExplorerMouseActionType = enum {
        SingleLeft,
        DoubleLeft,
    };
    const ExplorerMouseAction = struct {
        kind: ExplorerMouseActionType,
        pos: vecs.Vector2,
        time: f32,
    };

    shader: *shd.Shader,
    icons: [6]sprite.Sprite,
    text_box: [2]sprite.Sprite,
    menubar: sprite.Sprite,
    focus: sprite.Sprite,
    gray: sprite.Sprite,
    shell: shell.Shell,

    focused: ?u64 = null,
    selected: usize = 0,
    lastAction: ?ExplorerMouseAction = null,

    pub fn getIcons(self: *Self) ![]const Icon {
        var result = try allocator.alloc.alloc(Icon, self.shell.root.subfolders.items.len + self.shell.root.contents.items.len);
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

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 34,
            };
        }
        if (self.lastAction != null) {
            if (self.lastAction.?.time <= 0) {
                self.lastAction = null;
            } else {
                //FIXME: > 60 fps
                self.lastAction.?.time -= 5;
            }
        }

        var title = try std.fmt.allocPrint(allocator.alloc, "{s}", .{self.shell.root.name});
        defer allocator.alloc.free(title);
        try props.setTitle(title);

        if (self.shell.vm != null) {
            var result = self.shell.updateVM() catch null;
            if (result != null) {
                result.?.data.deinit();
            }
        }

        var x: f32 = 0;
        var y: f32 = -props.scroll.?.value + 36;

        var icons = try self.getIcons();
        defer allocator.alloc.free(icons);

        const hidden = settings.settingManager.getBool("explorer_hidden");

        for (icons, 0..) |icon, idx| {
            if (!hidden and icon.name[0] == '_') continue;

            var size = font.sizeText(.{
                .text = icon.name,
                .wrap = 100,
                .turnicate = true,
            }).x;
            var xo = (128 - size) / 2;

            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = icon.name,
                .pos = vecs.newVec2(bnds.x + x + xo - 5, bnds.y + 64 + y + 6),
                .color = col.newColor(0, 0, 0, 1),
                .wrap = 128,
            });

            try batch.draw(sprite.Sprite, &self.icons[icon.icon], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

            if (idx + 1 == self.selected)
                try batch.draw(sprite.Sprite, &self.focus, self.shader, vecs.newVec3(bnds.x + x + 2 + 16, bnds.y + y + 2, 0));

            if (self.lastAction != null) {
                if (rect.newRect(x + 2 + 16, y + 2, 64, 64).contains(self.lastAction.?.pos)) {
                    switch (self.lastAction.?.kind) {
                        .SingleLeft => {
                            self.selected = idx + 1;
                        },
                        .DoubleLeft => {
                            var newPath = try self.shell.root.getFolder(icon.name);
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

        props.scroll.?.maxy = y + 64 + font.size + font.size + props.scroll.?.value - bnds.h;

        if (self.shell.vm != null) {
            self.gray.data.size.x = bnds.w;
            self.gray.data.size.y = bnds.h;

            try batch.draw(sprite.Sprite, &self.gray, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

            var size = font.sizeText(.{
                .text = "Running VM",
            });

            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = "Running VM",
                .pos = vecs.newVec2(bnds.x + (bnds.w - size.x) / 2, bnds.y + (bnds.h - size.y) / 2),
                .color = col.newColor(1, 1, 1, 1),
            });
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 32, bnds.y + 2, 0));
        self.text_box[1].data.size.x = bnds.w - 4 - 34;

        try batch.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 34, bnds.y + 2, 0));
        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 4, bnds.y + 2, 0));

        var tmp = batch.scissor;
        batch.scissor = rect.newRect(bnds.x + 34, bnds.y + 4, bnds.w - 4 - 34, 28);
        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = self.shell.root.name,
            .pos = vecs.newVec2(bnds.x + 36, bnds.y + 8),
            .color = col.newColor(0, 0, 0, 1),
        });

        batch.scissor = tmp;

        try batch.draw(sprite.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 6, bnds.y + 6, 0));
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) !void {
        if (self.shell.vm != null) return;

        if (mousepos.y < 36) {
            if (rect.newRect(0, 0, 28, 28).contains(mousepos)) {
                self.shell.root = self.shell.root.parent;
                self.selected = 0;
            }

            return;
        }

        switch (btn) {
            0 => {
                if (self.lastAction != null and mousepos.distSq(self.lastAction.?.pos) < 100) {
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
    }

    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        _ = mods;
        _ = code;
        _ = self;
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) void {
        if (self.shell.vm != null) return;
        if (!down) return;

        switch (keycode) {
            c.GLFW_KEY_BACKSPACE => {
                self.shell.root = self.shell.root.parent;
                self.selected = 0;
            },
            else => {},
        }
    }
};

pub fn new(texture: []const u8, shader: *shd.Shader) !win.WindowContents {
    var self = try allocator.alloc.create(ExplorerData);

    var ym = @intToFloat(f32, self.icons.len);

    self.* = .{
        .focus = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(7.0 / 32.0, 3.0 / 32.0 / ym, 3.0 / 32.0, 3.0 / 32.0 / ym),
            vecs.newVec2(72.0, 72.0),
        )),
        .gray = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(7.0 / 32.0, 6.0 / 32.0 / ym, 3.0 / 32.0, 3.0 / 32.0 / ym),
            vecs.newVec2(72.0, 72.0),
        )),
        .menubar = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(17.0 / 32.0, 0.0 / 32.0 / ym, 1.0 / 32.0, 18.0 / 32.0 / ym),
            vecs.newVec2(0.0, 36.0),
        )),
        .text_box = .{
            sprite.Sprite.new(texture, sprite.SpriteData.new(
                rect.newRect(18.0 / 32.0, 0.0 / 32.0 / ym, 0.0 / 32.0, 14.0 / 32.0 / ym),
                vecs.newVec2(2.0, 28.0),
            )),
            sprite.Sprite.new(texture, sprite.SpriteData.new(
                rect.newRect(19.0 / 32.0, 0.0 / 32.0 / ym, 0.0 / 32.0, 14.0 / 32.0 / ym),
                vecs.newVec2(2.0, 28.0),
            )),
        },
        .icons = undefined,
        .shader = shader,
        .shell = .{
            .root = files.home,
            .vm = null,
        },
    };

    for (self.icons, 0..) |_, idx| {
        var i = @intToFloat(f32, idx);

        self.icons[idx] = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(0 / 32.0, i / @intToFloat(f32, self.icons.len), 1.0, 1.0 / @intToFloat(f32, self.icons.len)),
            vecs.newVec2(64, 64),
        ));
    }

    self.icons[0] = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0.0 / 32.0, 21.0 / 32.0 / ym, 10.0 / 32.0, 11.0 / 32.0 / ym),
        vecs.newVec2(20.0, 22.0),
    ));

    return win.WindowContents.init(self, "explorer", "Files", col.newColor(1, 1, 1, 1));
}
