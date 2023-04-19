const std = @import("std");
const shd = @import("../util/shader.zig");
const sb = @import("../util/spritebatch.zig");
const sp = @import("../drawers/sprite2d.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const worker = @import("../loaders/worker.zig");
const fm = @import("../util/files.zig");
const audio = @import("../util/audio.zig");
const conf = @import("../system/config.zig");
const tex = @import("../util/texture.zig");
const font = @import("../util/font.zig");
const gfx = @import("../util/graphics.zig");
const wins = @import("../windows/all.zig");
const pseudo = @import("../system/pseudo/all.zig");
const shell = @import("../system/shell.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");

pub const GSLoading = struct {
    const Self = @This();

    const winpath: []const u8 = "window_frame_path";
    const webpath: []const u8 = "web_textrure_path";
    const wallpath: []const u8 = "wallpaper_path";
    const barpath: []const u8 = "bar_texture_path";
    const editorpath: []const u8 = "editor_texture_path";
    const scrollpath: []const u8 = "scroll_texture_path";
    const emailpath: []const u8 = "email_texture_path";
    const explorerpath: []const u8 = "explorer_texture_path";
    const cursorpath: []const u8 = "cursor_texture_path";
    const barlogopath: []const u8 = "bar_logo_path";
    const loginpath: []const u8 = "/cont/snds/login.era";
    const settingspath: []const u8 = "/conf/system.cfg";
    const zero: u8 = 0;
    const delay: u64 = 300;

    load_progress: f32 = 0,
    login_snd: audio.Sound = undefined,
    done: bool = false,

    sb: *sb.SpriteBatch,

    loading: *const fn (*Self) void,

    wintex: *tex.Texture,
    webtex: *tex.Texture,
    bartex: *tex.Texture,
    walltex: *tex.Texture,
    emailtex: *tex.Texture,
    editortex: *tex.Texture,
    scrolltex: *tex.Texture,
    cursortex: *tex.Texture,
    barlogotex: *tex.Texture,
    explorertex: *tex.Texture,
    face: *font.Font,

    logo_sprite: sp.Sprite,
    load_sprite: sp.Sprite,
    shader: *shd.Shader,
    settingManager: *conf.SettingManager,
    disk: *?[]u8,
    audio_man: *audio.Audio,

    ctx: *gfx.Context,

    loader: *worker.WorkerContext,

    fn loadThread(self: *Self) void {
        self.loading(self);
    }

    pub fn setup(self: *Self) !void {
        self.done = false;
        var fontpath = fm.getContentPath("content/font.ttf");
        defer fontpath.deinit();

        worker.texture.settingManager = self.settingManager;

        // files
        try self.loader.enqueue(self.disk, &zero, worker.files.loadFiles);

        // settings
        try self.loader.enqueue(&settingspath, self.settingManager, worker.settings.loadSettings);

        // textures
        try self.loader.enqueue(&winpath, self.wintex, worker.texture.loadTexture);
        try self.loader.enqueue(&webpath, self.webtex, worker.texture.loadTexture);
        try self.loader.enqueue(&barpath, self.bartex, worker.texture.loadTexture);
        try self.loader.enqueue(&wallpath, self.walltex, worker.texture.loadTexture);
        try self.loader.enqueue(&emailpath, self.emailtex, worker.texture.loadTexture);
        try self.loader.enqueue(&scrollpath, self.scrolltex, worker.texture.loadTexture);
        try self.loader.enqueue(&editorpath, self.editortex, worker.texture.loadTexture);
        try self.loader.enqueue(&cursorpath, self.cursortex, worker.texture.loadTexture);
        try self.loader.enqueue(&barlogopath, self.barlogotex, worker.texture.loadTexture);
        try self.loader.enqueue(&explorerpath, self.explorertex, worker.texture.loadTexture);

        // delay
        try self.loader.enqueue(&delay, &zero, worker.delay.loadDelay);

        // sounds
        try self.loader.enqueue(&loginpath, &self.login_snd, worker.sound.loadSound);

        // mail
        try self.loader.enqueue(&zero, &zero, worker.mail.loadMail);

        // fonts
        try self.loader.enqueue(&fontpath.items, self.face, worker.font.loadFont);

        // delay
        try self.loader.enqueue(&delay, &zero, worker.delay.loadDelay);

        _ = try std.Thread.spawn(.{}, Self.loadThread, .{self});
        self.loader.run(&self.load_progress) catch {
            @panic("BootEEE failed, Problaby missing file");
        };

        // setup some pointers
        pseudo.snd.audioPtr = self.audio_man;
        pseudo.win.shader = self.shader;
        pseudo.win.wintex = self.wintex;

        wins.settings.settingManager = self.settingManager;

        shell.wintex = self.wintex;
        shell.webtex = self.webtex;
        shell.edittex = self.editortex;
        shell.shader = self.shader;

        self.audio_man.* = try audio.Audio.init();

        // play login sound
        try self.audio_man.playSound(self.login_snd);

        events.em.sendEvent(systemEvs.EventStateChange{
            .targetState = .Windowed,
        });

        self.done = true;
    }

    pub fn deinit(_: *Self) !void {}

    pub fn update(_: *Self, _: f32) !void {}

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

    pub fn keypress(_: *Self, _: c_int, _: c_int) !bool {
        return false;
    }

    pub fn keychar(_: *Self, _: u32, _: c_int) !void {}
    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
