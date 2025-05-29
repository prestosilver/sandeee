const std = @import("std");
const c = @import("../c.zig");

const Self = @This();

// time: u64 = if (@import("builtin").mode == .Debug) 0 else 45,
time: u64 = 100,

pub fn load(self: *const Self) anyerror!void {
    std.time.sleep(self.time * 1_000_000);
}

pub fn unload(_: *const Self) void {}
