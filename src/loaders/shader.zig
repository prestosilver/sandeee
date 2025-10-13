const std = @import("std");
const c = @import("../c.zig");

const util = @import("../util/mod.zig");

const Shader = util.Shader;
const graphics = util.graphics;
const log = util.log;

const Self = @This();

files: [2]Shader.ShaderFile,
out: *Shader,

pub fn load(self: *const Self) anyerror!void {
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    log.debug("load shader", .{});
    self.out.* = try Shader.init(2, self.files);
    try graphics.Context.regShader(self.out.*);
}

pub fn unload(self: *const Self) void {
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    // save email data
    self.out.deinit();
}
