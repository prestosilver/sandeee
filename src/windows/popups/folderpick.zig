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

pub const PopupFolderPick = struct {
    const Self = @This();

    path: []u8,
    submit: *const fn (?*files.Folder, *anyopaque) anyerror!void,
    err: []const u8 = "",
    data: *anyopaque,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        try font.draw(.{
            .batch = batch,
            .shader = shader,
            .pos = bnds.location(),
            .text = "Enter the files path:",
        });

        const maxlen: usize = @intFromFloat((bnds.w - 120) / 10);

        const text = if (self.path.len > maxlen)
            try std.fmt.allocPrint(allocator.alloc, "\x90{s}", .{self.path[self.path.len - maxlen + 1 ..]})
        else
            try allocator.alloc.dupe(u8, self.path);
        defer allocator.alloc.free(text);

        try font.draw(.{
            .batch = batch,
            .shader = shader,
            .pos = bnds.location().add(.{ .x = 30, .y = font.size * 2 }),
            .text = text,
            .wrap = bnds.w - 60,
            .maxlines = 1,
        });

        try font.draw(.{
            .batch = batch,
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
            if (try files.root.getFolder(self.path)) |folder| {
                try self.submit(folder, self.data);
                events.em.sendEvent(windowEvs.EventClosePopup{});
            } else {
                self.err = "Folder Not Found";
            }
        }
    }

    pub fn char(self: *Self, keycode: u32, _: i32) !void {
        if (keycode < 256) {
            self.err = "";

            self.path = try allocator.alloc.realloc(self.path, self.path.len + 1);
            self.path[self.path.len - 1] = @as(u8, @intCast(keycode));
        }
    }

    pub fn click(_: *Self, _: vecs.Vector2) !void {}

    pub fn deinit(self: *Self) !void {
        allocator.alloc.free(self.path);
        allocator.alloc.destroy(self);
    }
};
