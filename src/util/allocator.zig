const std = @import("std");

const builtin = @import("builtin");
pub const useclib = true;

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var arena = std.heap.ArenaAllocator.init(gpa.allocator());
pub const alloc = if(!builtin.link_libc or !useclib) arena.allocator() else std.heap.c_allocator;
