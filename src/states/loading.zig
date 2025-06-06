const std = @import("std");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");
const sp = @import("../drawers/sprite2d.zig");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const cols = @import("../math/colors.zig");
const fm = @import("../util/files.zig");
const audio = @import("../util/audio.zig");
const conf = @import("../system/config.zig");
const tex = @import("../util/texture.zig");
const texture_manager = @import("../util/texmanager.zig");
const font = @import("../util/font.zig");
const gfx = @import("../util/graphics.zig");
const wins = @import("../windows/all.zig");
const pseudo = @import("../system/pseudo/all.zig");
const shell = @import("../system/shell.zig");
const events = @import("../util/events.zig");
const system_events = @import("../events/system.zig");
const mail = @import("../system/mail.zig");
const allocator = @import("../util/allocator.zig");
const builtin = @import("builtin");
const log = @import("../util/log.zig").log;
const logout_state = @import("logout.zig");

const Loader = @import("../loaders/loader.zig");

pub const GSLoading = struct {
    const Self = @This();

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

    face: *font.Font,

    logo_sprite: sp.Sprite,
    load_sprite: sp.Sprite,
    shader: *shd.Shader,
    disk: *?[]u8,

    loading_thread: ?std.Thread = null,

    fn loadThread(in_self: *Self, load_error: *?[]const u8) void {
        return struct {
            fn load(self: *Self) !void {
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

                logout_state.GSLogout.unloader = try loader.load(&self.load_progress, 0.0, 1.0);
            }
        }.load(in_self) catch |err| {
            log.info("{?}", .{@errorReturnTrace()});
            load_error.* = @errorName(err); // ++ " while loading";
        };
    }

    pub fn setup(self: *Self) !void {
        self.done.store(false, .monotonic);

        self.wait = LOAD_WAIT;

        self.loading_thread = null;

        self.load_progress = 0;
        self.load_sprite.data.size.x = 0;

        self.loading_thread = try std.Thread.spawn(.{}, Self.loadThread, .{ self, &self.load_error });

        // setup some pointers
        pseudo.win.shader = self.shader;

        wins.email.notif = .atlas("icons", .{
            .source = .{ .x = 0.0 / 8.0, .y = 1.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{},
        });
    }

    pub fn deinit(self: *Self) void {
        if (self.loading_thread) |thread|
            thread.join();
    }

    pub fn update(self: *Self, dt: f32) !void {
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

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        const logo_offset = size.sub(self.logo_sprite.data.size).div(2);

        const fade_time = LOAD_WAIT * 0.75;
        const round_fade: f32 = @round(std.math.clamp(self.wait / fade_time, 0, 1) * FADE_STEPS);
        const fade: f32 = round_fade / FADE_STEPS;

        // draw the logo
        self.logo_sprite.data.color.a = fade;
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.logo_sprite, self.shader, .{ .x = logo_offset.x, .y = logo_offset.y });

        // progress bar
        self.load_sprite.data.color.a = fade;
        self.load_sprite.data.size.x = (self.load_progress * 320 * 0.5 + self.load_sprite.data.size.x * 0.5);
        self.load_sprite.data.source.w = self.load_sprite.data.size.x / self.load_sprite.data.size.y;
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.load_sprite, self.shader, .{ .x = logo_offset.x, .y = logo_offset.y + 100 });

        if (self.load_sprite.data.size.x > 319)
            self.done.store(true, .monotonic);
    }
};
