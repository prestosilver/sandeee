const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const win = @import("../drawers/window2d.zig");
const batch = @import("../util/spritebatch.zig");
const shd = @import("../util/shader.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const fnt = @import("../util/font.zig");
const shell = @import("../system/shell.zig");
const allocator = @import("../util/allocator.zig");
const tex = @import("../util/texture.zig");
const col = @import("../math/colors.zig");
const files = @import("../system/files.zig");

const DEMO_TIME = 6e+11;

pub const WelcomeData = struct {
    const Self = @This();

    shell: shell.Shell,
    timer: std.time.Timer,

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;
        try font.draw(.{
            .shader = font_shader,
            .text = "Welcome to Sand\x82\x82\x82",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26),
            .scale = 2,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = "  \x80 Open \x82\x82\x82Mail to get started",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26 + 3 * font.size),
            .scale = 1,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = if (options.IsDemo) "  \x80 This demo will not save progress." else "  \x80 You can open Xplore anytime for help",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26 + 5 * font.size),
            .scale = 1,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = "  \x80 Remember \x82\x82\x82 is monitoring your activity",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26 + 7 * font.size),
            .scale = 1,
        });

        if (options.IsDemo) {
            const remaining = DEMO_TIME - @as(f32, @floatFromInt(self.timer.read()));
            if (remaining < 0) @panic("Demo Over");

            const demoText = try std.fmt.allocPrint(allocator.alloc, "{} seconds remianing.", .{@as(usize, @intFromFloat(remaining / 1e+9))});
            defer allocator.alloc.free(demoText);

            try font.draw(.{
                .shader = font_shader,
                .text = demoText,
                .pos = vecs.newVec2(bnds.x + 6, bnds.y + 26 + 10 * font.size),
                .scale = 2,
                .color = col.newColor(1, 0, 0, 1),
            });
        }

        const versionText = try std.fmt.allocPrint(allocator.alloc, "(" ++ options.VersionText ++ ")", .{options.SandEEEVersion});
        defer allocator.alloc.free(versionText);

        try font.draw(.{
            .shader = font_shader,
            .text = versionText,
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + bnds.h - 1.5 * font.size),
        });
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}

    pub fn move(self: *Self, x: f32, y: f32) void {
        _ = y;
        _ = x;
        _ = self;
    }

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, _: ?i32) !void {
        _ = pos;
        _ = self;
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
    const self = try allocator.alloc.create(WelcomeData);

    // TODO: disable button

    self.* = WelcomeData{
        .shell = .{
            .root = files.home,
            .vm = null,
        },
        .timer = try std.time.Timer.start(),
    };

    var result = try win.WindowContents.init(self, "Welcome", "Welcome To Sand\x82\x82\x82", col.newColorRGBA(192, 192, 192, 255));
    result.props.size.min = vecs.newVec2(600, 350);
    result.props.size.max = vecs.newVec2(600, 350);

    return result;
}
