const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const batch = @import("../../util/spritebatch.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const events = @import("../../util/events.zig");
const windowEvs = @import("../../events/window.zig");
const c = @import("../../c.zig");

pub const PopupConfirm = struct {
    const Self = @This();

    message: []const u8,
    buttons: [][]const u8,

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        try font.draw(.{
            .shader = shader,
            .pos = bnds.location(),
            .text = self.message,
        });

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 30, .y = font.size }),
            .text = self.path,
            .wrap = bnds.w - 60,
            .maxlines = 1,
        });

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 0, .y = font.size * 2 }),
            .text = self.err,
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
            if (try files.root.getFolder(self.path)) |folder| {
                try self.submit(folder, self.data);
                events.em.sendEvent(windowEvs.EventClosePopup{});
            }
        }
    }

    pub fn char(_: *Self, _: u32, _: i32) !void {}

    pub fn click(_: *Self, _: vecs.Vector2) !void {}

    pub fn deinit(self: *Self) !void {
        allocator.alloc.free(self.path);
        allocator.alloc.destroy(self);
    }
};
