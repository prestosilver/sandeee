const std = @import("std");
const options = @import("options");
const zaudio = @import("zaudio");

const util = @import("../util.zig");
const sandeee_data = @import("../data.zig");

const no_audio = options.disable_audio;

const log = util.log;

const allocator = util.allocator;

const sizes = sandeee_data.sizes;

pub const Error = zaudio.Error;

pub var instance: Context = undefined;

const background_sound = @embedFile("bg.era");

pub const Sound = struct {
    valid: bool = false,
    buffer: *zaudio.AudioBuffer = undefined,
    sound: *zaudio.Sound = undefined,

    pub fn init(manager: Context, data: []const u8) Error!Sound {
        if (no_audio) return undefined;

        const buf = try zaudio.AudioBuffer.create(.init(
            .unsigned8,
            1,
            data.len,
            data.ptr,
        ));

        const snd = try manager.engine.createSoundFromDataSource(buf.asDataSourceMut(), .{}, null);
        return .{
            .valid = true,
            .buffer = buf,
            .sound = snd,
        };
    }

    pub fn deinit(self: *Sound) void {
        if (no_audio) return;

        self.valid = false;
        self.sound.stop() catch {};
        self.sound.destroy();
        self.buffer.destroy();
    }

    pub fn play(self: *const Sound) Error!void {
        if (no_audio) return;
        if (!self.valid) return;

        try self.sound.start();
    }
};

pub const Context = struct {
    engine: *zaudio.Engine,
    bg: Sound,
    mute: bool = false,

    pub fn init() Error!void {
        if (no_audio) return;

        zaudio.init(allocator);
        errdefer zaudio.deinit();

        var engine_config = zaudio.Engine.Config.init();
        engine_config.channels = 1;
        engine_config.sample_rate = 44100;

        const engine = try zaudio.Engine.create(engine_config);
        errdefer engine.destroy();

        instance = .{
            .engine = engine,
            .bg = undefined,
        };

        instance.bg = try Sound.init(instance, background_sound);
        instance.bg.sound.setLooping(true);
        instance.bg.sound.setVolume(0.25);

        try instance.bg.play();
        try instance.setVolume(0.5);
    }

    pub fn deinit() void {
        if (no_audio) return;

        instance.bg.sound.stop() catch {};
        instance.bg.deinit();
        instance.engine.destroy();
        zaudio.deinit();
    }

    pub fn setVolume(self: *Context, volume: f32) Error!void {
        if (!self.mute)
            try self.engine.setVolume(volume);
    }

    pub fn setMuted(self: *Context, mute: bool) Error!void {
        self.mute = mute;

        if (!self.mute)
            try self.engine.setVolume(0.5);

        if (self.mute)
            try self.engine.setVolume(0);
    }
};
