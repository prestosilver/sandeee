const std = @import("std");

const builtin = @import("builtin");

pub var gpa = std.heap.DebugAllocator(.{}){};
pub const allocator = if (builtin.is_test)
    std.testing.allocator
else if (builtin.mode == .debug)
    gpa.allocator()
else
    std.heap.smp_allocator;