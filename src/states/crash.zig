const builtin = @import("builtin");
const options = @import("options");
const std = @import("std");
const c = @import("../c.zig");

const drawers = @import("../drawers/mod.zig");
const windows = @import("../windows/mod.zig");
const loaders = @import("../loaders/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const states = @import("../states/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Color = math.Color;
const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const Sprite = drawers.Sprite;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const storage = util.storage;
const audio = util.audio;

const files = system.files;

const GSCrash = @This();

message: *[]const u8,
shader: *Shader,
face: *Font,
font_shader: *Shader,

prev_state: *u8,

sad_sprite: Sprite,

pub fn setup(_: *GSCrash) !void {
    files.write();
    graphics.Context.instance.color = .{ .r = 0.25, .g = 0, .b = 0 };
}

pub fn deinit(_: *GSCrash) void {}

pub fn draw(self: *GSCrash, size: Vec2) !void {
    SpriteBatch.global.scissor = null;

    try SpriteBatch.global.draw(Sprite, &self.sad_sprite, self.shader, .{ .x = 100, .y = 100 });

    try self.face.draw(.{
        .shader = self.font_shader,
        .text = "ERROR:",
        .pos = .{ .x = 300, .y = 100 },
        .color = .{ .r = 1, .g = 1, .b = 1 },
        .wrap = size.x - 400,
    });
    try self.face.draw(.{
        .shader = self.font_shader,
        .text = self.message.*,
        .pos = .{ .x = 300, .y = 100 + self.face.size },
        .color = .{ .r = 1, .g = 1, .b = 1 },
        .wrap = size.x - 400,
    });

    const offset = self.face.sizeText(.{
        .text = self.message.*,
        .wrap = size.x - 400,
    }).y;

    const state_text = try std.fmt.allocPrint(allocator.alloc, "State: {}", .{self.prev_state.*});
    defer allocator.alloc.free(state_text);

    try self.face.draw(.{
        .shader = self.font_shader,
        .text = state_text,
        .pos = .{ .x = 300, .y = 100 + self.face.size * 1 + offset },
        .color = .{ .r = 1, .g = 1, .b = 1 },
        .wrap = size.x - 400,
    });

    try self.face.draw(.{
        .shader = self.font_shader,
        .text = "\nIF YOU SEE THIS CRASH YOUR FILES WERE SAVED :)",
        .pos = .{ .x = 300, .y = 100 + self.face.size * 3 + offset },
        .color = .{ .r = 1, .g = 1, .b = 1 },
        .wrap = size.x - 400,
    });
}

pub fn keypress(_: *GSCrash, key: c_int, _: c_int, down: bool) !void {
    if (down and key == c.GLFW_KEY_ESCAPE)
        c.glfwSetWindowShouldClose(graphics.Context.instance.window, 1);
    return;
}
