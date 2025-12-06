const std = @import("std");
const c = @import("../c.zig");

const util = @import("../util/mod.zig");
const sandeee_data = @import("../data/mod.zig");

const log = util.log;

const sizes = sandeee_data.sizes;

pub const AudioErrors = error{
    AudioInit,
};

pub var instance: AudioManager = .{};

pub const Sound = struct {
    buffer: ?c.ALuint = null,

    pub fn init(data: []const u8) Sound {
        if (data.len == 0) return Sound{ .buffer = null };

        var buffer: c.ALuint = 0;

        c.alGenBuffers(1, &buffer);
        c.alBufferData(buffer, c.AL_FORMAT_MONO8, &data[0], @as(c_int, @intCast(data.len)), 44100);

        log.debug("Load sound len {0}", .{data.len});

        return .{
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *const Sound) void {
        if (self.buffer) |buffer| {
            c.alDeleteBuffers(1, &buffer);
        }
    }
};

const background_sound = @embedFile("../sounds/bg.era");

pub const AudioManager = struct {
    sources: [sizes.AUDIO_SOURCES]c.ALuint = std.mem.zeroes([sizes.AUDIO_SOURCES]c.ALuint),
    next: usize = 0,
    device: ?*c.ALCdevice = null,
    context: ?*c.ALCcontext = null,
    volume: f32 = 1.0,
    muted: bool = false,
    // effect: c.ALuint = 0,
    // slot: c.ALuint = 0,
    bg: c.ALuint = 0,

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

    pub fn init() !void {
        const device_name = c.alcGetString(null, c.ALC_DEFAULT_DEVICE_SPECIFIER);

        const device = c.alcOpenDevice(device_name);

        const context = c.alcCreateContext(device, null);

        if (c.alcMakeContextCurrent(context) == 0) return error.AudioInit;

        // c.alGenEffects = @ptrCast(@alignCast(c.alGetProcAddress("alGenEffects")));
        // c.alEffecti = @ptrCast(@alignCast(c.alGetProcAddress("alEffecti")));
        // c.alEffectf = @ptrCast(@alignCast(c.alGetProcAddress("alEffectf")));
        // c.alEffectfv = @ptrCast(@alignCast(c.alGetProcAddress("alEffectfv")));
        // c.alGenAuxiliaryEffectSlots = @ptrCast(@alignCast(c.alGetProcAddress("alGenAuxiliaryEffectSlots")));
        // c.alAuxiliaryEffectSloti = @ptrCast(@alignCast(c.alGetProcAddress("alAuxiliaryEffectSloti")));
        // const effect = c.LoadEffect(&eff);

        // var slot: c.ALuint = 0;

        // c.alGenAuxiliaryEffectSlots.?(1, &slot);
        // c.alAuxiliaryEffectSloti.?(slot, c.AL_EFFECTSLOT_AUXILIARY_SEND_AUTO, c.AL_TRUE);
        // c.alAuxiliaryEffectSloti.?(slot, c.AL_EFFECTSLOT_EFFECT, @intCast(effect));

        const background_data = Sound.init(background_sound);

        var sources = std.mem.zeroes([sizes.AUDIO_SOURCES]c.ALuint);

        // generate sources for sfx
        c.alGenSources(sizes.AUDIO_SOURCES, &sources);

        var bg: c.ALuint = 0;

        // generate bg sound
        c.alGenSources(1, &bg);

        // set bg properties
        // c.alSource3i(bg, c.AL_AUXILIARY_SEND_FILTER, @intCast(slot), 0, c.AL_FILTER_NULL);
        c.alSourcei(bg, c.AL_LOOPING, c.AL_TRUE);
        c.alSourcef(bg, c.AL_GAIN, 0.5);

        if (background_data.buffer) |buffer|
            c.alSourcei(bg, c.AL_BUFFER, @intCast(buffer));

        c.alSourcePlay(bg);

        instance = .{
            .device = device,
            .context = context,
            // .effect = effect,
            // .slot = slot,
            .bg = bg,
            .sources = sources,
        };
    }

    pub fn playSound(self: *AudioManager, snd: Sound) !void {
        if (self.muted) return;
        if (snd.buffer) |buffer| {
            var source_state: c.ALint = 0;

            c.alGetSourcei(self.sources[self.next], c.AL_SOURCE_STATE, &source_state);
            if (source_state != c.AL_PLAYING) {
                // c.alSource3i(self.sources[self.next], c.AL_AUXILIARY_SEND_FILTER, @intCast(self.slot), 0, c.AL_FILTER_NULL);
                c.alSourcei(self.sources[self.next], c.AL_BUFFER, @as(c_int, @intCast(buffer)));
                c.alSourcef(self.sources[self.next], c.AL_GAIN, self.volume);

                c.alSourcePlay(self.sources[self.next]);
            }
            self.next += 1;

            if (self.next == sizes.AUDIO_SOURCES) self.next = 0;
        }
    }
};
