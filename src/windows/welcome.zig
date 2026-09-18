const std = @import("std");
const options = @import("options");

const Windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

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

const DEMO_TIME: std.Io.Duration = .fromSeconds(30 * 60);

pub const WelcomeData = struct {
    const Self = @This();

    shell: Shell,
    stop_time: std.Io.Timestamp,
    check_box: [2]Sprite,
    cb_pos: Rect = .{ .w = 0, .h = 0 },
    shader: *Shader,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        props.no_min = true;

        var y: f32 = 0;

        try font.draw(.{
            .shader = font_shader,
            .text = "Welcome to Sand" ++ strings.EEE,
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + y * font.size },
            .scale = 2,
        });
        y += 3;

        if (options.is_demo) {
            try font.draw(.{
                .shader = font_shader,
                .text = "trial version",
                .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + y * font.size },
                .scale = 1,
            });
        }
        y += 2;

        try font.draw(.{
            .shader = font_shader,
            .text = "  " ++ strings.BULLET ++ " Open " ++ strings.EEE ++ "Mail to get started",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + y * font.size },
            .scale = 1,
        });
        y += 2;

        try font.draw(.{
            .shader = font_shader,
            .text = "  " ++ strings.BULLET ++ " You can open Xplore anytime for help",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + y * font.size },
            .scale = 1,
        });
        y += 2;

        try font.draw(.{
            .shader = font_shader,
            .text = "  " ++ strings.BULLET ++ " Remember " ++ strings.EEE ++ " is monitoring your activity",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + y * font.size },
            .scale = 1,
        });
        y += 2;

        if (options.is_demo) {
            props.no_close = true;
            const remaining: f32 = @floatFromInt(std.Io.Clock.real.now(util.io).durationTo(self.stop_time).toSeconds());
            if (remaining < 0) @panic("Trial Over");

            const demo_text = try std.fmt.allocPrint(allocator, "Trial ends in {}m", .{@as(usize, @intFromFloat(remaining / 60.0))});
            defer allocator.free(demo_text);

            try font.draw(.{
                .shader = font_shader,
                .text = demo_text,
                .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + y * font.size },
                .scale = 2,
                .color = .red,
            });

            y += 3;
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

        const version_text = try std.fmt.allocPrint(allocator, "(" ++ strings.SANDEEE_VERSION_TEXT ++ ")", .{});
        defer allocator.free(version_text);

        try font.draw(.{
            .shader = font_shader,
            .text = version_text,
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + bnds.h - 1.5 * font.size },
        });
    }

    pub fn click(self: *Self, _: Vec2, pos: Vec2, btn: i32, kind: events.input.ClickKind) !void {
        if (btn == 0 and kind == .single and self.cb_pos.contains(pos)) {
            const new_value: bool = config.SettingManager.instance.getBool("show_welcome") orelse true;
            try config.SettingManager.instance.setBool("show_welcome", !new_value);
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(WelcomeData);

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
        .stop_time = std.Io.Clock.real.now(util.io).addDuration(DEMO_TIME),
    };

    var result = try Window.Data.WindowContents.init(self, "Welcome", "Welcome To Sand" ++ strings.EEE ++ if (options.is_demo) " (trial)" else "", .gray(0.75));
    result.props.size.min = .{ .x = 600, .y = 350 };
    result.props.size.max = .{ .x = 600, .y = 350 };

    return result;
}
