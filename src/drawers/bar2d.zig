const std = @import("std");
const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const fnt = @import("../util/font.zig");
const tex = @import("../util/texture.zig");
const va = @import("../util/vertArray.zig");
const shd = @import("../util/shader.zig");
const win = @import("window2d.zig");
const wins = @import("../windows/all.zig");
const gfx = @import("../util/graphics.zig");
const spr = @import("../drawers/sprite2d.zig");
const c = @import("../c.zig");
const allocator = @import("../util/allocator.zig");
const popups = @import("popup2d.zig");
const files = @import("../system/files.zig");
const settings = @import("../system/config.zig");

const events = @import("../util/events.zig");
const windowEvs = @import("../events/window.zig");

const TOTAL_SPRITES: f32 = 13;
const TEX_SIZE: f32 = 32;

pub var settingsManager: *settings.SettingManager = undefined;

pub const BarData = struct {
    screendims: *vecs.Vector2,
    height: f32,
    btnActive: bool = false,
    btns: i32 = 0,

    fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle) !void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @as(f32, @floatFromInt(sprite));

        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
    }

    fn addUiQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, scale: i32, r: f32, l: f32, t: f32, b: f32) !void {
        const sc = @as(f32, @floatFromInt(scale));

        try addQuad(arr, sprite, rect.newRect(pos.x, pos.y, sc * l, sc * t), rect.newRect(0, 0, l / TEX_SIZE, t / TEX_SIZE));
        try addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y, pos.w - sc * (l + r), sc * t), rect.newRect(l / TEX_SIZE, 0, (TEX_SIZE - l - r) / TEX_SIZE, t / TEX_SIZE));
        try addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y, sc * r, sc * t), rect.newRect((TEX_SIZE - r) / TEX_SIZE, 0, r / TEX_SIZE, t / TEX_SIZE));

        try addQuad(arr, sprite, rect.newRect(pos.x, pos.y + sc * t, sc * l, pos.h - sc * (t + b)), rect.newRect(0, t / TEX_SIZE, l / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE));
        try addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y + sc * t, pos.w - sc * (l + r), pos.h - sc * (t + b)), rect.newRect(l / TEX_SIZE, t / TEX_SIZE, (TEX_SIZE - l - r) / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE));
        try addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y + sc * t, sc * r, pos.h - sc * (t + b)), rect.newRect((TEX_SIZE - r) / TEX_SIZE, t / TEX_SIZE, r / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE));

        try addQuad(arr, sprite, rect.newRect(pos.x, pos.y + pos.h - sc * b, sc * l, sc * b), rect.newRect(0, (TEX_SIZE - b) / TEX_SIZE, l / TEX_SIZE, b / TEX_SIZE));
        try addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y + pos.h - sc * b, pos.w - sc * (l + r), sc * b), rect.newRect(l / TEX_SIZE, (TEX_SIZE - b) / TEX_SIZE, (TEX_SIZE - l - r) / TEX_SIZE, b / TEX_SIZE));
        try addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y + pos.h - sc * b, sc * r, sc * b), rect.newRect((TEX_SIZE - r) / TEX_SIZE, (TEX_SIZE - b) / TEX_SIZE, r / TEX_SIZE, b / TEX_SIZE));
    }

    pub fn drawName(self: *BarData, font_shader: *shd.Shader, shader: *shd.Shader, logoSprite: *spr.Sprite, font: *fnt.Font, batch: *sb.SpriteBatch, windows: *std.ArrayList(win.Window)) !void {
        var pos = rect.newRect(self.height, self.screendims.y - self.height + 12, self.screendims.x + self.height, self.height);

        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = "APPS",
            .pos = pos.location(),
        });

        const ts = std.time.timestamp();
        const hours = @as(i64, @intCast(@as(u64, @intCast(ts)) / std.time.s_per_hour)) - settingsManager.getInt("hours_offset");
        const mins = @as(i64, @intCast(@as(u64, @intCast(ts)) / std.time.s_per_min)) - settingsManager.getInt("minutes_offset");
        const clockString = try std.fmt.allocPrint(allocator.alloc, "{d: >2}:{d:0>2}", .{
            @as(u8, @intCast(@rem(hours, 24))),
            @as(u8, @intCast(@rem(mins, 60))),
        });
        defer allocator.alloc.free(clockString);

        const clockSize = font.sizeText(.{ .text = clockString });
        const clockPos = vecs.newVec2(self.screendims.x - clockSize.x - 10, pos.y);

        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = clockString,
            .pos = clockPos,
        });

        self.btns = 0;

        for (windows.items) |window| {
            pos.x = 3 * self.height + 10 + 4 * (self.height * @as(f32, @floatFromInt(window.data.idx)));
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = window.data.contents.props.info.name,
                .pos = pos.location(),
                .wrap = 4 * self.height - 16,
                .maxlines = 1,
            });

            pos.x += 4 * self.height;
            self.btns += 1;
        }

        if (self.btnActive) {
            try batch.draw(spr.Sprite, logoSprite, shader, vecs.newVec3(2, self.screendims.y - 464 - self.height, 0));

            for (0..10) |i| {
                const height = font.size * 1;
                const y = self.screendims.y - 466 - self.height + 67 * @as(f32, @floatFromInt(i)) + std.math.floor((67 - height) / 2);
                const text = switch (i) {
                    0 => "Cmd",
                    1 => "\x82\x82\x82Mail",
                    2 => "\x82\x82\x82DT",
                    3 => "Files",
                    4 => "Xplore",
                    5 => "Settings",
                    6 => "Log out",
                    else => "",
                };
                const textpos = vecs.newVec2(100, y);
                try font.draw(.{
                    .batch = batch,
                    .shader = font_shader,
                    .text = text,
                    .pos = textpos,
                });
            }
        }
    }

    pub fn doClick(self: *BarData, windows: *std.ArrayList(win.Window), shader: *shd.Shader, pos: vecs.Vector2) !bool {
        const btn = rect.newRect(0, self.screendims.y - self.height, 3 * self.height, self.height);

        var added = false;

        if (self.screendims.y - self.height <= pos.y) {
            var newTop: ?u32 = null;

            for (windows.items, 0..) |*window, idx| {
                const offset = 3 * self.height + 10 + 4 * (self.height * @as(f32, @floatFromInt(window.data.idx)));

                const btnBnds = rect.newRect(offset, self.screendims.y - self.height, 4 * self.height, self.height);

                if (btnBnds.contains(pos)) {
                    if (window.data.active or window.data.min) {
                        window.data.min = !window.data.min;
                    }
                    if (window.data.min) {
                        window.data.active = false;
                    } else {
                        window.data.active = true;
                        newTop = @as(u32, @intCast(idx));
                    }
                } else {
                    window.data.active = false;
                }
            }
            if (newTop) |top| {
                var swap = windows.orderedRemove(@as(usize, @intCast(top)));
                try swap.data.contents.focus();
                try windows.append(swap);
            }
        }

        if (self.btnActive) {
            for (0..10) |i| {
                const y = self.screendims.y - 466 - self.height + 67 * @as(f32, @floatFromInt(i));
                const item = rect.newRect(36, y, 160, 67);
                if (item.contains(pos)) {
                    added = true;
                    switch (i) {
                        0 => {
                            const window = win.Window.new("win", win.WindowData{
                                .source = rect.Rectangle{
                                    .x = 0.0,
                                    .y = 0.0,
                                    .w = 1.0,
                                    .h = 1.0,
                                },
                                .contents = try wins.cmd.new(),
                                .active = true,
                            });

                            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });
                        },
                        1 => {
                            const window = win.Window.new("win", win.WindowData{
                                .source = rect.Rectangle{
                                    .x = 0.0,
                                    .y = 0.0,
                                    .w = 1.0,
                                    .h = 1.0,
                                },
                                .contents = try wins.email.new("email", shader),
                                .active = true,
                            });

                            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });
                        },
                        2 => {
                            const window = win.Window.new("win", win.WindowData{
                                .source = rect.Rectangle{
                                    .x = 0.0,
                                    .y = 0.0,
                                    .w = 1.0,
                                    .h = 1.0,
                                },
                                .contents = try wins.editor.new("editor", shader),
                                .active = true,
                            });

                            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });
                        },
                        3 => {
                            const window = win.Window.new("win", win.WindowData{
                                .source = rect.Rectangle{
                                    .x = 0.0,
                                    .y = 0.0,
                                    .w = 1.0,
                                    .h = 1.0,
                                },
                                .contents = try wins.explorer.new("explorer", shader),
                                .active = true,
                            });

                            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });
                        },
                        4 => {
                            const window = win.Window.new("win", win.WindowData{
                                .source = rect.Rectangle{
                                    .x = 0.0,
                                    .y = 0.0,
                                    .w = 1.0,
                                    .h = 1.0,
                                },
                                .contents = try wins.web.new("web", shader),
                                .active = true,
                            });

                            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });
                        },
                        5 => {
                            const window = win.Window.new("win", win.WindowData{
                                .source = rect.Rectangle{
                                    .x = 0.0,
                                    .y = 0.0,
                                    .w = 1.0,
                                    .h = 1.0,
                                },
                                .contents = try wins.settings.new("explorer", shader),
                                .active = true,
                            });

                            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });
                        },
                        6 => {
                            const adds = try allocator.alloc.create(popups.all.quit.PopupQuit);
                            adds.* = .{
                                .shader = shader,
                                .icons = .{
                                    .{
                                        .texture = "bar",
                                        .data = .{
                                            .source = rect.newRect(0, 11.0 / TOTAL_SPRITES, 1.0, 1.0 / TOTAL_SPRITES),
                                            .size = vecs.newVec2(64, 64),
                                        },
                                    },
                                    .{
                                        .texture = "bar",
                                        .data = .{
                                            .source = rect.newRect(0, 12.0 / TOTAL_SPRITES, 1.0, 1.0 / TOTAL_SPRITES),
                                            .size = vecs.newVec2(64, 64),
                                        },
                                    },
                                },
                            };

                            try events.EventManager.instance.sendEvent(windowEvs.EventCreatePopup{
                                .global = true,
                                .popup = .{
                                    .texture = "win",
                                    .data = .{
                                        .title = "Quit SandEEE",
                                        .source = rect.newRect(0, 0, 1, 1),
                                        .size = vecs.newVec2(350, 125),
                                        .parentPos = undefined,
                                        .contents = popups.PopupData.PopupContents.init(adds),
                                    },
                                },
                            });
                        },
                        else => {},
                    }
                }
            }
        }

        self.btnActive = !self.btnActive and btn.contains(pos);
        if (!btn.contains(pos)) {
            self.btnActive = false;
        }

        const bnds = rect.newRect(0, self.screendims.y - self.height, self.screendims.x, self.height);

        return bnds.contains(pos) or added;
    }

    pub fn submitPopup(_: ?*files.File, data: *anyopaque) !void {
        _ = data;
        c.glfwSetWindowShouldClose(gfx.gContext.window, 1);
    }

    pub fn getVerts(self: *const BarData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();
        const pos = rect.newRect(0, self.screendims.y - self.height, self.screendims.x, self.height);

        try addUiQuad(&result, 0, pos, 2, 3, 3, 3, 3);

        const btn = rect.newRect(0, self.screendims.y - self.height, 3 * self.height, self.height);
        try addUiQuad(&result, 1, btn, 2, 6, 6, 6, 6);

        var icon = btn;

        icon.h -= 6;
        icon.w = icon.h;
        icon.x += 3;
        icon.y += 3;

        try addQuad(&result, 3, icon, rect.newRect(0, 0, 1, 1));

        if (self.btnActive) {
            const menu = rect.newRect(0, self.screendims.y - 466 - self.height, 300, 466);

            try addUiQuad(&result, 4, menu, 2, 3, 3, 3, 3);

            for (0..10) |i| {
                const y = self.screendims.y - 466 - self.height + 67 * @as(f32, @floatFromInt(i));
                const iconpos = rect.newRect(36, y + 2, 64, 64);

                switch (i) {
                    0 => {
                        try addQuad(&result, 5, iconpos, rect.newRect(0, 0, 1, 1));
                    },
                    1 => {
                        try addQuad(&result, 7, iconpos, rect.newRect(0, 0, 1, 1));
                    },
                    2 => {
                        try addQuad(&result, 8, iconpos, rect.newRect(0, 0, 1, 1));
                    },
                    3 => {
                        try addQuad(&result, 6, iconpos, rect.newRect(0, 0, 1, 1));
                    },
                    4 => {
                        try addQuad(&result, 9, iconpos, rect.newRect(0, 0, 1, 1));
                    },
                    5 => {
                        try addQuad(&result, 10, iconpos, rect.newRect(0, 0, 1, 1));
                    },
                    6 => {
                        try addQuad(&result, 11, iconpos, rect.newRect(0, 0, 1, 1));
                    },
                    else => {},
                }
            }
        }

        for (0..@as(usize, @intCast(self.btns))) |i| {
            const b = rect.newRect(self.height * @as(f32, @floatFromInt(i * 4 + 3)), self.screendims.y - self.height, 4 * self.height, self.height);
            try addUiQuad(&result, 1, b, 2, 6, 6, 6, 6);
        }

        return result;
    }
};

pub const Bar = sb.Drawer(BarData);
