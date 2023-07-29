const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../util/texture.zig");
const config = @import("../system/config.zig");
const popups = @import("../drawers/popup2d.zig");
const winEvs = @import("../events/window.zig");
const events = @import("../util/events.zig");
const c = @import("../c.zig");

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
    icons: [6]sprite.Sprite,

    focused: ?usize = null,
    selection: usize = 0,
    lastAction: ?SettingsMouseAction = null,
    focusedPane: ?usize = null,
    editing: ?usize = null,

    value: []const u8,

    const panels = [_]SettingPanel{
        SettingPanel{ .name = "Graphics", .icon = 2 },
        SettingPanel{ .name = "Sounds", .icon = 1 },
        SettingPanel{ .name = "Explorer", .icon = 3 },
        SettingPanel{ .name = "System", .icon = 0 },
    };

    const Setting = struct {
        const Kind = enum(u8) { String, Dropdown };

        kind: Kind,
        kinddata: []const u8 = "",

        setting: []const u8,
        key: []const u8,
    };

    const panes = [_][]const Setting{
        &[_]Setting{
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
            Setting{
                .kind = .String,
                .setting = "System font",
                .key = "system_font",
            },
            Setting{
                .kind = .Dropdown,
                .kinddata = "No Yes",
                .setting = "CRT Shader",
                .key = "crt_shader",
            },
        },
        &[_]Setting{
            Setting{
                .kind = .String,
                .setting = "Sound Volume",
                .key = "sound_volume",
            },
            Setting{
                .kind = .Dropdown,
                .kinddata = "No Yes",
                .setting = "Sound Muted",
                .key = "sound_muted",
            },
        },
        &[_]Setting{
            Setting{
                .kind = .Dropdown,
                .kinddata = "No Yes",
                .setting = "Show Hidden Files",
                .key = "explorer_hidden",
            },
            Setting{
                .kind = .String,
                .setting = "Web homepage",
                .key = "web_home",
            },
        },
        &[_]Setting{
            Setting{
                .kind = .Dropdown,
                .kinddata = "No Yes",
                .setting = "Show Welcome",
                .key = "show_welcome",
            },
            Setting{
                .kind = .String,
                .setting = "Startup Script",
                .key = "startup_file",
            },
            Setting{
                .kind = .String,
                .setting = "Extr path",
                .key = "extr_path",
            },
        },
    };

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;

        if (self.lastAction != null) {
            if (self.lastAction.?.time <= 0) {
                self.lastAction = null;
            } else {
                self.lastAction.?.time -= 5;
            }
        }

        if (self.focusedPane) |focused| {
            var pos = vecs.newVec2(0, 0);

            for (panes[focused]) |item| {
                // draw name
                try font.draw(.{
                    .batch = batch,
                    .shader = font_shader,
                    .text = item.setting,
                    .pos = vecs.newVec2(16 + bnds.x + pos.x, bnds.y + pos.y),
                });

                // check click
                if (self.lastAction) |action| {
                    if (rect.newRect(pos.x, pos.y, bnds.w, font.size).contains(action.pos)) {
                        switch (action.kind) {
                            .SingleLeft => {
                                self.value = settingManager.get(item.key) orelse "";
                                const adds = try allocator.alloc.create(popups.all.textpick.PopupTextPick);
                                adds.* = .{
                                    .prompt = item.setting,
                                    .text = try allocator.alloc.dupe(u8, self.value),
                                    .data = self,
                                    .submit = &submit,
                                };

                                self.value = item.key;

                                try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
                                    .popup = .{
                                        .texture = "win",
                                        .data = .{
                                            .title = "Text Picker",
                                            .source = rect.newRect(0, 0, 1, 1),
                                            .size = vecs.newVec2(350, 125),
                                            .parentPos = undefined,
                                            .contents = popups.PopupData.PopupContents.init(adds),
                                        },
                                    },
                                });
                                self.lastAction = null;
                            },
                            .DoubleLeft => {},
                        }
                    }
                }

                // draw value
                const value = settingManager.get(item.key);
                if (value) |val| {
                    try font.draw(.{
                        .batch = batch,
                        .shader = font_shader,
                        .text = val,
                        .pos = vecs.newVec2(16 + bnds.x + pos.x + bnds.w / 3 * 2, bnds.y + pos.y),
                    });
                } else {
                    try font.draw(.{
                        .batch = batch,
                        .shader = font_shader,
                        .text = "UNDEFINED",
                        .pos = vecs.newVec2(16 + bnds.x + pos.x + bnds.w / 3 * 2, bnds.y + pos.y),
                        .color = col.newColor(1, 0, 0, 1),
                    });
                }

                pos.y += font.size;
            }

            return;
        }

        var x: f32 = 0;
        var y: f32 = 0;

        for (SettingsData.panels, 0..) |panel, idx| {
            const size = font.sizeText(.{ .text = panel.name });
            const xo = (128 - size.x) / 2;

            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = panel.name,
                .pos = vecs.newVec2(bnds.x + x + xo - 10, bnds.y + 64 + y + 6),
            });

            try batch.draw(sprite.Sprite, &self.icons[panel.icon], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

            if (idx + 1 == self.selection)
                try batch.draw(sprite.Sprite, &self.icons[4], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

            if (self.lastAction) |action| {
                if (rect.newRect(x + 2 + 16, y + 2, 64, 64).contains(action.pos)) {
                    switch (action.kind) {
                        .SingleLeft => {
                            self.selection = idx + 1;
                        },
                        .DoubleLeft => {
                            self.selection = 0;
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

    pub fn submit(val: []u8, data: *anyopaque) !void {
        const self: *Self = @ptrCast(@alignCast(data));
        try settingManager.set(self.value, val);
        try settingManager.save();
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (btn == null) return;

        switch (btn.?) {
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

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        _ = mods;
        _ = code;
        _ = self;
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) void {
        if (!down) return;
        switch (keycode) {
            c.GLFW_KEY_BACKSPACE => {
                self.focusedPane = null;
            },
            else => {},
        }
    }

    pub fn scroll(_: *Self, _: f32, _: f32) !void {}
    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}
    pub fn moveResize(_: *Self, _: *rect.Rectangle) !void {}

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};

pub fn new(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(SettingsData);

    const ym = @as(f32, @floatFromInt(self.icons.len));
    _ = ym;

    self.* = .{
        .shader = shader,
        .icons = undefined,
        .value = "",
    };

    for (self.icons, 0..) |_, idx| {
        const i = @as(f32, @floatFromInt(idx));

        self.icons[idx] = sprite.Sprite.new("big_icons", sprite.SpriteData.new(
            rect.newRect(i / 8.0, 1.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(64, 64),
        ));
    }

    return win.WindowContents.init(self, "settings", "Settings", col.newColor(1, 1, 1, 1));
}
