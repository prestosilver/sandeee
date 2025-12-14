const std = @import("std");
const glfw = @import("glfw");

const sandeee_data = @import("../../data/mod.zig");
const drawers = @import("../../drawers/mod.zig");
const system = @import("../../system/mod.zig");
const events = @import("../../events/mod.zig");
const math = @import("../../math/mod.zig");
const util = @import("../../util/mod.zig");

const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;

const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;

const strings = sandeee_data.strings;

pub const PopupFolderPick = struct {
    const Self = @This();

    path: []u8,
    submit: *const fn (?*files.Folder, *anyopaque) anyerror!void,
    err: ?[]const u8 = null,
    data: *anyopaque,

    pub fn draw(self: *Self, shader: *Shader, bnds: Rect, font: *Font) !void {
        try font.draw(.{
            .shader = shader,
            .pos = bnds.location(),
            .text = "Enter the folders path:",
        });

        const maxlen: usize = @intFromFloat((bnds.w - 60) / 10);

        const text = if (self.path.len > maxlen)
            try std.fmt.allocPrint(allocator.alloc, strings.DOTS ++ "{s}", .{self.path[self.path.len - maxlen + 1 ..]})
        else
            try allocator.alloc.dupe(u8, self.path);
        defer allocator.alloc.free(text);

        const text_background: Sprite = .atlas("ui", .{
            .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = bnds.w - 60, .y = 32 },
        });

        const text_foreground: Sprite = .atlas("ui", .{
            .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = bnds.w - 64, .y = 28 },
        });

        try SpriteBatch.global.draw(Sprite, &text_background, Popup.Data.popup_shader, .{ .x = bnds.x + 28, .y = bnds.y + font.size * 2 - 4 });
        try SpriteBatch.global.draw(Sprite, &text_foreground, Popup.Data.popup_shader, .{ .x = bnds.x + 30, .y = bnds.y + font.size * 2 - 2 });

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

        if (keycode == glfw.KeyBackspace and self.path.len != 0) {
            self.path = try allocator.alloc.realloc(self.path, self.path.len - 1);
            if (self.err) |err|
                allocator.alloc.free(err);
            self.err = null;
        }

        if (keycode == glfw.KeyEnter) {
            const root = try files.FolderLink.resolve(.root);

            if (root.getFolder(self.path) catch null) |folder| {
                try self.submit(folder, self.data);
                try events.EventManager.instance.sendEvent(window_events.EventClosePopup{
                    .popup_conts = self,
                });
            } else {
                if (self.err) |err|
                    allocator.alloc.free(err);
                self.err = try allocator.alloc.dupe(u8, "Folder Not Found");
            }
        }
    }

    pub fn char(self: *Self, keycode: u32, _: i32) !void {
        if (keycode < 256) {
            if (self.err) |err|
                allocator.alloc.free(err);
            self.err = null;

            self.path = try allocator.alloc.realloc(self.path, self.path.len + 1);
            self.path[self.path.len - 1] = @as(u8, @intCast(keycode));
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.err) |err|
            allocator.alloc.free(err);

        allocator.alloc.free(self.path);
        allocator.alloc.destroy(self);
    }
};
