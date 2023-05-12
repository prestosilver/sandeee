const std = @import("std");
const shd = @import("../util/shader.zig");
const sb = @import("../util/spritebatch.zig");
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

pub const GSLoading = struct {
    const Self = @This();

    const textureNames = [_][2][]const u8{
        .{ "window_frame_path", "win" },
        .{ "web_texture_path", "web" },
        .{ "wallpaper_path", "wall" },
        .{ "bar_texture_path", "bar" },
        .{ "notif_texture_path", "notif" },
        .{ "editor_texture_path", "editor" },
        .{ "scroll_texture_path", "scroll" },
        .{ "email_texture_path", "email" },
        .{ "explorer_texture_path", "explorer" },
        .{ "cursor_texture_path", "cursor" },
        .{ "bar_logo_path", "barlogo" },
    };

    const loginpath: []const u8 = "/cont/snds/login.era";
    const messagepath: []const u8 = "/cont/snds/message.era";
    const settingspath: []const u8 = "/conf/system.cfg";
    const fontpath: []const u8 = "/cont/fnts/main.eff";
    const zero: u8 = 0;
    const delay: u64 = 300;

    load_progress: f32 = 0,
    login_snd: audio.Sound = undefined,
    message_snd: *audio.Sound,
    done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),

    sb: *sb.SpriteBatch,

    loading: *const fn (*Self) void,

    textureManager: *texMan.TextureManager,
    face: *font.Font,

    logo_sprite: sp.Sprite,
    load_sprite: sp.Sprite,
    shader: *shd.Shader,
    settingManager: *conf.SettingManager,
    disk: *?[]u8,
    audio_man: *audio.Audio,

    ctx: *gfx.Context,

    loadingThread: std.Thread = undefined,

    loader: *worker.WorkerContext,

    fn loadThread(self: *Self) void {
        self.loading(self);
    }

    pub fn setup(self: *Self) !void {
        self.done.storeUnchecked(false);
        defer self.done.storeUnchecked(true);

        worker.texture.settingManager = self.settingManager;
        worker.texture.textureManager = self.textureManager;

        // files
        try self.loader.enqueue(*?[]u8, *const u8, self.disk, &zero, worker.files.loadFiles);

        // settings
        try self.loader.enqueue(*const []const u8, *conf.SettingManager, &settingspath, self.settingManager, worker.settings.loadSettings);

        // textures
        for (&textureNames) |*textureEntry| {
            try self.loader.enqueue(*const []const u8, *const []const u8, &textureEntry[0], &textureEntry[1], worker.texture.loadTexture);
        }

        // delay
        try self.loader.enqueue(*const u64, *const u8, &delay, &zero, worker.delay.loadDelay);

        // sounds
        try self.loader.enqueue(*const []const u8, *audio.Sound, &loginpath, &self.login_snd, worker.sound.loadSound);
        try self.loader.enqueue(*const []const u8, *audio.Sound, &messagepath, self.message_snd, worker.sound.loadSound);

        // mail
        try self.loader.enqueue(*const u8, *const u8, &zero, &zero, worker.mail.loadMail);

        // fonts
        try self.loader.enqueue(*const []const u8, *font.Font, &fontpath, self.face, worker.font.loadFontPath);

        // delay
        try self.loader.enqueue(*const u64, *const u8, &delay, &zero, worker.delay.loadDelay);

        self.loadingThread = try std.Thread.spawn(.{}, Self.loadThread, .{self});
        self.loader.run(&self.load_progress) catch {
            self.done.storeUnchecked(true);
            @panic("BootEEE failed, Problaby missing file");
        };

        // setup some pointers
        pseudo.snd.audioPtr = self.audio_man;
        pseudo.win.shader = self.shader;

        wins.settings.settingManager = self.settingManager;
        wins.email.notif = .{
            .texture = "email",
            .data = .{
                .source = rect.newRect(0.5, 0.75, 0.5, 0.25),
                .size = undefined,
            },
        };
    }

    pub fn deinit(self: *Self) !void {
        self.loadingThread.join();
    }

    pub fn update(self: *Self, _: f32) !void {
        events.em.sendEvent(systemEvs.EventStateChange{
            .targetState = .Windowed,
        });

        // play login sound
        try self.audio_man.playSound(self.login_snd);
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        var logoOff = size.sub(self.logo_sprite.data.size).div(2);

        // draw the logo
        try self.sb.draw(sp.Sprite, &self.logo_sprite, self.shader, vecs.newVec3(logoOff.x, logoOff.y, 0));

        // progress bar
        // self.load_sprite.data.size.x = (self.load_progress * 320 + self.load_sprite.data.size.x) / 2;

        for (0..@floatToInt(usize, self.load_progress * 32)) |idx| {
            try self.sb.draw(sp.Sprite, &self.load_sprite, self.shader, vecs.newVec3(logoOff.x + @intToFloat(f32, 10 * idx), logoOff.y + 100, 0));
        }
    }

    pub fn keypress(_: *Self, _: c_int, _: c_int, _: bool) !bool {
        return false;
    }

    pub fn keychar(_: *Self, _: u32, _: c_int) !void {}
    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
