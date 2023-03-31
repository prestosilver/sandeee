const std = @import("std");
const mat4 = @import("../math/mat4.zig");
const c = @import("../c.zig");

pub const ShaderFile = struct {
    contents: [*c]const u8,
    kind: c.GLuint,
};

pub const Shader = struct {
    id: c.GLuint = 0,

    pub fn new(comptime total: u32, files: [total]ShaderFile) !Shader {
        var prog = c.glCreateProgram();
        var success: c.GLint = 0;

        for (files) |file| {
            var code = [1][*c]const u8{file.contents};

            var shader = c.glCreateShader(file.kind);
            defer c.glDeleteShader(shader);
            c.glShaderSource(shader, 1, &code, null);
            c.glCompileShader(shader);

            c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);

            if (success == 0) {
                var infoLog: [512]u8 = std.mem.zeroes([512]u8);

                c.glGetShaderInfoLog(shader, 512, null, &infoLog);
                std.log.err("{s}", .{infoLog});
                return error.CompileError;
            }

            c.glAttachShader(prog, shader);
        }

        c.glLinkProgram(prog);

        return Shader{
            .id = prog,
        };
    }

    pub fn setMat4(self: Shader, name: [*c]const u8, value: mat4.Mat4) void {
        c.glUseProgram(self.id);

        var loc = c.glGetUniformLocation(self.id, name);

        c.glUniformMatrix4fv(loc, 1, 0, &value.data.items[0]);
    }

    pub fn setInt(self: Shader, name: [*c]const u8, value: c_int) void {
        c.glUseProgram(self.id);

        var loc = c.glGetUniformLocation(self.id, name);

        c.glUniform1i(loc, value);
    }
};
