const std = @import("std");

const builtin = @import("builtin");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
pub const alloc = if(!builtin.link_libc) arena.allocator() else std.heap.c_allocator;
