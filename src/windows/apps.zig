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
const texMan = @import("../util/texmanager.zig");
const eln = @import("../util/eln.zig");

const log = @import("../util/log.zig").log;

const SCROLL = 30;
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
    lastAction: ?LauncherMouseAction = null,

    icon_data: []const eln.ElnData,
    idx: u8,

    max_sprites: u8 = 0,

    pub fn getIcons(self: *Self) ![]const eln.ElnData {
        const folder = files.root.getFolder("conf/apps") catch
            return &.{};

        const subFiles = try folder.getFiles();
        defer allocator.alloc.free(subFiles);

        const result = try allocator.alloc.alloc(eln.ElnData, subFiles.len);

        for (subFiles, 0..) |file, idx| {
            result[idx] = try eln.ElnData.parse(file);
        }

        self.max_sprites = @max(self.max_sprites, @as(u8, @intCast(subFiles.len)));

        return result;
    }

    pub fn refresh(self: *Self) !void {
        allocator.alloc.free(self.icon_data);
        self.icon_data = try self.getIcons();
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 0,
            };
        }
        if (self.lastAction != null) {
            if (self.lastAction.?.time <= 0) {
                self.lastAction = null;
            } else {
                self.lastAction.?.time -= 5;
            }
        }

        if (self.shell.vm != null) {
            const result = self.shell.getVMResult() catch null;
            if (result != null) {
                allocator.alloc.free(result.?.data);
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
                    .pos = vecs.newVec2(bnds.x + x + xo - 14, bnds.y + 64 + y + 6),
                    .color = col.newColor(0, 0, 0, 1),
                    .wrap = 100,
                    .maxlines = 1,
                });

                const icon_spr =
                    if (icon.icon) |icn|
                    sprite.Sprite.new(&.{ 'e', 'l', 'n', @as(u8, @intCast(icn)) }, sprite.SpriteData.new(
                        rect.newRect(0, 0, 1, 1),
                        vecs.newVec2(64, 64),
                    ))
                else
                    sprite.Sprite.new("error", sprite.SpriteData.new(
                        rect.newRect(0, 0, 1, 1),
                        vecs.newVec2(64, 64),
                    ));

                try batch.SpriteBatch.instance.draw(sprite.Sprite, &icon_spr, self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

                if (idx + 1 == self.selected)
                    try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));
            }

            if (self.lastAction != null) {
                if (rect.newRect(x + 2 + 16, y + 2, 64, 64).contains(self.lastAction.?.pos)) {
                    switch (self.lastAction.?.kind) {
                        .SingleLeft => {
                            self.selected = idx + 1;
                        },
                        .DoubleLeft => {
                            _ = self.shell.runBg(icon.launches) catch {
                                //TODO: popup
                            };
                            self.lastAction = null;
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

    pub fn deinit(self: *Self) !void {
        // TODO: deinit textures

        // deinit rest
        try self.shell.deinit();
        allocator.alloc.free(self.icon_data);
        allocator.alloc.destroy(self);
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (self.shell.vm != null) return;
        if (btn == null) return;

        switch (btn.?) {
            0 => {
                if (self.lastAction != null and mousepos.distSq(self.lastAction.?.pos) < 100) {
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

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) void {
        if (self.shell.vm != null) return;
        if (!down) return;

        switch (keycode) {
            else => {},
        }
    }
};

pub fn new(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(LauncherData);

    self.* = .{
        .icon_data = try allocator.alloc.alloc(eln.ElnData, 0),
        .idx = g_idx,

        .gray = sprite.Sprite.new("ui", sprite.SpriteData.new(
            rect.newRect(3.0 / 8.0, 4.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(72.0, 72.0),
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
                vecs.newVec2(2.0, 28.0),
            )),
        },
        .sel = sprite.Sprite.new("big_icons", sprite.SpriteData.new(
            rect.newRect(2.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(64.0, 64.0),
        )),
        .shader = shader,
        .shell = .{
            .root = files.home,
            .vm = null,
        },
    };

    g_idx += 1;

    return win.WindowContents.init(self, "launcher", "Launcher", col.newColor(1, 1, 1, 1));
}
