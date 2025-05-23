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

    const mailpath: []const u8 = "/cont/mail";
    const loginpath: []const u8 = "login_sound_path";
    const logoutpath: []const u8 = "logout_sound_path";
    const messagepath: []const u8 = "message_sound_path";
    const settingspath: []const u8 = "/conf/system.cfg";
    const fontpath: []const u8 = "system_font";
    const zero: u8 = 0;
    const delay: u64 = if (builtin.mode == .Debug) 0 else 45;
    const tdelay: u64 = if (builtin.mode == .Debug) 0 else 15;

    load_progress: f32 = 0,
    login_snd: audio.Sound = .{},
    logout_snd: *audio.Sound,
    message_snd: *audio.Sound,
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    loading: *const fn (*Self) void,

    face: *font.Font,

    logo_sprite: sp.Sprite,
    load_sprite: sp.Sprite,
    shader: *shd.Shader,
    disk: *?[]u8,

    loading_thread: ?std.Thread = null,

    fn loadThread(self: *Self) void {
        self.loading(self);
    }

    pub fn setup(self: *Self) !void {
        self.done.store(false, .monotonic);

        self.load_sprite.data.size.x = 0;
        self.loading_thread = null;

        var loader = try Loader.init(Loader.Group{});

        // files
        var files = try Loader.init(Loader.Files{
            .disk = self.disk.*.?,
        });

        // settings
        var settings = try Loader.init(Loader.Settings{
            .path = settingspath,
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
        //try self.loader.enqueue(*const []const u8, *audio.Sound, &loginpath, &self.login_snd, worker.sound.loadSound);
        //try self.loader.enqueue(*const []const u8, *audio.Sound, &logoutpath, self.logout_snd, worker.sound.loadSound);
        //try self.loader.enqueue(*const []const u8, *audio.Sound, &messagepath, self.message_snd, worker.sound.loadSound);

        //// mail
        //try self.loader.enqueue(*const []const u8, *const u8, &mailpath, &zero, worker.mail.loadMail);

        self.load_progress = 0;

        self.loading_thread = try std.Thread.spawn(.{}, Self.loadThread, .{self});

        try loader.load(&self.load_progress, 0.0, 1.0);

        // setup some pointers
        pseudo.win.shader = self.shader;

        wins.email.notif = .{
            .texture = "icons",
            .data = .{
                .source = .{ .x = 0.0 / 8.0, .y = 1.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{},
            },
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.loading_thread) |thread|
            thread.join();
    }

    pub fn update(self: *Self, _: f32) !void {
        try events.EventManager.instance.sendEvent(system_events.EventStateChange{
            .target_state = .Windowed,
        });

        // play login sound
        try audio.instance.playSound(self.login_snd);
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        if (self.done.load(.monotonic))
            return;

        const logo_offset = size.sub(self.logo_sprite.data.size).div(2);

        // draw the logo
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.logo_sprite, self.shader, .{ .x = logo_offset.x, .y = logo_offset.y });

        // progress bar
        self.load_sprite.data.size.x = (self.load_progress * 320 * 0.5 + self.load_sprite.data.size.x * 0.5);
        self.load_sprite.data.source.w = self.load_sprite.data.size.x / self.load_sprite.data.size.y;
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.load_sprite, self.shader, .{ .x = logo_offset.x, .y = logo_offset.y + 100 });

        if (self.load_sprite.data.size.x > 319)
            self.done.store(true, .monotonic);
    }
};
