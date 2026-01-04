const std = @import("std");
const builtin = @import("builtin");
const c = @import("../c.zig");

const Self = @This();

time: u64 = if (builtin.mode == .Debug) 0 else 100,

pub fn load(self: *const Self) anyerror!void {
    std.Thread.sleep(self.time * 1_000_000);
}

pub fn unload(_: *const Self) void {}
