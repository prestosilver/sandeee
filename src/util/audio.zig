const std = @import("std");

const c = @import("../c.zig");

pub const AudioErrors = error {
    AudioInit,
};

pub const Sound = struct {
    buffer: c.ALuint,

    pub fn init(data: []const u8) Sound {
        var result = Sound{
            .buffer = 0,
        };

        c.alGenBuffers(1, &result.buffer);
        c.alBufferData(result.buffer, c.AL_FORMAT_MONO8, &data[0], @intCast(c_int, data.len), 44100);

        return result;
    }

    pub fn deinit(self: *Sound) void {
        c.alDeleteBuffers(1, &self.buffer);
    }
};

pub const Audio = struct {
    pub const SOURCES = 30;

    sources: [SOURCES]c.ALuint,
    next: usize = 0,
    device: ?*c.ALCdevice,
    context: ?*c.ALCcontext,

    pub fn init() !Audio {
        var devicename = c.alcGetString(null, c.ALC_DEFAULT_DEVICE_SPECIFIER);

        var result = Audio{
            .sources = undefined,
            .device = undefined,
            .context = undefined,
        };

        result.device = c.alcOpenDevice(devicename);
        result.context = c.alcCreateContext(result.device, null);

        if (c.alcMakeContextCurrent(result.context) == 0) return error.AudioInit;

        c.alGenSources(SOURCES, &result.sources[0]);

        return result;
    }

    pub fn playSound(self: *Audio, snd: Sound) !void {
        var sourceState: c.ALint = 0;

        c.alGetSourcei(self.sources[self.next], c.AL_SOURCE_STATE, &sourceState);
        if (sourceState != c.AL_PLAYING) {
            c.alSourcei(self.sources[self.next], c.AL_BUFFER, @intCast(c_int, snd.buffer));

            c.alSourcePlay(self.sources[self.next]);
        }
        self.next += 1;

        if (self.next == SOURCES) self.next = 0;
    }
};
