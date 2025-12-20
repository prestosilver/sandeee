const options = @import("options");
const std = @import("std");
const glfw = @import("glfw");

const drawers = @import("../drawers.zig");
const loaders = @import("../loaders.zig");
const events = @import("../events.zig");
const system = @import("../system.zig");
const states = @import("../states.zig");
const util = @import("../util.zig");
const math = @import("../math.zig");

const Sprite = drawers.Sprite;
const Wall = drawers.Wall;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const audio = util.audio;

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const EventManager = events.EventManager;
const system_events = events.system;

const Unloader = loaders.Unloader;

const Vm = system.Vm;
const files = system.files;

pub var target: enum { Quit, Bios, Update } = .Quit;
pub var target_file: []const u8 = "";

const GSLogout = @This();

shader: *Shader,
clear_shader: *Shader,
face: *Font,
font_shader: *Shader,
wallpaper: *Wall,
logout_sound: *audio.Sound,

time: f32 = 0,

pub var unloader: ?Unloader = null;

pub fn setup(self: *GSLogout) !void {
    try audio.instance.playSound(self.logout_sound.*);
    try Vm.Manager.logout();
    self.time = 3;

    if (unloader) |*ul|
        ul.run();

    unloader = null;
}

pub fn deinit(_: *GSLogout) void {}

pub fn draw(self: *GSLogout, size: Vec2) !void {
    const old_scissor = SpriteBatch.global.scissor;
    defer SpriteBatch.global.scissor = old_scissor;

    SpriteBatch.global.scissor = null;

    try SpriteBatch.global.draw(Wall, self.wallpaper, self.shader, .{});

    const clear_sprite: Sprite = .atlas("none", .{
        .size = size,
        .source = .{ .w = size.x, .h = size.y },
    });

    try SpriteBatch.global.draw(Sprite, &clear_sprite, self.clear_shader, .{});

    const text = if (target == .Update) "Updating" else "Logging Out";

    const logout_size = self.face.sizeText(.{
        .text = text,
    });

    const logout_pos = size.sub(logout_size).div(2);

    try self.face.draw(.{
        .shader = self.font_shader,
        .text = text,
        .pos = logout_pos,
        .color = .{ .r = 1, .g = 1, .b = 1 },
    });
}

pub fn update(self: *GSLogout, dt: f32) !void {
    self.time -= dt;

    if (self.time < 0) {
        switch (target) {
            .Quit => {
                glfw.setWindowShouldClose(graphics.Context.instance.window, true);
            },
            .Bios => {
                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Disks,
                });
            },
            .Update => {
                try files.Folder.recoverDisk(target_file, false);

                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Disks,
                });

                allocator.free(target_file);
                target_file = "";
            },
        }
    }
}
