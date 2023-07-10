const std = @import("std");

const c = @import("../c.zig");

pub const AudioErrors = error{
    AudioInit,
};

pub const Sound = struct {
    buffer: c.ALuint,

    pub fn init(data: []const u8) Sound {
        var result = Sound{
            .buffer = 0,
        };

        c.alGenBuffers(1, &result.buffer);
        c.alBufferData(result.buffer, c.AL_FORMAT_MONO8, &data[0], @as(c_int, @intCast(data.len)), 44100);

        return result;
    }

    pub fn deinit(self: *const Sound) void {
        c.alDeleteBuffers(1, &self.buffer);
    }
};

const bgSound = @embedFile("../sounds/bg.era");

pub const Audio = struct {
    pub const SOURCES = 30;

    sources: [SOURCES]c.ALuint,
    next: usize = 0,
    device: ?*c.ALCdevice,
    context: ?*c.ALCcontext,
    volume: f32 = 1.0,
    muted: bool = false,
    effect: c.ALuint,
    slot: c.ALuint,
    bg: c.ALuint,

    const eff = c.EFXEAXREVERBPROPERTIES{
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

    pub fn init() !Audio {
        var result = Audio{
            .sources = undefined,
            .device = undefined,
            .context = undefined,
            .effect = undefined,
            .slot = 0,
            .bg = undefined,
        };

        const devicename = c.alcGetString(null, c.ALC_DEFAULT_DEVICE_SPECIFIER);

        result.device = c.alcOpenDevice(devicename);

        result.context = c.alcCreateContext(result.device, null);

        if (c.alcMakeContextCurrent(result.context) == 0) return error.AudioInit;

        c.alGenEffects = @ptrCast(@alignCast(c.alGetProcAddress("alGenEffects")));
        c.alEffecti = @ptrCast(@alignCast(c.alGetProcAddress("alEffecti")));
        c.alEffectf = @ptrCast(@alignCast(c.alGetProcAddress("alEffectf")));
        c.alEffectfv = @ptrCast(@alignCast(c.alGetProcAddress("alEffectfv")));
        c.alGenAuxiliaryEffectSlots = @ptrCast(@alignCast(c.alGetProcAddress("alGenAuxiliaryEffectSlots")));
        c.alAuxiliaryEffectSloti = @ptrCast(@alignCast(c.alGetProcAddress("alAuxiliaryEffectSloti")));

        result.effect = c.LoadEffect(&eff);

        c.alGenAuxiliaryEffectSlots.?(1, &result.slot);
        c.alAuxiliaryEffectSloti.?(result.slot, c.AL_EFFECTSLOT_AUXILIARY_SEND_AUTO, c.AL_TRUE);
        c.alAuxiliaryEffectSloti.?(result.slot, c.AL_EFFECTSLOT_EFFECT, @intCast(result.effect));

        const bgData = Sound.init(bgSound);

        // generate sources for sfx
        c.alGenSources(SOURCES, &result.sources);

        // generate bg sound
        c.alGenSources(1, &result.bg);

        // set bg properties
        c.alSource3i(result.bg, c.AL_AUXILIARY_SEND_FILTER, @intCast(result.slot), 0, c.AL_FILTER_NULL);
        c.alSource3f(result.bg, c.AL_POSITION, 0, 1.5, 0);
        c.alSourcei(result.bg, c.AL_LOOPING, c.AL_TRUE);
        c.alSourcef(result.bg, c.AL_GAIN, 0.5);

        c.alSourcei(result.bg, c.AL_BUFFER, @intCast(bgData.buffer));

        c.alSourcePlay(result.bg);

        return result;
    }

    pub fn playSound(self: *Audio, snd: Sound) !void {
        if (self.muted) return;

        var sourceState: c.ALint = 0;

        c.alGetSourcei(self.sources[self.next], c.AL_SOURCE_STATE, &sourceState);
        if (sourceState != c.AL_PLAYING) {
            c.alSource3i(self.sources[self.next], c.AL_AUXILIARY_SEND_FILTER, @intCast(self.slot), 0, c.AL_FILTER_NULL);
            c.alSourcei(self.sources[self.next], c.AL_BUFFER, @as(c_int, @intCast(snd.buffer)));
            c.alSourcef(self.sources[self.next], c.AL_GAIN, self.volume);

            c.alSource3f(self.sources[self.next], c.AL_POSITION, 0, 1.5, 0);

            c.alSourcePlay(self.sources[self.next]);
        }
        self.next += 1;

        if (self.next == SOURCES) self.next = 0;
    }
};
