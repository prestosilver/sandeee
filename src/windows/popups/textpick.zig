const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const sb = @import("../../util/spritebatch.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const events = @import("../../util/events.zig");
const windowEvs = @import("../../events/window.zig");
const c = @import("../../c.zig");

pub const PopupTextPick = struct {
    const Self = @This();

    text: []u8,
    submit: *const fn ([]u8, *anyopaque) anyerror!void,
    err: []const u8 = "",
    prompt: []const u8,
    data: *anyopaque,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        try font.draw(.{
            .batch = batch,
            .shader = shader,
            .pos = bnds.location(),
            .text = self.prompt,
        });

        try font.draw(.{
            .batch = batch,
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 30, .y = font.size }),
            .text = self.text,
            .wrap = bnds.w - 60,
            .maxlines = 1,
        });

        try font.draw(.{
            .batch = batch,
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 0, .y = font.size * 2 }),
            .text = self.err,
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
            try self.submit(self.text, self.data);
            events.em.sendEvent(windowEvs.EventClosePopup{});
        }
    }

    pub fn char(self: *Self, keycode: u32, _: i32) !void {
        if (keycode < 256) {
            self.err = "";

            self.text = try allocator.alloc.realloc(self.text, self.text.len + 1);
            self.text[self.text.len - 1] = @intCast(u8, keycode);
        }
    }

    pub fn deinit(self: *Self) !void {
        allocator.alloc.free(self.text);
        allocator.alloc.destroy(self);
    }
};
