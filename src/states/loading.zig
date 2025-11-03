const builtin = @import("builtin");
const std = @import("std");

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
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const storage = util.storage;
const audio = util.audio;
const log = util.log;

const Shell = system.Shell;
const config = system.config;
const mail = system.mail;

const Loader = loaders.Loader;

const EventManager = events.EventManager;
const system_events = events.system;

const LogoutState = states.Logout;

const pseudo = @import("../system/pseudo/all.zig");

const GSLoading = @This();

const TEXTURE_NAMES = [_][2][]const u8{
    .{ "window_frame_path", "win" },
    .{ "wallpaper_path", "wall" },
    .{ "bar_texture_path", "bar" },
    .{ "ui_texture_path", "ui" },
    .{ "icons_texture_path", "icons" },
    .{ "bigicons_texture_path", "big_icons" },
    .{ "cursor_texture_path", "cursor" },
    .{ "bar_logo_path", "barlogo" },
    .{ "email_logo_path", "email-logo" },
};
const LOAD_WAIT = if (builtin.mode == .Debug) 0.1 else 1.0;
const FADE_STEPS = 23;

const mailpath: []const u8 = "/cont/mail";
const login_sound_path: []const u8 = "login_sound_path";
const logout_sound_path: []const u8 = "logout_sound_path";
const message_sound_path: []const u8 = "message_sound_path";
const settings_path: []const u8 = "/conf/system.cfg";
const fontpath: []const u8 = "system_font";

wait: f32 = LOAD_WAIT,
load_progress: f32 = 0,
login_snd: audio.Sound = .{},
done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
load_error: ?[]const u8 = null,
logout_snd: *audio.Sound,
message_snd: *audio.Sound,

face: *Font,

logo_sprite: Sprite,
load_sprite: Sprite,
shader: *Shader,
disk: *?[]u8,

loading_thread: ?std.Thread = null,

fn loadThread(in_self: *GSLoading, load_error: *?[]const u8) void {
    return struct {
        fn load(self: *GSLoading) !void {
            var loader = try Loader.init(Loader.Group{});

            // files
            var files = try Loader.init(Loader.Files{
                .disk = self.disk.*.?,
            });

            // settings
            var settings = try Loader.init(Loader.Settings{
                .path = settings_path,
            });

            try settings.require(&files);

            try loader.require(&files);
            try loader.require(&settings);

            var textures = try Loader.init(Loader.Group{});

            var texture_loaders: [TEXTURE_NAMES.len]Loader = undefined;
            for (TEXTURE_NAMES, 0..) |texture_entry, i| {
                texture_loaders[i] = try Loader.init(Loader.Texture{
                    .path = texture_entry[0],
                    .name = texture_entry[1],
                });

                try textures.require(&texture_loaders[i]);
            }

            try textures.require(&settings);
            try loader.require(&textures);

            var face = try Loader.init(Loader.Font{
                .data = .{
                    .path = fontpath,
                },
                .output = self.face,
            });

            try face.require(&settings);
            try loader.require(&face);

            //// sounds
            var sounds = try Loader.init(Loader.Group{});

            var login_sound_load = try Loader.init(Loader.Sound{
                .path = login_sound_path,
                .output = &self.login_snd,
            });

            try sounds.require(&login_sound_load);

            var logout_sound_load = try Loader.init(Loader.Sound{
                .path = logout_sound_path,
                .output = self.logout_snd,
            });

            try logout_sound_load.require(&settings);
            try sounds.require(&logout_sound_load);

            var message_sound_load = try Loader.init(Loader.Sound{
                .path = message_sound_path,
                .output = self.message_snd,
            });

            try sounds.require(&message_sound_load);

            try sounds.require(&settings);
            try loader.require(&sounds);

            //// mail
            //try self.loader.enqueue(*const []const u8, *const u8, &mailpath, &zero, worker.mail.loadMail);

            LogoutState.unloader = try loader.load(&self.load_progress, 0.0, 1.0);
        }
    }.load(in_self) catch |err| {
        @import("../main.zig").panic(@errorName(err), @errorReturnTrace(), null);
        log.err("loading error: {s}", .{@errorName(err)});
        load_error.* = @errorName(err);
    };
}

pub fn setup(self: *GSLoading) !void {
    self.done.store(false, .monotonic);
    defer self.done.store(true, .monotonic);

    self.wait = LOAD_WAIT;

    self.load_progress = 0;
    self.loading_thread = try std.Thread.spawn(.{}, GSLoading.loadThread, .{ self, &self.load_error });

    // setup some pointers
    pseudo.win.shader = self.shader;

    windows.email.notif = .atlas("icons", .{
        .source = .{ .x = 0.0 / 8.0, .y = 1.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
        .size = .{},
    });
}

pub fn deinit(self: *GSLoading) void {
    if (self.loading_thread) |thread|
        thread.join();

    self.loading_thread = null;
    self.load_sprite.data.size.x = 0;
}

pub fn update(self: *GSLoading, dt: f32) !void {
    if (!self.done.load(.monotonic))
        return;

    self.wait -= dt;

    if (self.wait > 0) return;

    try events.EventManager.instance.sendEvent(system_events.EventStateChange{
        .target_state = .Windowed,
    });

    // play login sound
    try audio.instance.playSound(self.login_snd);
}

pub fn draw(self: *GSLoading, size: Vec2) !void {
    const logo_offset = size.sub(self.logo_sprite.data.size).div(2);

    const fade_time = LOAD_WAIT * 0.75;
    const round_fade: f32 = @round(std.math.clamp(self.wait / fade_time, 0, 1) * FADE_STEPS);
    const fade: f32 = round_fade / FADE_STEPS;

    // draw the logo
    self.logo_sprite.data.color.a = fade;
    try SpriteBatch.global.draw(Sprite, &self.logo_sprite, self.shader, .{ .x = logo_offset.x, .y = logo_offset.y });

    // progress bar
    self.load_sprite.data.color.a = fade;
    self.load_sprite.data.size.x = (self.load_progress * 320 * 0.5 + self.load_sprite.data.size.x * 0.5);
    self.load_sprite.data.source.w = self.load_sprite.data.size.x / self.load_sprite.data.size.y;
    try SpriteBatch.global.draw(Sprite, &self.load_sprite, self.shader, .{ .x = logo_offset.x, .y = logo_offset.y + 100 });

    if (self.load_sprite.data.size.x > 319)
        self.done.store(true, .monotonic);
}
