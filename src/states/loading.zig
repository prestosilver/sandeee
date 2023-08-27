const std = @import("std");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");
const sp = @import("../drawers/sprite2d.zig");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const cols = @import("../math/colors.zig");
const worker = @import("../loaders/worker.zig");
const fm = @import("../util/files.zig");
const audio = @import("../util/audio.zig");
const conf = @import("../system/config.zig");
const tex = @import("../util/texture.zig");
const texMan = @import("../util/texmanager.zig");
const font = @import("../util/font.zig");
const gfx = @import("../util/graphics.zig");
const wins = @import("../windows/all.zig");
const pseudo = @import("../system/pseudo/all.zig");
const shell = @import("../system/shell.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const mail = @import("../system/mail.zig");
const allocator = @import("../util/allocator.zig");
const builtin = @import("builtin");

pub const GSLoading = struct {
    const Self = @This();

    const textureNames = [_][2][]const u8{
        .{ "window_frame_path", "win" },
        .{ "wallpaper_path", "wall" },
        .{ "bar_texture_path", "bar" },
        .{ "notif_texture_path", "notif" },
        .{ "ui_texture_path", "ui" },
        .{ "icons_texture_path", "icons" },
        .{ "bigicons_texture_path", "big_icons" },
        .{ "email_texture_path", "email" },
        .{ "cursor_texture_path", "cursor" },
        .{ "bar_logo_path", "barlogo" },
    };

    const mailpath: []const u8 = "/cont/mail";
    const loginpath: []const u8 = "/cont/snds/login.era";
    const logoutpath: []const u8 = "/cont/snds/logout.era";
    const messagepath: []const u8 = "/cont/snds/message.era";
    const settingspath: []const u8 = "/conf/system.cfg";
    const fontpath: []const u8 = "system_font";
    const zero: u8 = 0;
    const delay: u64 = if (builtin.mode == .Debug) 0 else 90;
    const tdelay: u64 = if (builtin.mode == .Debug) 0 else 15;

    load_progress: f32 = 0,
    login_snd: audio.Sound = undefined,
    logout_snd: *audio.Sound,
    message_snd: *audio.Sound,
    done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),

    loading: *const fn (*Self) void,

    emailManager: *mail.EmailManager,
    face: *font.Font,

    logo_sprite: sp.Sprite,
    load_sprite: sp.Sprite,
    shader: *shd.Shader,
    disk: *?[]u8,
    audio_man: *audio.Audio,

    loadingThread: std.Thread = undefined,

    loader: *worker.WorkerContext,

    fn loadThread(self: *Self) void {
        self.loading(self);
    }

    pub fn setup(self: *Self) !void {
        self.done.storeUnchecked(false);

        self.load_sprite.data.size.x = 0;

        // delay
        try self.loader.enqueue(*const u64, *const u8, &delay, &zero, worker.delay.loadDelay);

        // files
        try self.loader.enqueue(*?[]u8, *const u8, self.disk, &zero, worker.files.loadFiles);
        defer allocator.alloc.free(self.disk.*.?);

        // settings
        try self.loader.enqueue(*const []const u8, *const u8, &settingspath, &zero, worker.settings.loadSettings);

        // textures
        for (&textureNames) |*textureEntry| {
            try self.loader.enqueue(*const []const u8, *const []const u8, &textureEntry[0], &textureEntry[1], worker.texture.loadTexture);

            // delay
            try self.loader.enqueue(*const u64, *const u8, &tdelay, &zero, worker.delay.loadDelay);
        }

        // delay
        try self.loader.enqueue(*const u64, *const u8, &delay, &zero, worker.delay.loadDelay);

        // sounds
        try self.loader.enqueue(*const []const u8, *audio.Sound, &loginpath, &self.login_snd, worker.sound.loadSound);
        try self.loader.enqueue(*const []const u8, *audio.Sound, &logoutpath, self.logout_snd, worker.sound.loadSound);
        try self.loader.enqueue(*const []const u8, *audio.Sound, &messagepath, self.message_snd, worker.sound.loadSound);

        // delay
        try self.loader.enqueue(*const u64, *const u8, &delay, &zero, worker.delay.loadDelay);

        // mail
        try self.loader.enqueue(*const []const u8, *mail.EmailManager, &mailpath, self.emailManager, worker.mail.loadMail);

        // delay
        try self.loader.enqueue(*const u64, *const u8, &delay, &zero, worker.delay.loadDelay);

        // fonts
        try self.loader.enqueue(*const []const u8, *font.Font, &fontpath, self.face, worker.font.loadFontPath);

        self.load_progress = 0;

        self.loadingThread = try std.Thread.spawn(.{}, Self.loadThread, .{self});
        try self.loader.run(&self.load_progress);

        // setup some pointers
        pseudo.snd.audioPtr = self.audio_man;
        pseudo.win.shader = self.shader;

        wins.email.emailManager = self.emailManager;
        wins.email.notif = .{
            .texture = "icons",
            .data = .{
                .source = rect.newRect(0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                .size = undefined,
            },
        };
    }

    pub fn deinit(self: *Self) !void {
        self.loadingThread.join();
    }

    pub fn update(self: *Self, _: f32) !void {
        try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
            .targetState = .Windowed,
        });

        // play login sound
        try self.audio_man.playSound(self.login_snd);
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        const logoOff = size.sub(self.logo_sprite.data.size).div(2);

        // draw the logo
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.logo_sprite, self.shader, vecs.newVec3(logoOff.x, logoOff.y, 0));

        // progress bar
        self.load_sprite.data.size.x = (self.load_progress * 320 * 0.5 + self.load_sprite.data.size.x * 0.5);
        self.load_sprite.data.source.w = self.load_sprite.data.size.x / self.load_sprite.data.size.y;
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.load_sprite, self.shader, vecs.newVec3(logoOff.x, logoOff.y + 100, 0));

        if (self.load_sprite.data.size.x > 319)
            self.done.storeUnchecked(true);
    }

    pub fn keypress(_: *Self, _: c_int, _: c_int, _: bool) !void {}
    pub fn keychar(_: *Self, _: u32, _: c_int) !void {}
    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
