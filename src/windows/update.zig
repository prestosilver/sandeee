const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const win = @import("../drawers/window2d.zig");
const sb = @import("../util/spritebatch.zig");
const shd = @import("../util/shader.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const fnt = @import("../util/font.zig");
const shell = @import("../system/shell.zig");
const allocator = @import("../util/allocator.zig");
const tex = @import("../util/texture.zig");
const col = @import("../math/colors.zig");
const files = @import("../system/files.zig");
const logoutState = @import("../states/logout.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");

pub const UpdateData = struct {
    const Self = @This();

    focused_link: bool = false,
    link_pos: rect.Rectangle = .{ .x = 0, .y = 0, .w = 1, .h = 1 },

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;
        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = "There has been a Sand\x82\x82\x82 Update",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26),
            .wrap = bnds.w - 12,
            .scale = 2,
        });

        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = "Please Update your disk to ensure you have all the nessesary files",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26 + font.size * 5),
            .wrap = bnds.w - 12,
            .scale = 1,
        });

        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .color = .{
                .r = 0,
                .g = 0,
                .b = 1,
                .a = 1,
            },
            .text = "Click here to update now",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26 + font.size * 10),
            .wrap = bnds.w - 12,
            .scale = 1,
        });

        self.link_pos = .{
            .x = 6,
            .y = 26 + font.size * 10,
            .w = font.sizeText(.{
                .text = "Click here to update now",
            }).x,
            .h = font.size,
        };
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}

    pub fn move(self: *Self, x: f32, y: f32) void {
        self.focused_link = self.link_pos.contains(.{
            .x = x,
            .y = y,
        });
    }

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, _: ?i32) !void {
        _ = pos;
        if (self.focused_link) {
            logoutState.target = .Update;
            try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                .targetState = .Logout,
            });
        }
    }

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        _ = mods;
        _ = code;
        _ = self;
    }

    pub fn key(_: *Self, _: i32, _: i32, _: bool) !void {}
    pub fn focus(_: *Self) !void {}
    pub fn moveResize(_: *Self, _: *rect.Rectangle) !void {}

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};

pub fn new() !win.WindowContents {
    const self = try allocator.alloc.create(UpdateData);

    self.* = UpdateData{};

    var result = try win.WindowContents.init(self, "Updater", "Please update your disk!", col.newColorRGBA(192, 192, 192, 255));
    result.props.size.min = vecs.newVec2(600, 350);
    result.props.size.max = vecs.newVec2(600, 350);

    return result;
}
