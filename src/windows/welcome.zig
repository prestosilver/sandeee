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
const Size = ui.Element.Size;

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

    ui_data: ui.Context.Wrapper(@import("welcome.zon")) = undefined,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        props.no_min = true;

        self.ui_data.context.font_shader = font_shader;
        self.ui_data.context.font = font;

        props.clear_color = .gray(0.75);

        self.ui_data.context.arrange();
        self.ui_data.context.draw(bnds.getCorner(.top_left));
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        self.ui_data.context.keyEvent(keycode, mods, down);
    }

    pub fn move(self: *Self, x: f32, y: f32) void {
        self.ui_data.context.mouseMove(.{ .x = x, .y = y });
    }

    pub fn moveResize(self: *Self, bounds: Rect) void {
        self.ui_data.context.resize(.{
            .x = @intFromFloat(bounds.w + 28),
            .y = @intFromFloat(bounds.h),
        });
    }

    pub fn char(self: *Self, char_string: []const u8, _: i32) !void {
        self.ui_data.context.textInput(char_string);
    }

    pub fn click(self: *Self, _: Vec2, _: Vec2, btn: i32, kind: events.input.ClickKind) !void {
        self.ui_data.context.mouseClick(kind, btn);
    }

    pub fn deinit(self: *Self) void {
        allocator.destroy(self);
    }
};

fn clickDisable(_: *ui.Element, ev: *ui.Context.Event, _: *anyopaque) bool {
    config.SettingManager.instance.setBool("show_welcome", !ev.data.change.selected) catch unreachable;

    return true;
}

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(WelcomeData);

    self.* = .{};
    self.ui_data.init(
        &SpriteBatch.global,
        shader,
        undefined,
        undefined,
        .{ .x = 600, .y = 350 },
    );

    try self.ui_data.getElem("$").onEvent(.resize, ui.Element.Handlers.resizeWithMax, undefined);
    try self.ui_data.getElem("$/bottom/check").onEvent(.change, clickDisable, undefined);

    var result = try Window.Data.WindowContents.init(self, "Welcome", "Welcome To Sand" ++ strings.EEE ++ if (options.is_demo) " (trial)" else "", .gray(0.75));
    result.props.size.min = .{ .x = 600, .y = 350 };
    result.props.size.max = .{ .x = 600, .y = 350 };

    return result;
}
