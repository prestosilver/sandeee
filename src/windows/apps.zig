const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const batch = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../util/texture.zig");
const c = @import("../c.zig");
const shell = @import("../system/shell.zig");
const conf = @import("../system/config.zig");
const texture_manager = @import("../util/texmanager.zig");
const eln = @import("../util/eln.zig");

const log = @import("../util/log.zig").log;

var g_idx: u8 = 0;

pub const LauncherData = struct {
    const Self = @This();

    const LauncherMouseActionType = enum {
        SingleLeft,
        DoubleLeft,
    };

    const LauncherMouseAction = struct {
        kind: LauncherMouseActionType,
        pos: vecs.Vector2,
        time: f32,
    };

    shader: *shd.Shader,
    text_box: [2]sprite.Sprite,
    menubar: sprite.Sprite,
    sel: sprite.Sprite,
    gray: sprite.Sprite,
    shell: shell.Shell,

    focused: ?u64 = null,
    selected: usize = 0,
    last_action: ?LauncherMouseAction = null,

    icon_data: []const eln.ElnData = &.{},
    idx: u8,

    max_sprites: u8 = 0,

    pub fn getIcons(self: *Self) ![]const eln.ElnData {
        const folder = files.root.getFolder("conf/apps") catch
            return &.{};

        const sub_files = try folder.getFiles();
        defer allocator.alloc.free(sub_files);

        const result = try allocator.alloc.alloc(eln.ElnData, sub_files.len);

        for (sub_files, 0..) |file, idx| {
            result[idx] = try eln.ElnData.parse(file);
        }

        self.max_sprites = @max(self.max_sprites, @as(u8, @intCast(sub_files.len)));

        return result;
    }

    pub fn refresh(self: *Self) !void {
        allocator.alloc.free(self.icon_data);
        self.icon_data = try self.getIcons();
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 0,
            };
        }

        if (self.last_action) |*last_action| {
            if (last_action.time <= 0) {
                self.last_action = null;
            } else {
                last_action.time -= 5;
            }
        }

        if (self.shell.vm) |_| {
            const result = self.shell.getVMResult() catch null;
            if (result) |result_data| {
                allocator.alloc.free(result_data.data);
            }
        }

        var x: f32 = 0;
        var y: f32 = -props.scroll.?.value + 0;

        const hidden = conf.SettingManager.instance.getBool("explorer_hidden");

        for (self.icon_data, 0..) |icon, idx| {
            if (icon.name.len == 0) continue;
            if (!hidden and icon.name[0] == '_') continue;

            const size = font.sizeText(.{
                .text = icon.name,
                .wrap = 100,
            }).x;
            const xo = (128 - size) / 2;

            if (y + 64 + font.size > 0 and y < bnds.h) {
                try font.draw(.{
                    .shader = font_shader,
                    .text = icon.name,
                    .pos = .{ .x = bnds.x + x + xo - 14, .y = bnds.y + 64 + y + 6 },
                    .color = .{ .r = 0, .g = 0, .b = 0 },
                    .wrap = 100,
                    .maxlines = 1,
                });

                const icon_spr =
                    if (icon.icon) |icn| sprite.Sprite{
                    .texture = &.{ 'e', 'l', 'n', @as(u8, @intCast(icn)) },
                    .data = .{
                        .source = .{ .w = 1, .h = 1 },
                        .size = .{ .x = 64, .y = 64 },
                    },
                } else sprite.Sprite{
                    .texture = "error",
                    .data = .{
                        .source = .{ .w = 1, .h = 1 },
                        .size = .{ .x = 64, .y = 64 },
                    },
                };

                try batch.SpriteBatch.instance.draw(sprite.Sprite, &icon_spr, self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if (idx + 1 == self.selected)
                    try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.sel, self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });
            }

            if (self.last_action) |last_action| {
                if ((rect.Rectangle{ .x = x + 2 + 16, .y = y + 2, .w = 64, .h = 64 }).contains(last_action.pos)) {
                    switch (last_action.kind) {
                        .SingleLeft => {
                            self.selected = idx + 1;
                        },
                        .DoubleLeft => {
                            try icon.run(&self.shell, self.shader);

                            self.last_action = null;
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
    }

    pub fn deinit(self: *Self) void {
        // TODO: deinit textures

        // deinit rest
        self.shell.deinit();
        allocator.alloc.free(self.icon_data);
        allocator.alloc.destroy(self);
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (self.shell.vm != null) return;
        if (btn == null) return;

        switch (btn.?) {
            0 => {
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
        if (self.shell.vm != null) return;
        if (!down) return;

        switch (keycode) {
            else => {},
        }
    }
};

pub fn init(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(LauncherData);

    self.* = .{
        .idx = g_idx,

        .gray = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 72, .y = 72 },
            },
        },
        .menubar = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
                .size = .{ .y = 40.0 },
            },
        },
        .text_box = .{
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2.0, .y = 32.0 },
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2.0, .y = 28.0 },
                },
            },
        },
        .sel = .{
            .texture = "big_icons",
            .data = .{
                .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 64.0, .y = 64.0 },
            },
        },
        .shader = shader,
        .shell = .{
            .root = files.home,
            .vm = null,
        },
    };

    g_idx += 1;

    return win.WindowContents.init(self, "launcher", "Launcher", .{ .r = 1, .g = 1, .b = 1 });
}
