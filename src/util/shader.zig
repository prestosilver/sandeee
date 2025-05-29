const std = @import("std");
const mat4 = @import("../math/mat4.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

pub const ShaderFile = struct {
    contents: [*c]const u8,
    kind: c.GLuint,
};

pub const Shader = struct {
    id: c.GLuint = 0,

    pub fn init(comptime total: u32, files: [total]ShaderFile) !Shader {
        const prog = c.glCreateProgram();
        var success: c.GLint = 0;

        for (files) |file| {
            const code = [1][*c]const u8{file.contents};

            const shader = c.glCreateShader(file.kind);
            defer c.glDeleteShader(shader);
            c.glShaderSource(shader, 1, &code, null);
            c.glCompileShader(shader);

            c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);

            if (success == 0) {
                var info_log = [_]u8{0} ** 512;

                c.glGetShaderInfoLog(shader, 512, null, &info_log);
                log.err("{s}", .{info_log});
                return error.CompileError;
            }

            c.glAttachShader(prog, shader);
        }

        c.glLinkProgram(prog);

        c.glGetProgramiv(prog, c.GL_LINK_STATUS, &success);

        if (success == 0) {
            var info_log = [_]u8{0} ** 512;

            c.glGetProgramInfoLog(prog, 512, null, &info_log);
            log.err("{s}", .{info_log});
            return error.CompileError;
        }

        return Shader{
            .id = prog,
        };
    }

    pub fn deinit(self: Shader) void {
        c.glDeleteProgram(self.id);
    }

    pub fn setMat4(self: Shader, name: [*c]const u8, value: mat4.Mat4) void {
        c.glUseProgram(self.id);

        const loc = c.glGetUniformLocation(self.id, name);

        c.glUniformMatrix4fv(loc, 1, 0, &value.data);
    }

    pub fn setInt(self: Shader, name: [*c]const u8, value: c_int) void {
        c.glUseProgram(self.id);

        const loc = c.glGetUniformLocation(self.id, name);

        c.glUniform1i(loc, value);
    }

    pub fn setFloat(self: Shader, name: [*c]const u8, value: f32) void {
        c.glUseProgram(self.id);

        const loc = c.glGetUniformLocation(self.id, name);

        c.glUniform1f(loc, value);
    }
};
