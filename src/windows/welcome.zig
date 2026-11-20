const std = @import("std");
const options = @import("options");

const Windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");
const ui = @import("../ui.zig");

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

    ui_context: ui.Context,
    ui_root: ui.Panel,
    ui_label: ui.Label,
    ui_title: ui.Label,
    ui_version: ui.Label,
    ui_spacer: ui.Element,
    ui_check: ui.CheckBox,
    ui_bottom: ui.Panel,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        props.no_min = true;

        self.ui_context.font_shader = font_shader;
        self.ui_context.font = font;

        props.clear_color = .gray(0.75);

        self.ui_context.arrange();
        self.ui_context.draw(bnds.getCorner(.top_left));
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        self.ui_context.keyEvent(keycode, mods, down);
    }

    pub fn move(self: *Self, x: f32, y: f32) void {
        self.ui_context.mouseMove(.{ .x = x, .y = y });
    }

    pub fn moveResize(self: *Self, bounds: Rect) void {
        self.ui_context.resize(.{
            .x = @intFromFloat(bounds.w + 12),
            .y = @intFromFloat(bounds.h + 40),
        });
    }

    pub fn char(self: *Self, char_string: []const u8, _: i32) !void {
        self.ui_context.textInput(char_string);
    }

    pub fn click(self: *Self, _: Vec2, _: Vec2, btn: i32, kind: events.input.ClickKind) !void {
        self.ui_context.mouseClick(kind, btn);
    }

    pub fn deinit(self: *Self) void {
        allocator.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(WelcomeData);

    self.* = .{
        .ui_title = .{
            .base = .init(&self.ui_context, "root", ui.Label, .{
                .focusable = false,
                .margin = .{
                    .bottom = 30,
                },
            }),
            .scale = 2.0,
            .text = "Welcome to Sand" ++ strings.EEE,
        },
        .ui_label = .{
            .base = .init(&self.ui_context, "root", ui.Label, .{
                .focusable = false,
            }),
            .text = "  " ++ strings.BULLET ++ " Open " ++ strings.EEE ++ "Mail to get started\n\n" ++
                "  " ++ strings.BULLET ++ " You can open Xplore anytime for help\n\n" ++
                "  " ++ strings.BULLET ++ " Remember " ++ strings.EEE ++ " is monitoring your activity",
        },
        .ui_version = .{
            .base = .init(&self.ui_context, "version", ui.Label, .{
                .focusable = false,
            }),
            .text = "(" ++ strings.SANDEEE_VERSION_TEXT ++ ")",
        },
        .ui_check = .{
            .label = "Never show again.",
            .base = .init(&self.ui_context, "root", ui.CheckBox, .{
                .desired_size = .{ .w = 200, .h = 30 },
            }),
        },
        .ui_spacer = .init(&self.ui_context, "root", ui.Panel, .{
            .focusable = false,
            .expand_h = true,
        }),
        .ui_bottom = .{
            .base = .init(&self.ui_context, "root", ui.Panel, .{
                .focusable = false,
                .desired_size = .{ .w = 600, .h = 350 },
                .padding = .all(20),
            }),
            .flags = .{
                .justify = .space_between,
                .direction = .row,
                .wrap = true,
            },
        },
        .ui_root = .{
            .base = .init(&self.ui_context, "bottom", ui.Panel, .{
                .focusable = false,
                .padding = .{ .top = 20 },
            }),
            .flags = .{
                .direction = .column,
                .wrap = true,
            },
        },
        .ui_context = .{
            .sprite_batch = &SpriteBatch.global,
            .shader = shader,
            .font = undefined,
            .font_shader = undefined,
            .window_size = .{ .x = 640, .y = 480 },
            .clip_stack = .initBuffer(&self.ui_context.clip_stack_buf),
            .root = &self.ui_root.base,
        },
    };

    try self.ui_root.base.onEvent(.resize, ui.Element.Handlers.resize_with_max, undefined);
    self.ui_root.base.addChild(&self.ui_title.base);
    self.ui_root.base.addChild(&self.ui_label.base);
    self.ui_root.base.addChild(&self.ui_spacer);
    self.ui_root.base.addChild(&self.ui_bottom.base);

    self.ui_bottom.base.addChild(&self.ui_check.base);
    self.ui_bottom.base.addChild(&self.ui_version.base);

    var result = try Window.Data.WindowContents.init(self, "Welcome", "Welcome To Sand" ++ strings.EEE ++ if (options.is_demo) " (trial)" else "", .gray(0.75));
    result.props.size.min = .{ .x = 600, .y = 350 };
    result.props.size.max = .{ .x = 600, .y = 350 };

    return result;
}
