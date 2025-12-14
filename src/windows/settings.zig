const std = @import("std");
const glfw = @import("glfw");

const Windows = @import("mod.zig");

const drawers = @import("../drawers/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const log = util.log;

const config = system.config;
const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;

const settings = data.settings;

const SettingsData = struct {
    const Self = @This();

    const SettingsMouseActionType = enum {
        SingleLeft,
        DoubleLeft,
    };

    const SettingsMouseAction = struct {
        kind: SettingsMouseActionType,
        pos: Vec2,
        time: f32,
    };

    shader: *Shader,
    highlight: Sprite,
    menubar: Sprite,
    icons: [6]Sprite,
    back_button: Sprite,
    text_box: [2]Sprite,

    focused: ?usize = null,
    selection: usize = 0,
    last_action: ?SettingsMouseAction = null,
    focused_pane: ?usize = null,
    editing: ?usize = null,
    bnds: Rect = .{ .w = 0, .h = 0 },

    value: []const u8,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, _: *Window.Data.WindowContents.WindowProps) !void {
        if (self.last_action) |*last_action| {
            if (last_action.time <= 0) {
                self.last_action = null;
            } else {
                last_action.time -= 5;
            }
        }

        self.bnds = bnds.*;

        if (self.focused_pane) |focused| {
            var pos = Vec2{ .y = 40 };

            for (settings.SETTINGS[focused].entries) |item| {
                // draw name
                try font.draw(.{
                    .shader = font_shader,
                    .text = item.setting,
                    .pos = .{ .x = 16 + bnds.x + pos.x, .y = bnds.y + pos.y },
                });

                // check click
                if (self.last_action) |action| {
                    if ((Rect{ .x = pos.x, .y = pos.y, .w = bnds.w, .h = font.size }).contains(action.pos)) {
                        switch (action.kind) {
                            .SingleLeft => {
                                switch (item.kind) {
                                    .string, .dropdown, .slider => {
                                        self.value = config.SettingManager.instance.get(item.key) orelse "";
                                        const adds = try allocator.alloc.create(Popup.Data.textpick.PopupTextPick);
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
                                                .pos = .initCentered(self.bnds, 350, 125),
                                                .contents = .init(adds),
                                            }),
                                        });
                                        self.last_action = null;
                                    },
                                    .file => {
                                        self.value = config.SettingManager.instance.get(item.key) orelse "";
                                        const adds = try allocator.alloc.create(Popup.Data.filepick.PopupFilePick);
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
                                                .pos = .initCentered(self.bnds, 350, 125),
                                                .contents = .init(adds),
                                            }),
                                        });
                                        self.last_action = null;
                                    },
                                    .folder => {
                                        self.value = config.SettingManager.instance.get(item.key) orelse "";
                                        const adds = try allocator.alloc.create(Popup.Data.folderpick.PopupFolderPick);
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
                                                .pos = .initCentered(self.bnds, 350, 125),
                                                .contents = .init(adds),
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
                const value = config.SettingManager.instance.get(item.key);
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

            for (settings.SETTINGS, 0..) |panel, idx| {
                const size = font.sizeText(.{ .text = panel.name });
                const xo = (128 - size.x) / 2;

                try font.draw(.{
                    .shader = font_shader,
                    .text = panel.name,
                    .pos = .{ .x = bnds.x + x + xo - 10, .y = bnds.y + 64 + y + 6 },
                });

                try SpriteBatch.global.draw(Sprite, &self.icons[panel.icon], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if (idx + 1 == self.selection)
                    try SpriteBatch.global.draw(Sprite, &self.icons[4], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if (self.last_action) |action| {
                    if ((Rect{ .x = x + 2 + 16, .y = y + 2, .w = 64, .h = 64 }).contains(action.pos)) {
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
        try SpriteBatch.global.draw(Sprite, &self.menubar, self.shader, .{ .x = bnds.x, .y = bnds.y });

        self.text_box[0].data.size.x = bnds.w - 46;
        self.text_box[1].data.size.x = bnds.w - 50;
        try SpriteBatch.global.draw(Sprite, &self.text_box[0], self.shader, .{ .x = bnds.x + 42, .y = bnds.y + 2 });
        try SpriteBatch.global.draw(Sprite, &self.text_box[1], self.shader, .{ .x = bnds.x + 44, .y = bnds.y + 4 });

        const text = try std.mem.concat(allocator.alloc, u8, &.{
            "!SET:/",
            if (self.focused_pane) |focused| settings.SETTINGS[focused].name else "",
        });
        defer allocator.alloc.free(text);

        try font.draw(.{
            .shader = font_shader,
            .text = text,
            .pos = .{ .x = bnds.x + 48, .y = bnds.y + 8 },
            .wrap = bnds.w - 56,
            .maxlines = 1,
        });

        try SpriteBatch.global.draw(Sprite, &self.back_button, self.shader, .{ .x = bnds.x + 2, .y = bnds.y + 2 });
    }

    pub fn submit(val: []u8, popup_data: *anyopaque) !void {
        const self: *Self = @ptrCast(@alignCast(popup_data));
        try config.SettingManager.instance.set(self.value, val);
        try config.SettingManager.instance.save();
    }

    pub fn submitFile(val: ?*files.File, popup_data: *anyopaque) !void {
        const self: *Self = @ptrCast(@alignCast(popup_data));
        try config.SettingManager.instance.set(self.value, val.?.name);
        try config.SettingManager.instance.save();
    }

    pub fn submitFolder(val: ?*files.Folder, popup_data: *anyopaque) !void {
        const self: *Self = @ptrCast(@alignCast(popup_data));
        try config.SettingManager.instance.set(self.value, val.?.name);
        try config.SettingManager.instance.save();
    }

    pub fn click(self: *Self, _: Vec2, mousepos: Vec2, btn: ?i32) !void {
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
            glfw.KeyBackspace => {
                self.focused_pane = null;
            },
            else => {},
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
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

    return Window.Data.WindowContents.init(self, "settings", "Settings", .{ .r = 1, .g = 1, .b = 1 });
}
