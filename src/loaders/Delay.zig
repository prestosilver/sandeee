const std = @import("std");
const c = @import("../c.zig");

const Self = @This();

time: u64,

pub fn load(self: *const Self) anyerror!void {
    std.time.sleep(self.time * 1_000_000);
}
