const std = @import("std");
const c = @import("../c.zig");

const Windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Eln = util.Eln;
const allocator = util.allocator;
const log = util.log;

const Shell = system.Shell;
const config = system.config;
const files = system.files;

var g_idx: u8 = 0;

pub const LauncherData = struct {
    const Self = @This();

    shader: *Shader,
    text_box: [2]Sprite,
    menubar: Sprite,
    sel: Sprite,
    gray: Sprite,
    shell: Shell,

    focused: ?u64 = null,
    selected: ?usize = null,
    hover_idx: ?usize = null,
    mousepos: Vec2 = .{},

    icon_data: []const Eln = &.{},
    idx: u8,

    max_sprites: u8 = 0,

    pub fn getIcons(self: *Self) ![]const Eln {
        const root = try files.FolderLink.resolve(.root);
        const folder = root.getFolder("conf/apps") catch return &.{};

        var result: std.array_list.Managed(Eln) = .init(allocator);
        defer result.deinit();

        var sub_file = try folder.getFiles();
        while (sub_file) |file| : (sub_file = file.next_sibling) {
            try result.append(try Eln.parse(file));
        }

        self.max_sprites = @max(self.max_sprites, @as(u8, @intCast(result.items.len)));

        return try allocator.dupe(Eln, result.items);
    }

    pub fn refresh(self: *Self) !void {
        allocator.free(self.icon_data);
        self.icon_data = try self.getIcons();
    }

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 0,
            };
        }

        if (self.shell.vm) |_| {
            const result = self.shell.getVMResult() catch null;
            if (result) |result_data| {
                allocator.free(result_data.data);
            }
        }

        var x: f32 = 0;
        var y: f32 = -props.scroll.?.value + 0;

        const hidden = config.SettingManager.instance.getBool("explorer_hidden") orelse false;

        self.hover_idx = null;
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

                const icon_spr: Sprite = if (icon.icon) |icn|
                    .override(icn, .{
                        .source = .{ .w = 1, .h = 1 },
                        .size = .{ .x = 64, .y = 64 },
                    })
                else
                    .atlas("error", .{
                        .source = .{ .w = 1, .h = 1 },
                        .size = .{ .x = 64, .y = 64 },
                    });

                try SpriteBatch.global.draw(Sprite, &icon_spr, self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                if (idx == self.selected)
                    try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });
            }

            if ((Rect{ .x = x + 2 + 16, .y = y + 2, .w = 64, .h = 64 }).contains(self.mousepos)) {
                self.hover_idx = idx;
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
        allocator.free(self.icon_data);
        allocator.destroy(self);
    }

    pub fn move(self: *Self, x: f32, y: f32) void {
        self.mousepos = .{ .x = x, .y = y };
    }

    pub fn click(self: *Self, _: Vec2, _: Vec2, btn: i32, kind: events.input.ClickKind) !void {
        if (self.shell.vm != null) return;
        if (kind == .down or kind == .up) return;

        if (btn == 0 and kind == .single) {
            self.selected = self.hover_idx;
        } else if (btn == 0 and kind == .double) {
            if (self.hover_idx) |hover_idx|
                try self.icon_data[hover_idx].run(&self.shell, self.shader);

            self.selected = null;
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

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(LauncherData);

    self.* = .{
        .idx = g_idx,

        .gray = .atlas("ui", .{
            .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 72, .y = 72 },
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
        .sel = .atlas("big_icons", .{
            .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 64.0, .y = 64.0 },
        }),
        .shader = shader,
        .shell = .{
            .root = .home,
            .vm = null,
        },
    };

    g_idx += 1;

    return .init(self, "launcher", "Launcher", .{ .r = 1, .g = 1, .b = 1 });
}
