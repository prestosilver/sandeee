pub usingnamespace @cImport({
    if (!@import("builtin").is_test) {
        @cInclude("glad/glad.h");
        @cInclude("GLFW/glfw3.h");
        @cInclude("AL/al.h");
        @cInclude("AL/alc.h");
        @cInclude("AL/alreverb.c");
        @cInclude("signal.h");
    }
});
