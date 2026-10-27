const std = @import("std");
const options = @import("options");
const zaudio = @import("zaudio");

const util = @import("../util.zig");
const sandeee_data = @import("../data.zig");

const no_audio = options.disable_audio;

const log = util.log;

const allocator = util.allocator;

const sizes = sandeee_data.sizes;

pub const AudioErrors = error{
    AudioInit,
};

pub var instance: AudioManager = undefined;

const background_sound = @embedFile("bg.era");

pub const Sound = struct {
    valid: bool = false,
    buffer: *zaudio.AudioBuffer = undefined,
    sound: *zaudio.Sound = undefined,

    pub fn init(manager: AudioManager, data: []const u8) !Sound {
        if (no_audio) return undefined;

        const buf = zaudio.AudioBuffer.create(.init(
            .unsigned8,
            1,
            data.len,
            data.ptr,
        )) catch return error.Unimplemented;
        //defer audio_buffer.destroy();

        const snd = manager.engine.createSoundFromDataSource(buf.asDataSourceMut(), .{}, null) catch return error.Unimplemented;
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

    pub fn play(self: *const Sound) !void {
        if (no_audio) return;
        if (!self.valid) return;

        self.sound.start() catch return error.Unimplemented;
    }
};

pub const AudioManager = struct {
    engine: *zaudio.Engine,
    bg: Sound,
    mute: bool = false,

    pub fn init() !void {
        if (no_audio) return;

        zaudio.init(allocator);
        errdefer zaudio.deinit();

        var engine_config = zaudio.Engine.Config.init();
        engine_config.channels = 1;
        engine_config.sample_rate = 44100;

        const engine = zaudio.Engine.create(engine_config) catch return error.AudioInit;
        errdefer engine.destroy();

        instance = .{
            .engine = engine,
            .bg = undefined,
        };

        instance.bg = try Sound.init(instance, background_sound[4..]);
        instance.bg.sound.setLooping(true);
        instance.bg.sound.setVolume(0.25);

        try instance.bg.play();
        try instance.setVolume(0.5);
    }

    pub fn deinit(self: *AudioManager) void {
        if (no_audio) return;

        self.bg.sound.stop() catch {};
        self.bg.deinit();
        self.engine.destroy();
        zaudio.deinit();
    }

    pub fn setVolume(self: *AudioManager, volume: f32) !void {
        if (!self.mute)
            try self.engine.setVolume(volume);
    }

    pub fn setMuted(self: *AudioManager, mute: bool) !void {
        self.mute = mute;

        if (!self.mute)
            try self.engine.setVolume(0.5);

        if (self.mute)
            try self.engine.setVolume(0);
    }
};
