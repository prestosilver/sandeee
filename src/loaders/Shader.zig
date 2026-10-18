const std = @import("std");

const util = @import("../util.zig");

const Shader = util.Shader;
const graphics = util.graphics;
const log = util.log;

const Self = @This();

files: [2]Shader.ShaderFile,
out: *Shader,
name: []const u8,

pub fn load(self: *const Self) !void {
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    self.out.* = try Shader.init(2, self.files);
    try graphics.Context.regShader(self.out.*);

    log.debug("Loaded the {s} shader", .{self.name});
}

pub fn unload(self: *const Self) void {
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    // deinit the shader
    self.out.deinit();

    log.debug("Unloaded the {s} shader", .{self.name});
}
