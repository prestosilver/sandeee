const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../util/texture.zig");
const conf = @import("../system/config.zig");
const popups = @import("../drawers/popup2d.zig");
const window_events = @import("../events/window.zig");
const events = @import("../util/events.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");

const SpriteBatch = @import("../util/spritebatch.zig");

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
    last_action: ?SettingsMouseAction = null,
    focused_pane: ?usize = null,
    editing: ?usize = null,
    bnds: rect.Rectangle = .{ .w = 0, .h = 0 },

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
            Setting{
                .kind = .File,
                .setting = "Login Sound",
                .key = "login_sound_path",
            },
            Setting{
                .kind = .File,
                .setting = "Message Sound",
                .key = "message_sound_path",
            },
            Setting{
                .kind = .File,
                .setting = "Logout Sound",
                .key = "logout_sound_path",
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
                .kind = .String,
                .setting = "Window Update Rate",
                .key = "refresh_rate",
            },
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
                .kind = .String,
                .setting = "Extr path",
                .key = "extr_path",
            },
        },
    };

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, _: *win.WindowContents.WindowProps) !void {
        if (self.last_action) |*last_action| {
            if (last_action.time <= 0) {
                self.last_action = null;
            } else {
                last_action.time -= 5;
            }
        }

        self.bnds = bnds.*;

        if (self.focused_pane) |focused| {
            var pos = vecs.Vector2{ .y = 40 };

            for (panes[focused]) |item| {
                // draw name
                try font.draw(.{
                    .shader = font_shader,
                    .text = item.setting,
                    .pos = .{ .x = 16 + bnds.x + pos.x, .y = bnds.y + pos.y },
                });

                // check click
                if (self.last_action) |action| {
                    if ((rect.Rectangle{ .x = pos.x, .y = pos.y, .w = bnds.w, .h = font.size }).contains(action.pos)) {
                        switch (action.kind) {
                            .SingleLeft => {
                                switch (item.kind) {
                                    .String, .Dropdown => {
                                        self.value = conf.SettingManager.instance.get(item.key) orelse "";
                                        const adds = try allocator.alloc.create(popups.all.textpick.PopupTextPick);
                                        adds.* = .{
                                            .prompt = try allocator.alloc.dupe(u8, item.setting),
                                            .text = try allocator.alloc.dupe(u8, self.value),
                                            .data = self,
                                            .submit = &submit,
                                        };

                                        self.value = item.key;

                                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                                            .popup = .atlas("win", .{
                                                .title = "Text Picker",
                                                .source = .{ .w = 1, .h = 1 },
                                                .pos = rect.Rectangle.initCentered(self.bnds, 350, 125),
                                                .contents = popups.PopupData.PopupContents.init(adds),
                                            }),
                                        });
                                        self.last_action = null;
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

                                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                                            .popup = .atlas("win", .{
                                                .title = "Text Picker",
                                                .source = .{ .w = 1.0, .h = 1.0 },
                                                .pos = rect.Rectangle.initCentered(self.bnds, 350, 125),
                                                .contents = popups.PopupData.PopupContents.init(adds),
                                            }),
                                        });
                                        self.last_action = null;
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

                                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                                            .popup = .atlas("win", .{
                                                .title = "Text Picker",
                                                .source = .{ .w = 1.0, .h = 1.0 },
                                                .pos = rect.Rectangle.initCentered(self.bnds, 350, 125),
                                                .contents = popups.PopupData.PopupContents.init(adds),
                                            }),
                                        });
                                        self.last_action = null;
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
                        .pos = .{ .x = 16 + bnds.x + pos.x + bnds.w / 3 * 2, .y = bnds.y + pos.y },
                    });
                } else {
                    try font.draw(.{
                        .shader = font_shader,
                        .text = "UNDEFINED",
                        .pos = .{ .x = 16 + bnds.x + pos.x + bnds.w / 3 * 2, .y = bnds.y + pos.y },
                        .color = .{ .r = 1, .g = 0, .b = 0 },
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
                    .pos = .{ .x = bnds.x + x + xo - 10, .y = bnds.y + 64 + y + 6 },
                });

                try SpriteBatch.global.draw(sprite.Sprite, &self.icons[panel.icon], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if (idx + 1 == self.selection)
                    try SpriteBatch.global.draw(sprite.Sprite, &self.icons[4], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if (self.last_action) |action| {
                    if ((rect.Rectangle{ .x = x + 2 + 16, .y = y + 2, .w = 64, .h = 64 }).contains(action.pos)) {
                        switch (action.kind) {
                            .SingleLeft => {
                                self.selection = idx + 1;
                            },
                            .DoubleLeft => {
                                self.selection = 0;
                                self.focused_pane = idx;
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
        try SpriteBatch.global.draw(sprite.Sprite, &self.menubar, self.shader, .{ .x = bnds.x, .y = bnds.y });

        self.text_box[0].data.size.x = bnds.w - 46;
        self.text_box[1].data.size.x = bnds.w - 50;
        try SpriteBatch.global.draw(sprite.Sprite, &self.text_box[0], self.shader, .{ .x = bnds.x + 42, .y = bnds.y + 2 });
        try SpriteBatch.global.draw(sprite.Sprite, &self.text_box[1], self.shader, .{ .x = bnds.x + 44, .y = bnds.y + 4 });

        const text = try std.mem.concat(allocator.alloc, u8, &.{
            "!SET:/",
            if (self.focused_pane) |focused| panels[focused].name else "",
        });
        defer allocator.alloc.free(text);

        try font.draw(.{
            .shader = font_shader,
            .text = text,
            .pos = .{ .x = bnds.x + 48, .y = bnds.y + 8 },
            .wrap = bnds.w - 56,
            .maxlines = 1,
        });

        try SpriteBatch.global.draw(sprite.Sprite, &self.back_button, self.shader, .{ .x = bnds.x + 2, .y = bnds.y + 2 });
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
                        self.focused_pane = null;
                    }

                    return;
                }

                self.last_action = if (self.last_action) |last_action|
                    if (mousepos.distSq(last_action.pos) < 100)
                        .{
                            .kind = .DoubleLeft,
                            .pos = mousepos,
                            .time = 10,
                        }
                    else
                        .{
                            .kind = .SingleLeft,
                            .pos = mousepos,
                            .time = 100,
                        }
                else
                    .{
                        .kind = .SingleLeft,
                        .pos = mousepos,
                        .time = 100,
                    };
            },
            else => {},
        }
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) void {
        if (!down) return;
        switch (keycode) {
            c.GLFW_KEY_BACKSPACE => {
                self.focused_pane = null;
            },
            else => {},
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(SettingsData);

    self.* = .{
        .shader = shader,
        .highlight = .atlas("ui", .{
            .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 2.0, .y = 28.0 },
        }),
        .menubar = .atlas("ui", .{
            .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
            .size = .{ .y = 40.0 },
        }),
        .text_box = .{
            .atlas("ui", .{
                .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2.0, .y = 32.0 },
            }),
            .atlas("ui", .{
                .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2.0, .y = 28.0 },
            }),
        },
        .icons = undefined,
        .back_button = .atlas("icons", .{
            .source = .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 32.0, .y = 32.0 },
        }),
        .value = "",
    };

    for (self.icons, 0..) |_, idx| {
        const i = @as(f32, @floatFromInt(idx));

        self.icons[idx] = .atlas("big_icons", .{
            .source = .{ .x = i / 8.0, .y = 1.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 64, .y = 64 },
        });
    }

    return win.WindowContents.init(self, "settings", "Settings", .{ .r = 1, .g = 1, .b = 1 });
}
