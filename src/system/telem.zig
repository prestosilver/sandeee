const std = @import("std");

pub const Telem = struct {
    pub var instance: Telem = .{};

    logins: u64 = 0,
    instructionCalls: u128 = 0,
};
