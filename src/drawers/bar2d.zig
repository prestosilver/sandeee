const std = @import("std");
const batch = @import("../util/spritebatch.zig");
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
const conf = @import("../system/config.zig");
const events = @import("../util/events.zig");
const window_events = @import("../events/window.zig");
const shell = @import("../system/shell.zig");
const eln = @import("../util/eln.zig");

const TOTAL_SPRITES: f32 = 13;
const TEX_SIZE: f32 = 32;

pub const BarData = struct {
    screendims: *vecs.Vector2,
    height: f32,
    btn_active: bool = false,
    btns: i32 = 0,
    shell: shell.Shell,
    shader: *shd.Shader,

    inline fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle) !void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @as(f32, @floatFromInt(sprite));

        const color = .{ .r = 1, .g = 1, .b = 1 };

        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y + pos.h }, .{ .x = source.x + source.w, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y }, .{ .x = source.x, .y = source.y }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
    }

    fn addUiQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, scale: i32, r: f32, l: f32, t: f32, b: f32) !void {
        const sc = @as(f32, @floatFromInt(scale));

        try addQuad(arr, sprite, .{ .x = pos.x, .y = pos.y, .w = sc * l, .h = sc * t }, .{ .w = l / TEX_SIZE, .h = t / TEX_SIZE });
        try addQuad(arr, sprite, .{ .x = pos.x + sc * l, .y = pos.y, .w = pos.w - sc * (l + r), .h = sc * t }, .{ .x = l / TEX_SIZE, .w = (TEX_SIZE - l - r) / TEX_SIZE, .h = t / TEX_SIZE });
        try addQuad(arr, sprite, .{ .x = pos.x + pos.w - sc * r, .y = pos.y, .w = sc * r, .h = sc * t }, .{ .x = (TEX_SIZE - r) / TEX_SIZE, .w = r / TEX_SIZE, .h = t / TEX_SIZE });

        try addQuad(arr, sprite, .{ .x = pos.x, .y = pos.y + sc * t, .w = sc * l, .h = pos.h - sc * (t + b) }, .{ .y = t / TEX_SIZE, .w = l / TEX_SIZE, .h = (TEX_SIZE - t - b) / TEX_SIZE });
        try addQuad(arr, sprite, .{ .x = pos.x + sc * l, .y = pos.y + sc * t, .w = pos.w - sc * (l + r), .h = pos.h - sc * (t + b) }, .{ .x = l / TEX_SIZE, .y = t / TEX_SIZE, .w = (TEX_SIZE - l - r) / TEX_SIZE, .h = (TEX_SIZE - t - b) / TEX_SIZE });
        try addQuad(arr, sprite, .{ .x = pos.x + pos.w - sc * r, .y = pos.y + sc * t, .w = sc * r, .h = pos.h - sc * (t + b) }, .{ .x = (TEX_SIZE - r) / TEX_SIZE, .y = t / TEX_SIZE, .w = r / TEX_SIZE, .h = (TEX_SIZE - t - b) / TEX_SIZE });

        try addQuad(arr, sprite, .{ .x = pos.x, .y = pos.y + pos.h - sc * b, .w = sc * l, .h = sc * b }, .{ .y = (TEX_SIZE - b) / TEX_SIZE, .w = l / TEX_SIZE, .h = b / TEX_SIZE });
        try addQuad(arr, sprite, .{ .x = pos.x + sc * l, .y = pos.y + pos.h - sc * b, .w = pos.w - sc * (l + r), .h = sc * b }, .{ .x = l / TEX_SIZE, .y = (TEX_SIZE - b) / TEX_SIZE, .w = (TEX_SIZE - l - r) / TEX_SIZE, .h = b / TEX_SIZE });
        try addQuad(arr, sprite, .{ .x = pos.x + pos.w - sc * r, .y = pos.y + pos.h - sc * b, .w = sc * r, .h = sc * b }, .{ .x = (TEX_SIZE - r) / TEX_SIZE, .y = (TEX_SIZE - b) / TEX_SIZE, .w = r / TEX_SIZE, .h = b / TEX_SIZE });
    }

    pub fn drawName(self: *BarData, font_shader: *shd.Shader, shader: *shd.Shader, logoSprite: *spr.Sprite, font: *fnt.Font, windows: *std.ArrayList(win.Window)) !void {
        var pos = rect.Rectangle{ .x = self.height, .y = self.screendims.y - self.height + 12, .w = self.screendims.x + self.height, .h = self.height };

        try font.draw(.{
            .shader = font_shader,
            .text = "APPS",
            .pos = pos.location(),
        });

        const ts = std.time.timestamp();
        const hours = @as(i64, @intCast(@as(u64, @intCast(ts)) / std.time.s_per_hour)) - conf.SettingManager.instance.getInt("hours_offset");
        const mins = @as(i64, @intCast(@as(u64, @intCast(ts)) / std.time.s_per_min)) - conf.SettingManager.instance.getInt("minutes_offset");
        const clock_text = try std.fmt.allocPrint(allocator.alloc, "{d: >2}:{d:0>2}", .{
            @as(u8, @intCast(@rem(hours, 24))),
            @as(u8, @intCast(@rem(mins, 60))),
        });
        defer allocator.alloc.free(clock_text);

        const clock_size = font.sizeText(.{ .text = clock_text });
        const clock_pos = vecs.Vector2{ .x = self.screendims.x - clock_size.x - 10, .y = pos.y };

        try font.draw(.{
            .shader = font_shader,
            .text = clock_text,
            .pos = clock_pos,
        });

        self.btns = 0;

        for (windows.items) |window| {
            const color = if (window.data.min)
                cols.Color{ .r = 0.5, .g = 0.5, .b = 0.5 }
            else
                cols.Color{ .r = 0, .g = 0, .b = 0 };

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

        if (self.btn_active) {
            try batch.SpriteBatch.instance.draw(spr.Sprite, logoSprite, shader, .{ .x = 2, .y = self.screendims.y - 464 - self.height });

            for (apps, 0..) |app, i| {
                const icon_spr = if (app.icon) |icn|
                    spr.Sprite{
                        .texture = &.{ 'e', 'l', 'n', @as(u8, @intCast(icn)) },
                        .data = .{
                            .source = .{ .w = 1, .h = 1 },
                            .size = .{ .x = 64, .y = 64 },
                        },
                    }
                else
                    spr.Sprite{
                        .texture = "error",
                        .data = .{
                            .source = .{ .w = 1, .h = 1 },
                            .size = .{ .x = 64, .y = 64 },
                        },
                    };
                const height = font.size * 1;
                const y = self.screendims.y - 466 - self.height + 67 * @as(f32, @floatFromInt(i));
                const text = app.name;
                const textpos = vecs.Vector2{ .x = 100, .y = y + std.math.floor((67 - height) / 2) };
                const iconpos = rect.Rectangle{ .x = 36, .y = y + 2, .w = 64, .h = 64 };

                try batch.SpriteBatch.instance.draw(spr.Sprite, &icon_spr, self.shader, .{ .x = iconpos.x, .y = iconpos.y });

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = textpos,
                });
            }
        }
    }

    pub fn getApps() ![]const eln.ElnData {
        const file = files.root.getFile("conf/bar.cfg") catch return &.{};
        const apps = try files.root.getFolder("conf/apps");
        const list = try file.read(null);

        var iter = std.mem.split(u8, list, "\n");

        var result = try allocator.alloc.alloc(eln.ElnData, 0);
        errdefer allocator.alloc.free(result);

        while (iter.next()) |eln_name| {
            const file_name = try std.fmt.allocPrint(allocator.alloc, "{s}.eln", .{eln_name});
            defer allocator.alloc.free(file_name);

            const eln_file = apps.getFile(file_name) catch continue;
            const eln_data = eln.ElnData.parse(eln_file) catch continue;
            result = try allocator.alloc.realloc(result, result.len + 1);
            result[result.len - 1] = eln_data;
        }

        return result;
    }

    pub fn doClick(self: *BarData, windows: *std.ArrayList(win.Window), shader: *shd.Shader, pos: vecs.Vector2) !bool {
        _ = shader;
        const btn = rect.Rectangle{ .y = self.screendims.y - self.height, .w = 3 * self.height, .h = self.height };

        var added = false;

        if (self.screendims.y - self.height <= pos.y) {
            var new_top: ?u32 = null;

            for (windows.items, 0..) |*window, idx| {
                const offset = 3 * self.height + 10 + 4 * (self.height * @as(f32, @floatFromInt(window.data.idx)));

                const button_bounds = rect.Rectangle{ .x = offset, .y = self.screendims.y - self.height, .w = 4 * self.height, .h = self.height };

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
                var swap = windows.orderedRemove(@as(usize, @intCast(top)));
                try swap.data.contents.focus();
                try windows.append(swap);
            }
        }

        const apps = try getApps();
        defer allocator.alloc.free(apps);

        if (self.btn_active) {
            for (apps, 0..) |app, i| {
                const y = self.screendims.y - 466 - self.height + 67 * @as(f32, @floatFromInt(i));
                const item = rect.Rectangle{ .x = 36, .y = y, .w = 160, .h = 67 };
                if (item.contains(pos)) {
                    added = true;
                    self.shell.root = files.root;
                    try app.run(&self.shell, self.shader);
                }
            }
        }

        self.btn_active = !self.btn_active and btn.contains(pos);
        if (!btn.contains(pos)) {
            self.btn_active = false;
        }

        const bnds = rect.Rectangle{ .y = self.screendims.y - self.height, .w = self.screendims.x, .h = self.height };

        return bnds.contains(pos) or added;
    }

    pub fn submitPopup(_: ?*files.File, _: *anyopaque) !void {
        c.glfwSetWindowShouldClose(gfx.gContext.window, 1);
    }

    pub fn getVerts(self: *const BarData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(9 * 6 * 2);
        const pos = rect.Rectangle{ .y = self.screendims.y - self.height, .w = self.screendims.x, .h = self.height };

        try addUiQuad(&result, 0, pos, 2, 3, 3, 3, 3);

        const btn = rect.Rectangle{ .y = self.screendims.y - self.height, .w = 3 * self.height, .h = self.height };
        try addUiQuad(&result, 1, btn, 2, 6, 6, 6, 6);

        const icon = rect.Rectangle{
            .x = btn.x + 3,
            .y = btn.y + 3,
            .w = btn.h - 6,
            .h = btn.h - 6,
        };

        try addQuad(&result, 3, icon, .{ .w = 1, .h = 1 });

        if (self.btn_active) {
            const menu = rect.Rectangle{ .y = self.screendims.y - 466 - self.height, .w = 300, .h = 466 };

            try addUiQuad(&result, 4, menu, 2, 3, 3, 3, 3);
        }

        for (0..@as(usize, @intCast(self.btns))) |i| {
            const b = rect.Rectangle{ .x = self.height * @as(f32, @floatFromInt(i * 4 + 3)), .y = self.screendims.y - self.height, .w = 4 * self.height, .h = self.height };
            try addUiQuad(&result, 1, b, 2, 6, 6, 6, 6);
        }

        return result;
    }
};

pub const Bar = batch.Drawer(BarData);
