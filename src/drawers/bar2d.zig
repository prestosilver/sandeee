const std = @import("std");
const c = @import("../c.zig");

const drawers = @import("mod.zig");

const windows = @import("../windows/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Eln = util.Eln;
const allocator = util.allocator;
const graphics = util.Graphics;

const Shell = system.Shell;
const files = system.files;
const config = system.config;

const EventManager = events.EventManager;
const window_events = events.windows;

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const TOTAL_SPRITES = 13.0;

const TEX_SIZE = 32;
const ICON_SIZE = 64;
const ICON_SPACE = 3;

pub const BarData = struct {
    screendims: *Vec2,
    height: f32,
    btn_active: bool = false,
    btns: i32 = 0,
    shell: Shell,
    shader: *Shader,

    pub fn drawName(self: *BarData, font_shader: *Shader, shader: *Shader, logoSprite: *Sprite, font: *Font, window_list: *std.ArrayList(*Window)) !void {
        var pos = Rect{ .x = self.height, .y = self.screendims.y - self.height + 12, .w = self.screendims.x + self.height, .h = self.height };

        try font.draw(.{
            .shader = font_shader,
            .text = "APPS",
            .pos = pos.location(),
        });

        const ts = std.time.timestamp();
        const hours = @as(i64, @intCast(@as(u64, @intCast(ts)) / std.time.s_per_hour)) - config.SettingManager.instance.getInt("hours_offset");
        const mins = @as(i64, @intCast(@as(u64, @intCast(ts)) / std.time.s_per_min)) - config.SettingManager.instance.getInt("minutes_offset");
        const clock_text = try std.fmt.allocPrint(allocator.alloc, "{d: >2}:{d:0>2}", .{
            @as(u8, @intCast(@rem(hours, 24))),
            @as(u8, @intCast(@rem(mins, 60))),
        });
        defer allocator.alloc.free(clock_text);

        const clock_size = font.sizeText(.{ .text = clock_text });
        const clock_pos = Vec2{ .x = self.screendims.x - clock_size.x - 10, .y = pos.y };

        try font.draw(.{
            .shader = font_shader,
            .text = clock_text,
            .pos = clock_pos,
        });

        self.btns = 0;

        for (window_list.items) |window| {
            const color = if (window.data.min)
                Color{ .r = 0.5, .g = 0.5, .b = 0.5 }
            else
                Color{ .r = 0, .g = 0, .b = 0 };

            pos.x = 3 * self.height + 10 + 4 * (self.height * @as(f32, @floatFromInt(window.data.idx)));
            try font.draw(.{
                .shader = font_shader,
                .text = window.data.contents.props.info.name,
                .pos = pos.location(),
                .wrap = 4 * self.height - 16,
                .maxlines = 1,
                .color = color,
            });

            pos.x += 4 * self.height;
            self.btns += 1;
        }

        const apps = try getApps();
        defer allocator.alloc.free(apps);

        const total_height: f32 = @floatFromInt(apps.len * (ICON_SIZE + ICON_SPACE));

        if (self.btn_active) {
            try SpriteBatch.global.draw(Sprite, logoSprite, shader, .{ .x = 2, .y = self.screendims.y - total_height - 2 - self.height });

            for (apps, 0..) |app, i| {
                const icon_spr: Sprite = if (app.icon) |icn|
                    .override(icn, .{
                        .source = .{ .w = 1, .h = 1 },
                        .size = .{ .x = ICON_SIZE, .y = ICON_SIZE },
                    })
                else
                    .atlas("error", .{
                        .source = .{ .w = 1, .h = 1 },
                        .size = .{ .x = ICON_SIZE, .y = ICON_SIZE },
                    });
                const height = font.size * 1;
                const y = self.screendims.y - total_height - self.height + (ICON_SIZE + ICON_SPACE) * @as(f32, @floatFromInt(i));
                const text = app.name;
                const textpos = Vec2{ .x = 36 + ICON_SIZE + ICON_SPACE * 2, .y = y + std.math.floor((ICON_SIZE + ICON_SPACE - height) / 2) };
                const iconpos = Rect{ .x = 36, .y = y + 2, .w = ICON_SIZE, .h = ICON_SIZE };

                try SpriteBatch.global.draw(Sprite, &icon_spr, self.shader, .{ .x = iconpos.x, .y = iconpos.y });

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = textpos,
                });
            }
        }
    }

    pub fn getApps() ![]const Eln {
        const root = try files.FolderLink.resolve(.root);

        const file = root.getFile("conf/bar.cfg") catch return &.{};
        const apps = try root.getFolder("conf/apps");
        const list = try file.read(null);

        var iter = std.mem.splitScalar(u8, list, '\n');

        var result: []Eln = &.{};
        errdefer allocator.alloc.free(result);

        while (iter.next()) |eln_name| {
            const file_name = try std.fmt.allocPrint(allocator.alloc, "{s}.eln", .{eln_name});
            defer allocator.alloc.free(file_name);

            const eln_file = apps.getFile(file_name) catch continue;
            const eln_data = Eln.parse(eln_file) catch continue;
            result = try allocator.alloc.realloc(result, result.len + 1);
            result[result.len - 1] = eln_data;
        }

        return result;
    }

    pub fn doClick(self: *BarData, window_list: *std.ArrayList(*Window), shader: *Shader, pos: Vec2) !bool {
        _ = shader;
        const btn = Rect{ .y = self.screendims.y - self.height, .w = 3 * self.height, .h = self.height };

        var added = false;

        if (self.screendims.y - self.height <= pos.y) {
            var new_top: ?u32 = null;

            for (window_list.items, 0..) |window, idx| {
                const offset = 3 * self.height + 10 + 4 * (self.height * @as(f32, @floatFromInt(window.data.idx)));

                const button_bounds = Rect{ .x = offset, .y = self.screendims.y - self.height, .w = 4 * self.height, .h = self.height };

                if (button_bounds.contains(pos)) {
                    if (window.data.active or window.data.min) {
                        window.data.min = !window.data.min;
                    }
                    if (window.data.min) {
                        window.data.active = false;
                    } else {
                        window.data.active = true;
                        new_top = @as(u32, @intCast(idx));
                    }
                } else {
                    window.data.active = false;
                }
            }

            if (new_top) |top| {
                var swap = window_list.orderedRemove(@as(usize, @intCast(top)));
                try swap.data.contents.focus();
                try window_list.append(swap);
            }
        }

        const apps = try getApps();
        defer allocator.alloc.free(apps);

        const total_height: f32 = @floatFromInt(apps.len * (ICON_SIZE + ICON_SPACE));

        if (self.btn_active) {
            for (apps, 0..) |app, i| {
                const y = self.screendims.y - total_height - 2 - self.height + (ICON_SIZE + ICON_SPACE) * @as(f32, @floatFromInt(i));
                const item = Rect{ .x = 36, .y = y, .w = 160, .h = (ICON_SIZE + ICON_SPACE) };
                if (item.contains(pos)) {
                    added = true;
                    self.shell.root = .root;
                    try app.run(&self.shell, self.shader);
                }
            }
        }

        self.btn_active = !self.btn_active and btn.contains(pos);
        if (!btn.contains(pos)) {
            self.btn_active = false;
        }

        const bnds = Rect{ .y = self.screendims.y - self.height, .w = self.screendims.x, .h = self.height };

        return bnds.contains(pos) or added;
    }

    pub fn submitPopup(_: ?*files.File, _: *anyopaque) !void {
        c.glfwSetWindowShouldClose(graphics.gContext.window, 1);
    }

    pub fn getVerts(self: *const BarData, _: Vec3) !VertArray {
        var result = try VertArray.init(9 * 6 * 2);
        const pos = Rect{ .y = self.screendims.y - self.height, .w = self.screendims.x, .h = self.height };

        try result.appendUiQuad(pos, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = 0 },
            .draw_scale = 2,
            .borders = .{ .l = 3, .r = 3, .t = 3, .b = 3 },
        });

        const btn = Rect{ .y = self.screendims.y - self.height, .w = 3 * self.height, .h = self.height };

        try result.appendUiQuad(btn, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = 1 },
            .draw_scale = 2,
            .borders = .{ .l = 6, .r = 6, .t = 6, .b = 6 },
        });

        const icon = Rect{
            .x = btn.x + 3,
            .y = btn.y + 3,
            .w = btn.h - 6,
            .h = btn.h - 6,
        };

        try result.appendQuad(icon, .{ .y = 3.0 / TOTAL_SPRITES, .w = 1, .h = 1.0 / TOTAL_SPRITES }, .{});

        if (self.btn_active) {
            const apps = try getApps();
            defer allocator.alloc.free(apps);

            const total_height: f32 = @floatFromInt(apps.len * (ICON_SIZE + ICON_SPACE));

            const menu = Rect{ .y = self.screendims.y - total_height - 2 - self.height, .w = 300, .h = total_height + 2 };

            try result.appendUiQuad(menu, .{
                .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
                .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
                .sprite = .{ .y = 4 },
                .draw_scale = 2,
                .borders = .{ .l = 3, .r = 3, .t = 3, .b = 3 },
            });
        }

        for (0..@as(usize, @intCast(self.btns))) |i| {
            const b = Rect{ .x = self.height * @as(f32, @floatFromInt(i * 4 + 3)), .y = self.screendims.y - self.height, .w = 4 * self.height, .h = self.height };

            try result.appendUiQuad(b, .{
                .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
                .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
                .sprite = .{ .y = 1 },
                .draw_scale = 2,
                .borders = .{ .l = 6, .r = 6, .t = 6, .b = 6 },
            });
        }

        return result;
    }
};

pub const drawer = SpriteBatch.Drawer(BarData);
