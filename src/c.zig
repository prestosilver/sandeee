pub const al =
    @cImport({
        @cInclude("AL/al.h");
        @cInclude("AL/alc.h");
        @cInclude("AL/alreverb.c");
        @cInclude("signal.h");
    });
