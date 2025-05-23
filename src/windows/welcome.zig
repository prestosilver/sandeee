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
const sprite = @import("../drawers/sprite2d.zig");
const conf = @import("../system/config.zig");

const DEMO_TIME = 6e+11;

pub const WelcomeData = struct {
    const Self = @This();

    shell: shell.Shell,
    timer: std.time.Timer,
    check_box: [2]sprite.Sprite,
    cb_pos: rect.Rectangle = undefined,
    shader: *shd.Shader,

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        props.no_min = true;

        try font.draw(.{
            .shader = font_shader,
            .text = "Welcome to Sand" ++ fnt.EEE,
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 },
            .scale = 2,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = "  " ++ fnt.BULLET ++ " Open " ++ fnt.EEE ++ "Mail to get started",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + 3 * font.size },
            .scale = 1,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = if (options.IsDemo)
                "  " ++ fnt.BULLET ++ " This demo will not save progress."
            else
                "  " ++ fnt.BULLET ++ " You can open Xplore anytime for help",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + 5 * font.size },
            .scale = 1,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = "  " ++ fnt.BULLET ++ " Remember " ++ fnt.EEE ++ " is monitoring your activity",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + 7 * font.size },
            .scale = 1,
        });

        if (options.IsDemo) {
            props.no_close = true;
            const remaining = DEMO_TIME - @as(f32, @floatFromInt(self.timer.read()));
            if (remaining < 0) @panic("Demo Over");

            const demo_text = try std.fmt.allocPrint(allocator.alloc, "{} seconds remianing.", .{@as(usize, @intFromFloat(remaining / 1e+9))});
            defer allocator.alloc.free(demo_text);

            try font.draw(.{
                .shader = font_shader,
                .text = demo_text,
                .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + 10 * font.size },
                .scale = 2,
                .color = col.newColor(1, 0, 0, 1),
            });
        } else {
            // draw checkbox
            const cb: usize = if (conf.SettingManager.instance.getBool("show_welcome")) 0 else 1;

            self.cb_pos = rect.Rectangle{
                .x = 6,
                .y = 80 + 10 * font.size,
                .w = 20,
                .h = 20,
            };

            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.check_box[cb], self.shader, .{ .x = bnds.x + 6, .y = bnds.y + 80 + 10 * font.size });

            try font.draw(.{
                .shader = font_shader,
                .text = "Never show again.",
                .pos = .{ .x = bnds.x + 20 + 6, .y = bnds.y + 80 + 10 * font.size },
            });
        }

        const version_text = try std.fmt.allocPrint(allocator.alloc, "(" ++ options.VersionText ++ ")", .{options.SandEEEVersion});
        defer allocator.alloc.free(version_text);

        try font.draw(.{
            .shader = font_shader,
            .text = version_text,
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + bnds.h - 1.5 * font.size },
        });
    }

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, btn: ?i32) !void {
        if (btn) |_| {
            if (self.cb_pos.contains(pos)) {
                const new_value: bool = !conf.SettingManager.instance.getBool("show_welcome");
                try conf.SettingManager.instance.setBool("show_welcome", new_value);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(WelcomeData);

    self.* = WelcomeData{
        .shell = .{
            .root = .home,
            .vm = null,
        },
        .check_box = .{
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 4.0 / 8.0, .y = 6.0 / 8.0, .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
                    .size = .{ .x = 20, .y = 20 },
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 6.0 / 8.0, .y = 6.0 / 8.0, .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
                    .size = .{ .x = 20, .y = 20 },
                },
            },
        },
        .shader = shader,
        .timer = try std.time.Timer.start(),
    };

    var result = try win.WindowContents.init(self, "Welcome", "Welcome To Sand" ++ fnt.EEE, .{ .r = 0.75, .g = 0.75, .b = 0.75 });
    result.props.size.min = .{ .x = 600, .y = 350 };
    result.props.size.max = .{ .x = 600, .y = 350 };

    return result;
}
