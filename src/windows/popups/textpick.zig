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

    submit: *const fn ([]u8, *anyopaque) anyerror!void,

    err: ?[]const u8 = null,

    text: []u8,
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
            .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .{
                .x = bnds.w - 60,
                .y = 32,
            },
        ));

        const text_foreground = spr.Sprite.new("ui", spr.SpriteData.new(
            .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .{
                .x = bnds.w - 64,
                .y = 28,
            },
        ));

        try batch.SpriteBatch.instance.draw(spr.Sprite, &text_background, popups.popup_shader, .{ .x = bnds.x + 28, .y = bnds.y + font.size * 2 - 4 });
        try batch.SpriteBatch.instance.draw(spr.Sprite, &text_foreground, popups.popup_shader, .{ .x = bnds.x + 30, .y = bnds.y + font.size * 2 - 2 });

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 30, .y = font.size * 2 }),
            .text = text,
            .wrap = bnds.w - 60,
            .maxlines = 1,
        });

        if (self.err) |err|
            try font.draw(.{
                .shader = shader,
                .pos = bnds.location().add(.{ .x = 0, .y = font.size * 4 }),
                .text = err,
                .wrap = bnds.w - 60,
                .color = .{ .r = 1, .g = 0, .b = 0 },
            });
    }

    pub fn key(self: *Self, keycode: c_int, _: c_int, down: bool) !void {
        if (!down) return;

        if (keycode == c.GLFW_KEY_BACKSPACE and self.text.len != 0) {
            self.text = try allocator.alloc.realloc(self.text, self.text.len - 1);
            if (self.err) |err|
                allocator.alloc.free(err);
            self.err = null;
        }

        if (keycode == c.GLFW_KEY_ENTER) {
            self.submit(self.text, self.data) catch |err| {
                if (self.err) |err_i|
                    allocator.alloc.free(err_i);
                self.err = try allocator.alloc.dupe(u8, @errorName(err));
                return;
            };

            try events.EventManager.instance.sendEvent(window_events.EventClosePopup{
                .popup_conts = self,
            });
        }
    }

    pub fn char(self: *Self, keycode: u32, _: i32) !void {
        if (keycode < 256) {
            if (self.err) |err|
                allocator.alloc.free(err);
            self.err = null;

            self.text = try allocator.alloc.realloc(self.text, self.text.len + 1);
            self.text[self.text.len - 1] = @as(u8, @intCast(keycode));
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.err) |err|
            allocator.alloc.free(err);

        allocator.alloc.free(self.prompt);
        allocator.alloc.free(self.text);
        allocator.alloc.destroy(self);
    }
};
