const std = @import("std");
const glfw = @import("glfw");

const windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const popups = windows.popups;

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

    shader: *Shader,
    highlight: Sprite,
    menubar: Sprite,
    icons: [6]Sprite,
    back_button: Sprite,
    text_box: [2]Sprite,

    mousepos: Vec2 = .{},
    focused: ?usize = null,
    hover_idx: ?usize = null,
    selected: ?usize = null,
    focused_pane: ?usize = null,
    editing: ?usize = null,
    bnds: Rect = .{ .w = 0, .h = 0 },

    value: []const u8,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, _: *Window.Data.WindowContents.WindowProps) !void {
        self.bnds = bnds.*;

        if (self.focused_pane) |focused| {
            var pos = Vec2{ .y = 40 };

            self.hover_idx = null;
            for (settings.SETTINGS[focused].entries, 0..) |item, idx| {
                // draw name
                try font.draw(.{
                    .shader = font_shader,
                    .text = item.setting,
                    .pos = .{ .x = 16 + bnds.x + pos.x, .y = bnds.y + pos.y },
                });

                // check click
                if ((Rect{ .x = pos.x, .y = pos.y, .w = bnds.w, .h = font.size }).contains(self.mousepos)) {
                    self.hover_idx = idx;
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

            self.hover_idx = null;
            for (settings.SETTINGS, 0..) |panel, idx| {
                const size = font.sizeText(.{ .text = panel.name });
                const xo = (128 - size.x) / 2;

                try font.draw(.{
                    .shader = font_shader,
                    .text = panel.name,
                    .pos = .{ .x = bnds.x + x + xo - 10, .y = bnds.y + 64 + y + 6 },
                });

                try SpriteBatch.global.draw(Sprite, &self.icons[panel.icon], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if (idx == self.selected)
                    try SpriteBatch.global.draw(Sprite, &self.icons[4], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if ((Rect{ .x = x + 2 + 16, .y = y + 2, .w = 64, .h = 64 }).contains(self.mousepos)) {
                    self.hover_idx = idx;
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

        const text = try std.mem.concat(allocator, u8, &.{
            "!SET:/",
            if (self.focused_pane) |focused| settings.SETTINGS[focused].name else "",
        });
        defer allocator.free(text);

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

    pub fn move(self: *Self, x: f32, y: f32) void {
        self.mousepos = .{ .x = x, .y = y };
    }

    pub fn click(self: *Self, _: Vec2, mousepos: Vec2, btn: i32, kind: events.input.ClickKind) !void {
        if (self.focused_pane) |focused| {
            if (kind == .single) {
                if (self.hover_idx) |hover_idx| {
                    const item = settings.SETTINGS[focused].entries[hover_idx];
                    switch (item.kind) {
                        .string, .dropdown, .slider => {
                            if (btn == 0) {
                                self.value = config.SettingManager.instance.get(item.key) orelse "";
                                const adds = try allocator.create(popups.textpick.PopupTextPick);
                                adds.* = .{
                                    .prompt = try allocator.dupe(u8, item.setting),
                                    .text = try allocator.dupe(u8, self.value),
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
                            }
                        },
                        .file => {
                            if (btn == 0) {
                                self.value = config.SettingManager.instance.get(item.key) orelse "";
                                const adds = try allocator.create(popups.filepick.PopupFilePick);
                                adds.* = .{
                                    .path = try allocator.dupe(u8, self.value),
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
                            }
                        },
                        .folder => {
                            if (btn == 0) {
                                self.value = config.SettingManager.instance.get(item.key) orelse "";
                                const adds = try allocator.create(popups.folderpick.PopupFolderPick);
                                adds.* = .{
                                    .path = try allocator.dupe(u8, self.value),
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
                            }
                        },
                    }
                }
            }
            if (mousepos.y < 40) {
                if (mousepos.x < 40) {
                    if (btn == 0)
                        self.focused_pane = null;
                }

                return;
            }
        } else {
            if (btn == 0 and kind == .single) {
                self.selected = self.hover_idx;
            } else if (btn == 0 and kind == .double) {
                if (self.hover_idx) |hover_idx|
                    self.focused_pane = hover_idx;
                self.selected = null;
            }
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
        allocator.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(SettingsData);

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
