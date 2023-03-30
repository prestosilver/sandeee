const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../texture.zig");
const config = @import("../system/config.zig");

pub var settingManager: *config.SettingManager = undefined;

const SettingPanel = struct {
    name: []const u8,
    icon: u8,
};

const SettingsData = struct {
    const Self = @This();

    const SettingsMouseActionType = enum {
        SingleLeft,
        DoubleLeft,
    };

    const SettingsMouseAction = struct {
        kind: SettingsMouseActionType,
        pos: vecs.Vector2,
        time: f32,
    };

    shader: *shd.Shader,
    icons: [5]sprite.Sprite,
    scroll: [3]sprite.Sprite,
    focus: sprite.Sprite,
    focused: ?u64,
    selection: usize,
    lastAction: ?SettingsMouseAction,
    focusedPane: ?u64,

    const panels = [_]SettingPanel{
        SettingPanel{ .name = "Graphics", .icon = 1 },
        SettingPanel{ .name = "Sounds", .icon = 2 },
    };
    const Setting = struct {
        const Kind = enum(u8) { String, Dropdown };

        kind: Kind,
        kinddata: []const u8 = "",

        setting: []const u8,
        key: []const u8,
    };

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) !void {
        if (self.focusedPane) |focused| {
            var settings = std.ArrayList(Setting).init(allocator.alloc);
            defer settings.deinit();

            switch (focused) {
                0 => {
                    try settings.appendSlice(&[_]Setting{
                        Setting{
                            .kind = .String,
                            .setting = "Wallpaper Color",
                            .key = "wallpaper_color",
                        },
                        Setting{
                            .kind = .Dropdown,
                            .kinddata = "Color Tile Center Stretch",
                            .setting = "Wallpaper Mode",
                            .key = "wallpaper_mode",
                        },
                        Setting{
                            .kind = .String,
                            .setting = "Wallpaper Path",
                            .key = "wallpaper_path",
                        },
                    });
                },
                else => {},
            }

            var pos = vecs.newVec2(0, 0);

            for (settings.items) |item| {
                // draw name
                try font.draw(batch, font_shader, item.setting, vecs.newVec2(16 + bnds.x + pos.x, bnds.y + pos.y), col.newColor(0, 0, 0, 1));

                // draw value
                var value = settingManager.get(item.key);
                if (value) |val| {
                    try font.draw(batch, font_shader, val, vecs.newVec2(16 + bnds.x + pos.x + bnds.w / 3 * 2, bnds.y + pos.y), col.newColor(0, 0, 0, 1));
                } else {
                    try font.draw(batch, font_shader, "UNDEFINED", vecs.newVec2(16 + bnds.x + pos.x + bnds.w / 3 * 2, bnds.y + pos.y), col.newColor(1, 0, 0, 1));
                }

                pos.y += font.size;
            }

            self.scroll[1].data.size.y = bnds.h - 20;

            try batch.draw(sprite.Sprite, &self.scroll[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y - 2, 0));
            try batch.draw(sprite.Sprite, &self.scroll[1], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 10, 0));
            try batch.draw(sprite.Sprite, &self.scroll[2], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + bnds.h - 10, 0));

            return;
        }

        if (self.lastAction != null) {
            if (self.lastAction.?.time <= 0) {
                self.lastAction = null;
            } else {
                self.lastAction.?.time -= 5;
            }
        }

        self.scroll[1].data.size.y = bnds.h - 20;

        try batch.draw(sprite.Sprite, &self.scroll[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y - 2, 0));
        try batch.draw(sprite.Sprite, &self.scroll[1], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + 10, 0));
        try batch.draw(sprite.Sprite, &self.scroll[2], self.shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + bnds.h - 10, 0));

        var x: f32 = 0;
        var y: f32 = 0;

        for (SettingsData.panels) |panel, idx| {
            var size = font.sizeText(panel.name);
            var xo = (128 - size.x) / 2;

            try font.draw(batch, font_shader, panel.name, vecs.newVec2(bnds.x + x + xo - 10, bnds.y + 64 + y + 6), col.newColor(0, 0, 0, 1));

            try batch.draw(sprite.Sprite, &self.icons[panel.icon], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

            if (idx + 1 == self.selection)
                try batch.draw(sprite.Sprite, &self.focus, self.shader, vecs.newVec3(bnds.x + x + 2 + 16, bnds.y + y + 2, 0));

            if (self.lastAction != null) {
                if (rect.newRect(x + 2 + 16, y + 2, 64, 64).contains(self.lastAction.?.pos)) {
                    switch (self.lastAction.?.kind) {
                        .SingleLeft => {
                            self.selection = idx + 1;
                        },
                        .DoubleLeft => {
                            self.focusedPane = idx;
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
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) !void {
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
                        .time = 100,
                    };
                }
            },
            else => {},
        }
    }

    pub fn key(_: *Self, _: i32, _: i32) !void {}
    pub fn scroll(_: *Self, _: f32, _: f32) !void {}
    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};

pub fn new(texture: *tex.Texture, shader: *shd.Shader) !win.WindowContents {
    var self = try allocator.alloc.create(SettingsData);

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
    self.focusedPane = null;

    return win.WindowContents.init(self, "settings", "Settings", col.newColor(1, 1, 1, 1));
}
