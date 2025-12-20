const std = @import("std");
const zgl = @import("zgl");

const util = @import("../util.zig");
const math = @import("../math.zig");

const Mat4 = math.Mat4;

const allocator = util.allocator;
const log = util.log;

// TODO: make shader manager, split shaders into multiple

pub const ShaderFile = struct {
    contents: []const u8,
    kind: zgl.ShaderType,
};

const Shader = @This();

program: zgl.Program = .invalid,

pub fn init(comptime total: u32, files: [total]ShaderFile) !Shader {
    const program = zgl.createProgram();

    for (files) |file| {
        const code = [1][]const u8{file.contents};

        const shader = zgl.createShader(file.kind);
        defer shader.delete();
        shader.source(1, &code);
        shader.compile();

        if (shader.get(.compile_status) == 0) {
            const info_log = try shader.getCompileLog(allocator);
            defer allocator.free(info_log);

            log.err("{s}", .{info_log});

            return error.CompileError;
        }

        program.attach(shader);
    }

    program.link();

    if (program.get(.link_status) == 0) {
        const info_log = try program.getCompileLog(allocator);
        defer allocator.free(info_log);

        return error.CompileError;
    }

    return Shader{
        .program = program,
    };
}

pub fn deinit(self: Shader) void {
    self.program.delete();
}

pub fn setMat4(self: Shader, name: [:0]const u8, value: Mat4) void {
    // TODO: check if this errors
    const loc = self.program.uniformLocation(name);
    self.program.uniformMatrix4(loc, false, &.{@bitCast(value.data)});
}

pub fn setInt(self: Shader, name: [:0]const u8, value: c_int) void {
    const loc = self.program.uniformLocation(name);
    self.program.uniform1i(loc, value);
}

pub fn setFloat(self: Shader, name: [:0]const u8, value: f32) void {
    const loc = self.program.uniformLocation(name);
    self.program.uniform1f(loc, value);
}
