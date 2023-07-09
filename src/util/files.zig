const std = @import("std");
const builtin = @import("builtin");
const allocator = @import("allocator.zig");

pub fn getContentPath(file: []const u8) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(allocator.alloc);

    if (builtin.os.tag == .windows) {
        try std.ArrayList(u8).appendSlice(&result, file);
        try std.ArrayList(u8).appendSlice(&result, "\x00");

        return result;
    }

    const first = try std.process.getCwdAlloc(allocator.alloc);
    defer allocator.alloc.free(first);

    try result.appendSlice(first);

    try std.ArrayList(u8).appendSlice(&result, "/");
    try std.ArrayList(u8).appendSlice(&result, file);

    return result;
}
