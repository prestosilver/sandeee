pub usingnamespace //if (!@import("builtin").is_test)
@cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("AL/al.h");
    @cInclude("AL/alc.h");
    @cInclude("AL/alreverb.c");
    @cInclude("signal.h");
});
//else
//    struct {
//        pub const GLuint = @compileError("use GLuint");
//        pub const GLFWwindow = @compileError("use GLFWwindow");
//    };
