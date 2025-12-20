const std = @import("std");

const builtin = @import("builtin");
pub const useclib = builtin.mode != .Debug;

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = if (builtin.is_test)
    std.testing.allocator
else if (builtin.link_libc and useclib)
    std.heap.c_allocator
else
    gpa.allocator();
