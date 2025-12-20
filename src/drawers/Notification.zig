const std = @import("std");
const c = @import("../c.zig");

const drawers = @import("../drawers.zig");
const util = @import("../util.zig");
const math = @import("../math.zig");

const Sprite = drawers.Sprite;
const Window = drawers.Window;

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;

const TOTAL_SPRITES: f32 = 1;
const TEX_SIZE: f32 = 32;

pub const NotificationData = struct {
    time: f32 = 3.0,
    icon: ?Sprite,
    title: []const u8,
    text: []const u8,
    source: Rect = .{ .w = 1, .h = 1 },
    color: Color = .{ .r = 1, .g = 1, .b = 1 },

    pub fn update(self: *NotificationData, dt: f32) !void {
        self.time = @max(@as(f32, 0), self.time - dt);
    }

    pub fn getVerts(_: *const NotificationData, pos: Vec3) !VertArray {
        const target2d = graphics.Context.instance.size.sub(.{ .x = 260, .y = 100 + 80 * pos.x });

        var result = try VertArray.init(9 * 6);

        const targetpos = Vec3{ .x = target2d.x, .y = target2d.y };

        try result.appendQuad(.{ .x = targetpos.x, .y = targetpos.y, .w = 250, .h = 70 }, .{
            .x = 2.0 / 8.0,
            .y = 0.0,
            .w = 1.0 / 8.0,
            .h = 1.0 / 8.0 / TOTAL_SPRITES,
        }, .{});

        try result.appendQuad(.{ .x = targetpos.x + 2, .y = targetpos.y + 2, .w = 250 - 4, .h = 70 - 4 }, .{
            .x = 3.0 / 8.0,
            .y = 0.0,
            .w = 1.0 / 8.0,
            .h = 1.0 / 8.0 / TOTAL_SPRITES,
        }, .{});

        return result;
    }

    pub fn drawContents(self: *NotificationData, shader: *Shader, font: *Font, font_shader: *Shader, idx: usize) !void {
        const desk_size = graphics.Context.instance.size;

        if (self.icon) |*icon| {
            icon.data.size.x = 60;
            icon.data.size.y = 60;

            const pos = desk_size.sub(.{ .x = 255, .y = 95 + 80 * @as(f32, @floatFromInt(idx)) });

            try SpriteBatch.global.draw(Sprite, icon, shader, .{ .x = pos.x, .y = pos.y });
        }

        try font.draw(.{
            .shader = font_shader,
            .text = self.title,
            .pos = desk_size.sub(.{ .x = 180, .y = 100 + 80 * @as(f32, @floatFromInt(idx)) }),
            .color = .{ .r = 0, .g = 0, .b = 0 },
            .wrap = 160,
            .maxlines = 1,
        });

        try font.draw(.{
            .shader = font_shader,
            .text = self.text,
            .pos = desk_size.sub(.{ .x = 180, .y = 100 - font.size + 80 * @as(f32, @floatFromInt(idx)) }),
            .color = .{ .r = 0, .g = 0, .b = 0 },
            .wrap = 160,
            .maxlines = 3,
        });
    }
};

pub const drawer = SpriteBatch.Drawer(NotificationData);
