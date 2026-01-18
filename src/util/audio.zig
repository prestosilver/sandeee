const std = @import("std");
const c = @import("../c.zig");
const options = @import("options");

const util = @import("../util.zig");
const sandeee_data = @import("../data.zig");

const no_audio = options.disable_audio;

const al = c.al;

const log = util.log;

const sizes = sandeee_data.sizes;

pub const AudioErrors = error{
    AudioInit,
};

pub var instance: AudioManager = .{};

pub const Sound = struct {
    buffer: ?al.ALuint = null,

    pub fn init(data: []const u8) Sound {
        if (no_audio) return .{};

        if (data.len == 0) return Sound{ .buffer = null };

        var buffer: al.ALuint = 0;

        al.alGenBuffers(1, &buffer);
        al.alBufferData(buffer, al.AL_FORMAT_MONO8, &data[0], @as(c_int, @intCast(data.len)), 44100);

        log.debug("Load sound len {0}", .{data.len});

        return .{
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *const Sound) void {
        if (no_audio) return;

        if (self.buffer) |buffer| {
            al.alDeleteBuffers(1, &buffer);
        }
    }
};

const background_sound = @embedFile("bg.era");

pub const AudioManager = struct {
    sources: [sizes.AUDIO_SOURCES]al.ALuint = std.mem.zeroes([sizes.AUDIO_SOURCES]al.ALuint),
    next: usize = 0,
    device: ?*al.ALCdevice = null,
    context: ?*al.ALCcontext = null,
    volume: f32 = 1.0,
    muted: bool = false,
    bg: al.ALuint = 0,

    const eff = al.EFXEAXREVERBPROPERTIES{
        .flDensity = 0.4287,
        .flDiffusion = 1.0000,
        .flGain = 0.3162,
        .flGainHF = 0.5929,
        .flGainLF = 1.0000,
        .flDecayTime = 0.4000,
        .flDecayHFRatio = 0.8300,
        .flDecayLFRatio = 1.0000,
        .flReflectionsGain = 0.1503,
        .flReflectionsDelay = 0.0020,
        .flReflectionsPan = .{ 0.0000, 0.0000, 0.0000 },
        .flLateReverbGain = 1.0629,
        .flLateReverbDelay = 0.0030,
        .flLateReverbPan = .{ 0.0000, 0.0000, 0.0000 },
        .flEchoTime = 0.2500,
        .flEchoDepth = 0.1,
        .flModulationTime = 0.2500,
        .flModulationDepth = 0.0000,
        .flAirAbsorptionGainHF = 0.9943,
        .flHFReference = 5000.0000,
        .flLFReference = 250.0000,
        .flRoomRolloffFactor = 0.0000,
        .iDecayHFLimit = 0x1,
    };

    pub fn init() !void {
        if (no_audio) return;

        const device_name = al.alGetString(al.ALC_DEFAULT_DEVICE_SPECIFIER);

        const device = al.alcOpenDevice(device_name);

        const context = al.alcCreateContext(device, null);

        if (al.alcMakeContextCurrent(context) == 0) return error.AudioInit;

        const background_data = Sound.init(background_sound);

        var sources = std.mem.zeroes([sizes.AUDIO_SOURCES]al.ALuint);

        // generate sources for sfx
        al.alGenSources(sizes.AUDIO_SOURCES, &sources);

        var bg: al.ALuint = 0;

        // generate bg sound
        al.alGenSources(1, &bg);

        // set bg properties
        al.alSourcei(bg, al.AL_LOOPING, al.AL_TRUE);
        al.alSourcef(bg, al.AL_GAIN, 0.5);

        if (background_data.buffer) |buffer|
            al.alSourcei(bg, al.AL_BUFFER, @intCast(buffer));

        al.alSourcePlay(bg);

        instance = .{
            .device = device,
            .context = context,
            .bg = bg,
            .sources = sources,
        };
    }

    pub fn playSound(self: *AudioManager, snd: Sound) !void {
        if (no_audio) return;

        if (self.muted) return;
        if (snd.buffer) |buffer| {
            var source_state: al.ALint = 0;

            al.alGetSourcei(self.sources[self.next], al.AL_SOURCE_STATE, &source_state);
            if (source_state != al.AL_PLAYING) {
                al.alSourcei(self.sources[self.next], al.AL_BUFFER, @as(c_int, @intCast(buffer)));
                al.alSourcef(self.sources[self.next], al.AL_GAIN, self.volume);

                al.alSourcePlay(self.sources[self.next]);
            }
            self.next += 1;

            if (self.next == sizes.AUDIO_SOURCES) self.next = 0;
        }
    }
};
