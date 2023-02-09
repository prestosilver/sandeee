const std = @import("std");

const builtin = @import("builtin");
pub const useclib = false;

pub var arena = std.heap.GeneralPurposeAllocator(.{}){};
pub const alloc = if(!builtin.link_libc or !useclib) arena.allocator() else std.heap.c_allocator;
