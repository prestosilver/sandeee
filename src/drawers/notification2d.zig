const batch = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");
const spr = @import("sprite2d.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");
const wins = @import("window2d.zig");
const gfx = @import("../util/graphics.zig");

const TOTAL_SPRITES = 1;
const TEX_SIZE: f32 = 32;

pub const NotificationData = struct {
    time: f32 = 3.0,
    icon: ?spr.Sprite,
    title: []const u8,
    text: []const u8,
    source: rect.Rectangle = rect.newRect(0, 0, 1, 1),
    color: cols.Color = cols.newColor(1, 1, 1, 1),

    inline fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle, color: cols.Color) !void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @as(f32, @floatFromInt(sprite));

        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
    }

    pub fn update(self: *NotificationData, dt: f32) !void {
        self.time = @max(@as(f32, 0), self.time - dt);
    }

    pub fn getVerts(self: *const NotificationData, pos: vecs.Vector3) !va.VertArray {
        _ = self;
        const target2d = gfx.Context.instance.size.sub(.{ .x = 260, .y = 100 + 80 * pos.x });

        var result = try va.VertArray.init(9 * 6);

        const targetpos = vecs.newVec3(target2d.x, target2d.y, 0);

        try addQuad(&result, 0, rect.newRect(targetpos.x, targetpos.y, 250, 70), rect.newRect(2.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0), cols.newColor(1, 1, 1, 1));
        try addQuad(&result, 0, rect.newRect(targetpos.x + 2, targetpos.y + 2, 250 - 4, 70 - 4), rect.newRect(3.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0), cols.newColor(1, 1, 1, 1));

        return result;
    }

    pub fn drawContents(self: *NotificationData, shader: *shd.Shader, font: *fnt.Font, font_shader: *shd.Shader, idx: usize) !void {
        const deskSize = gfx.Context.instance.size;

        if (self.icon) |*icon| {
            icon.data.size.x = 60;
            icon.data.size.y = 60;

            const pos = deskSize.sub(.{ .x = 255, .y = 95 + 80 * @as(f32, @floatFromInt(idx)) });

            try batch.SpriteBatch.instance.draw(
                spr.Sprite,
                icon,
                shader,
                vecs.newVec3(pos.x, pos.y, 0),
            );
        }

        try font.draw(.{
            .shader = font_shader,
            .text = self.title,
            .pos = deskSize.sub(.{ .x = 180, .y = 100 + 80 * @as(f32, @floatFromInt(idx)) }),
            .color = cols.newColor(0, 0, 0, 1),
            .wrap = 160,
            .maxlines = 1,
        });

        try font.draw(.{
            .shader = font_shader,
            .text = self.text,
            .pos = deskSize.sub(.{ .x = 180, .y = 100 - font.size + 80 * @as(f32, @floatFromInt(idx)) }),
            .color = cols.newColor(0, 0, 0, 1),
            .wrap = 160,
            .maxlines = 3,
        });
    }
};

pub const Notification = batch.Drawer(NotificationData);
