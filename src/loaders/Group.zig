const std = @import("std");
const builtin = @import("builtin");
const c = @import("../c.zig");

const util = @import("../util.zig");

const Self = @This();

sleep: std.Io.Duration = if (builtin.mode == .Debug)
    .fromMilliseconds(0)
else
    .fromMilliseconds(100),

pub fn load(self: *const Self) anyerror!void {
    try std.Io.sleep(util.io, self.sleep, .real);
}

pub fn unload(_: *const Self) void {}
