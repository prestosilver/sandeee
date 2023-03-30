const std = @import("std");
const builtin = @import("builtin");
const allocator = @import("allocator.zig");

pub fn getContentPath(file: []const u8) std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(allocator.alloc);

    if (builtin.os.tag == .windows) {
        std.ArrayList(u8).appendSlice(&result, file) catch {};
        std.ArrayList(u8).appendSlice(&result, "\x00") catch {};

        return result;
    }

    var first = std.process.getCwdAlloc(allocator.alloc) catch "";

    result.appendSlice(first) catch {};

    std.ArrayList(u8).appendSlice(&result, "/") catch {};
    std.ArrayList(u8).appendSlice(&result, file) catch {};

    return result;
}

pub fn getContentDir() []const u8 {
    return std.process.getCwdAlloc(allocator.alloc) catch "";
}
