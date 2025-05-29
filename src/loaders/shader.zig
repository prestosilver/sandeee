const std = @import("std");
const shd = @import("../util/shader.zig");
const gfx = @import("../util/graphics.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

const Self = @This();

files: [2]shd.ShaderFile,
out: *shd.Shader,

pub fn load(self: *const Self) anyerror!void {
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    log.debug("load shader", .{});
    self.out.* = try shd.Shader.init(2, self.files);
    try gfx.Context.regShader(self.out.*);
}

pub fn unload(self: *const Self) void {
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    // save email data
    self.out.deinit();
}
