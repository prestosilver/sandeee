const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const batch = @import("../../util/spritebatch.zig");
const spr = @import("../../drawers/sprite2d.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const events = @import("../../util/events.zig");
const window_events = @import("../../events/window.zig");
const popups = @import("../../drawers/popup2d.zig");
const c = @import("../../c.zig");

pub const PopupTextPick = struct {
    const Self = @This();

    text: []u8,
    submit: *const fn ([]u8, *anyopaque) anyerror!void,
    err: []const u8 = "",
    prompt: []const u8,
    data: *anyopaque,

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        try font.draw(.{
            .shader = shader,
            .pos = bnds.location(),
            .text = self.prompt,
        });

        const maxlen: usize = @intFromFloat((bnds.w - 60) / font.sizeText(.{
            .text = "A",
        }).x);

        const text = if (self.text.len > maxlen)
            try std.fmt.allocPrint(allocator.alloc, fnt.DOTS ++ "{s}", .{self.text[self.text.len - maxlen + 1 ..]})
        else
            try allocator.alloc.dupe(u8, self.text);
        defer allocator.alloc.free(text);

        const text_background = spr.Sprite.new("ui", spr.SpriteData.new(
            rect.newRect(2.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            .{
                .x = bnds.w - 60,
                .y = 32,
            },
        ));

        const text_foreground = spr.Sprite.new("ui", spr.SpriteData.new(
            rect.newRect(3.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            .{
                .x = bnds.w - 64,
                .y = 28,
            },
        ));

        try batch.SpriteBatch.instance.draw(spr.Sprite, &text_background, popups.popup_shader, vecs.newVec3(bnds.x + 28, bnds.y + font.size * 2 - 4, 0));
        try batch.SpriteBatch.instance.draw(spr.Sprite, &text_foreground, popups.popup_shader, vecs.newVec3(bnds.x + 30, bnds.y + font.size * 2 - 2, 0));

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 30, .y = font.size * 2 }),
            .text = text,
            .wrap = bnds.w - 60,
            .maxlines = 1,
        });

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 0, .y = font.size * 4 }),
            .text = self.err,
            .wrap = bnds.w - 60,
            .color = cols.newColor(1, 0, 0, 1),
        });
    }

    pub fn key(self: *Self, keycode: c_int, _: c_int, down: bool) !void {
        if (!down) return;

        if (keycode == c.GLFW_KEY_BACKSPACE and self.text.len != 0) {
            self.text = try allocator.alloc.realloc(self.text, self.text.len - 1);
            self.err = "";
        }

        if (keycode == c.GLFW_KEY_ENTER) {
            self.submit(self.text, self.data) catch |err| {
                self.err = @errorName(err);
                return;
            };

            try events.EventManager.instance.sendEvent(window_events.EventClosePopup{
                .popup_conts = self,
            });
        }
    }

    pub fn char(self: *Self, keycode: u32, _: i32) !void {
        if (keycode < 256) {
            self.err = "";

            self.text = try allocator.alloc.realloc(self.text, self.text.len + 1);
            self.text[self.text.len - 1] = @as(u8, @intCast(keycode));
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.free(self.text);
        allocator.alloc.destroy(self);
    }
};
