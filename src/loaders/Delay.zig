const std = @import("std");

const Self = @This();

time: u64,

pub fn load(self: *const Self) !void {
    std.time.sleep(self.time * 1_000_000);
}
