const std = @import("std");
const options = @import("options");
const c = @import("../c.zig");

const Windows = @import("mod.zig");

const drawers = @import("../drawers/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const HttpClient = util.HttpClient;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Url = util.Url;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const Shell = system.Shell;
const config = system.config;
const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;

const strings = data.strings;

const DEMO_TIME = 6e+11;

pub const WelcomeData = struct {
    const Self = @This();

    shell: Shell,
    timer: std.time.Timer,
    check_box: [2]Sprite,
    cb_pos: Rect = .{ .w = 0, .h = 0 },
    shader: *Shader,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        props.no_min = true;

        try font.draw(.{
            .shader = font_shader,
            .text = "Welcome to Sand" ++ strings.EEE,
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 },
            .scale = 2,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = "  " ++ strings.BULLET ++ " Open " ++ strings.EEE ++ "Mail to get started",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + 3 * font.size },
            .scale = 1,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = if (options.IsDemo)
                "  " ++ strings.BULLET ++ " This demo will not save progress."
            else
                "  " ++ strings.BULLET ++ " You can open Xplore anytime for help",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + 5 * font.size },
            .scale = 1,
        });
        try font.draw(.{
            .shader = font_shader,
            .text = "  " ++ strings.BULLET ++ " Remember " ++ strings.EEE ++ " is monitoring your activity",
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
                .color = .newColor(1, 0, 0, 1),
            });
        } else {
            // draw checkbox
            const cb: usize = if (config.SettingManager.instance.getBool("show_welcome") orelse true) 0 else 1;

            self.cb_pos = Rect{
                .x = 6,
                .y = 80 + 10 * font.size,
                .w = 20,
                .h = 20,
            };

            try SpriteBatch.global.draw(Sprite, &self.check_box[cb], self.shader, .{ .x = bnds.x + 6, .y = bnds.y + 80 + 10 * font.size });

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

    pub fn click(self: *Self, _: Vec2, pos: Vec2, btn: ?i32) !void {
        if (btn) |_| {
            if (self.cb_pos.contains(pos)) {
                const new_value: bool = config.SettingManager.instance.getBool("show_welcome") orelse true;
                try config.SettingManager.instance.setBool("show_welcome", !new_value);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.alloc.create(WelcomeData);

    self.* = .{
        .shell = .{
            .root = .home,
            .vm = null,
        },
        .check_box = .{
            .atlas("ui", .{
                .source = .{ .x = 4.0 / 8.0, .y = 6.0 / 8.0, .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
                .size = .{ .x = 20, .y = 20 },
            }),
            .atlas("ui", .{
                .source = .{ .x = 6.0 / 8.0, .y = 6.0 / 8.0, .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
                .size = .{ .x = 20, .y = 20 },
            }),
        },
        .shader = shader,
        .timer = try std.time.Timer.start(),
    };

    var result = try Window.Data.WindowContents.init(self, "Welcome", "Welcome To Sand" ++ strings.EEE, .{ .r = 0.75, .g = 0.75, .b = 0.75 });
    result.props.size.min = .{ .x = 600, .y = 350 };
    result.props.size.max = .{ .x = 600, .y = 350 };

    return result;
}
