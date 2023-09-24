const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const batch = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../util/texture.zig");
const conf = @import("../system/config.zig");
const popups = @import("../drawers/popup2d.zig");
const winEvs = @import("../events/window.zig");
const events = @import("../util/events.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");

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
    highlight: sprite.Sprite,
    menubar: sprite.Sprite,
    icons: [6]sprite.Sprite,
    back_button: sprite.Sprite,
    text_box: [2]sprite.Sprite,

    focused: ?usize = null,
    selection: usize = 0,
    lastAction: ?SettingsMouseAction = null,
    focusedPane: ?usize = null,
    editing: ?usize = null,
    bnds: rect.Rectangle = undefined,

    value: []const u8,

    const panels = [_]SettingPanel{
        SettingPanel{ .name = "Graphics", .icon = 2 },
        SettingPanel{ .name = "Sounds", .icon = 1 },
        SettingPanel{ .name = "Files", .icon = 3 },
        SettingPanel{ .name = "System", .icon = 0 },
    };

    const Setting = struct {
        const Kind = enum(u8) { String, Dropdown, File, Folder };

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
                .kind = .File,
                .setting = "Wallpaper",
                .key = "wallpaper_path",
            },
            Setting{
                .kind = .File,
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
                .kind = .File,
                .setting = "Startup Script",
                .key = "startup_file",
            },
            Setting{
                .kind = .Folder,
                .setting = "Extr path",
                .key = "extr_path",
            },
        },
    };

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;

        if (self.lastAction != null) {
            if (self.lastAction.?.time <= 0) {
                self.lastAction = null;
            } else {
                self.lastAction.?.time -= 5;
            }
        }

        self.bnds = bnds.*;

        if (self.focusedPane) |focused| {
            var pos = vecs.newVec2(0, 40);

            for (panes[focused]) |item| {
                // draw name
                try font.draw(.{
                    .shader = font_shader,
                    .text = item.setting,
                    .pos = vecs.newVec2(16 + bnds.x + pos.x, bnds.y + pos.y),
                });

                // check click
                if (self.lastAction) |action| {
                    if (rect.newRect(pos.x, pos.y, bnds.w, font.size).contains(action.pos)) {
                        switch (action.kind) {
                            .SingleLeft => {
                                switch (item.kind) {
                                    .String, .Dropdown => {
                                        self.value = conf.SettingManager.instance.get(item.key) orelse "";
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
                                                    .pos = rect.newRectCentered(self.bnds, 350, 125),
                                                    .contents = popups.PopupData.PopupContents.init(adds),
                                                },
                                            },
                                        });
                                        self.lastAction = null;
                                    },
                                    .File => {
                                        self.value = conf.SettingManager.instance.get(item.key) orelse "";
                                        const adds = try allocator.alloc.create(popups.all.filepick.PopupFilePick);
                                        adds.* = .{
                                            .path = try allocator.alloc.dupe(u8, self.value),
                                            .data = self,
                                            .submit = &submitFile,
                                        };

                                        self.value = item.key;

                                        try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
                                            .popup = .{
                                                .texture = "win",
                                                .data = .{
                                                    .title = "Text Picker",
                                                    .source = rect.newRect(0, 0, 1, 1),
                                                    .pos = rect.newRectCentered(self.bnds, 350, 125),
                                                    .contents = popups.PopupData.PopupContents.init(adds),
                                                },
                                            },
                                        });
                                        self.lastAction = null;
                                    },
                                    .Folder => {
                                        self.value = conf.SettingManager.instance.get(item.key) orelse "";
                                        const adds = try allocator.alloc.create(popups.all.folderpick.PopupFolderPick);
                                        adds.* = .{
                                            .path = try allocator.alloc.dupe(u8, self.value),
                                            .data = self,
                                            .submit = &submitFolder,
                                        };

                                        self.value = item.key;

                                        try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
                                            .popup = .{
                                                .texture = "win",
                                                .data = .{
                                                    .title = "Text Picker",
                                                    .source = rect.newRect(0, 0, 1, 1),
                                                    .pos = rect.newRectCentered(self.bnds, 350, 125),
                                                    .contents = popups.PopupData.PopupContents.init(adds),
                                                },
                                            },
                                        });
                                        self.lastAction = null;
                                    },
                                }
                            },
                            .DoubleLeft => {},
                        }
                    }
                }

                // draw value
                const value = conf.SettingManager.instance.get(item.key);
                if (value) |val| {
                    try font.draw(.{
                        .shader = font_shader,
                        .text = val,
                        .pos = vecs.newVec2(16 + bnds.x + pos.x + bnds.w / 3 * 2, bnds.y + pos.y),
                    });
                } else {
                    try font.draw(.{
                        .shader = font_shader,
                        .text = "UNDEFINED",
                        .pos = vecs.newVec2(16 + bnds.x + pos.x + bnds.w / 3 * 2, bnds.y + pos.y),
                        .color = col.newColor(1, 0, 0, 1),
                    });
                }

                pos.y += font.size;
            }
        } else {
            var x: f32 = 0;
            var y: f32 = 40;

            for (SettingsData.panels, 0..) |panel, idx| {
                const size = font.sizeText(.{ .text = panel.name });
                const xo = (128 - size.x) / 2;

                try font.draw(.{
                    .shader = font_shader,
                    .text = panel.name,
                    .pos = vecs.newVec2(bnds.x + x + xo - 10, bnds.y + 64 + y + 6),
                });

                try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[panel.icon], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

                if (idx + 1 == self.selection)
                    try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[4], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

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

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        self.text_box[0].data.size.x = bnds.w - 46;
        self.text_box[1].data.size.x = bnds.w - 50;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 42, bnds.y + 2, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 44, bnds.y + 4, 0));

        const text = try std.mem.concat(allocator.alloc, u8, &.{
            "!SET:/",
            if (self.focusedPane) |focused| panels[focused].name else "",
        });
        defer allocator.alloc.free(text);

        try font.draw(.{
            .shader = font_shader,
            .text = text,
            .pos = vecs.newVec2(bnds.x + 48, bnds.y + 8),
            .wrap = bnds.w - 56,
            .maxlines = 1,
        });

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.back_button, self.shader, vecs.newVec3(bnds.x + 2, bnds.y + 2, 0));
    }

    pub fn submit(val: []u8, data: *anyopaque) !void {
        const self: *Self = @ptrCast(@alignCast(data));
        try conf.SettingManager.instance.set(self.value, val);
        try conf.SettingManager.instance.save();
    }

    pub fn submitFile(val: ?*files.File, data: *anyopaque) !void {
        const self: *Self = @ptrCast(@alignCast(data));
        try conf.SettingManager.instance.set(self.value, val.?.name);
        try conf.SettingManager.instance.save();
    }

    pub fn submitFolder(val: ?*files.Folder, data: *anyopaque) !void {
        const self: *Self = @ptrCast(@alignCast(data));
        try conf.SettingManager.instance.set(self.value, val.?.name);
        try conf.SettingManager.instance.save();
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (btn == null) return;

        switch (btn.?) {
            0 => {
                if (mousepos.y < 40) {
                    if (mousepos.x < 40) {
                        self.focusedPane = null;
                    }

                    return;
                }

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
    pub fn moveResize(_: *Self, _: rect.Rectangle) !void {}
    pub fn refresh(_: *Self) !void {}

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
        .highlight = sprite.Sprite.new("ui", sprite.SpriteData.new(
            rect.newRect(3.0 / 8.0, 4.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(2.0, 28),
        )),
        .menubar = sprite.Sprite.new("ui", sprite.SpriteData.new(
            rect.newRect(4.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 4.0 / 8.0),
            vecs.newVec2(0.0, 40.0),
        )),
        .text_box = .{
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(2.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 32.0),
            )),
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(3.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 28),
            )),
        },
        .icons = undefined,
        .back_button = sprite.Sprite.new("icons", sprite.SpriteData.new(
            rect.newRect(3.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(32, 32),
        )),
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
