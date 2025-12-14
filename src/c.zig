pub usingnamespace if (!@hasDecl(@import("root"), "isBuild"))
    @cImport({
        @cInclude("AL/al.h");
        @cInclude("AL/alc.h");
        @cInclude("AL/alreverb.c");
        @cInclude("signal.h");
    })
else
    struct {};
