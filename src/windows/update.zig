const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");
const c = @import("../c.zig");

const Windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const states = @import("../states.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const Window = drawers.Window;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const log = util.log;

const Shell = system.Shell;
const files = system.files;

const EventManager = events.EventManager;
const system_events = events.system;

const LogoutState = states.Logout;

const strings = data.strings;

pub const UpdateData = struct {
    const Self = @This();

    focused_link: bool = false,
    link_pos: Rect = .{ .x = 0, .y = 0, .w = 1, .h = 1 },

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        props.no_min = true;
        props.no_close = true;

        try font.draw(.{
            .shader = font_shader,
            .text = "There has been a Sand" ++ strings.EEE ++ " Update",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 },
            .wrap = bnds.w - 12,
            .scale = 2,
        });

        try font.draw(.{
            .shader = font_shader,
            .text = "Please Update your disk to ensure you have all the nessesary files",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + font.size * 5 },
            .wrap = bnds.w - 12,
            .scale = 1,
        });

        try font.draw(.{
            .shader = font_shader,
            .color = .{
                .r = 0,
                .g = 0,
                .b = 1,
                .a = 1,
            },
            .text = "Click here to update now",
            .pos = .{ .x = bnds.x + 6, .y = bnds.y + 26 + font.size * 10 },
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

    pub fn move(self: *Self, x: f32, y: f32) void {
        self.focused_link = self.link_pos.contains(.{
            .x = x,
            .y = y,
        });
    }

    pub fn click(self: *Self, _: Vec2, pos: Vec2, _: ?i32) !void {
        _ = pos;
        if (self.focused_link) {
            const idx = std.mem.lastIndexOf(u8, files.root_out.?, "/") orelse unreachable;
            LogoutState.target_file = try allocator.dupe(u8, files.root_out.?[idx + 1 ..]);
            LogoutState.target = .Update;
            try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                .target_state = .Logout,
            });
        }
    }

    pub fn deinit(self: *Self) void {
        allocator.destroy(self);
    }
};

pub fn init() !Window.Data.WindowContents {
    const self = try allocator.create(UpdateData);

    self.* = .{};

    var result: Window.Data.WindowContents = try .init(self, "Updater", "Please update your disk!", .{ .r = 0.75, .g = 0.75, .b = 0.75 });
    result.props.size.min = .{ .x = 600, .y = 350 };
    result.props.size.max = .{ .x = 600, .y = 350 };

    return result;
}
