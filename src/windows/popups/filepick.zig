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
const windowEvs = @import("../../events/window.zig");
const popups = @import("../../drawers/popup2d.zig");
const c = @import("../../c.zig");

pub const PopupFilePick = struct {
    const Self = @This();

    path: []u8,
    submit: *const fn (?*files.File, *anyopaque) anyerror!void,
    err: []const u8 = "",
    data: *anyopaque,

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        try font.draw(.{
            .shader = shader,
            .pos = bnds.location(),
            .text = "Enter the files path:",
        });

        const maxlen: usize = @intFromFloat((bnds.w - 60) / font.sizeText(.{
            .text = "A",
        }).x);

        const text = if (self.path.len > maxlen)
            try std.fmt.allocPrint(allocator.alloc, "\x90{s}", .{self.path[self.path.len - maxlen + 1 ..]})
        else
            try allocator.alloc.dupe(u8, self.path);
        defer allocator.alloc.free(text);

        const textbgSprite = spr.Sprite.new("ui", spr.SpriteData.new(
            rect.newRect(2.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            .{
                .x = bnds.w - 60,
                .y = 32,
            },
        ));

        const textfgSprite = spr.Sprite.new("ui", spr.SpriteData.new(
            rect.newRect(3.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            .{
                .x = bnds.w - 64,
                .y = 28,
            },
        ));

        try batch.SpriteBatch.instance.draw(spr.Sprite, &textbgSprite, popups.popupShader, vecs.newVec3(bnds.x + 28, bnds.y + font.size * 2 - 4, 0));
        try batch.SpriteBatch.instance.draw(spr.Sprite, &textfgSprite, popups.popupShader, vecs.newVec3(bnds.x + 30, bnds.y + font.size * 2 - 2, 0));

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

        if (keycode == c.GLFW_KEY_BACKSPACE and self.path.len != 0) {
            self.path = try allocator.alloc.realloc(self.path, self.path.len - 1);
            self.err = "";
        }

        if (keycode == c.GLFW_KEY_ENTER) {
            const file = files.root.getFile(self.path) catch {
                self.err = "File Not Found";
                return;
            };

            try self.submit(file, self.data);
            try events.EventManager.instance.sendEvent(windowEvs.EventClosePopup{
                .popup_conts = self,
            });
        }
    }

    pub fn char(self: *Self, keycode: u32, _: i32) !void {
        if (keycode < 256) {
            self.err = "";

            self.path = try allocator.alloc.realloc(self.path, self.path.len + 1);
            self.path[self.path.len - 1] = @as(u8, @intCast(keycode));
        }
    }

    pub fn deinit(self: *Self) !void {
        allocator.alloc.free(self.path);
        allocator.alloc.destroy(self);
    }
};
