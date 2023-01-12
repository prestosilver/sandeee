const std = @import("std");
const allocator = @import("allocator.zig");

pub fn getContentPath(file: []const u8) [*c]const u8 {
    var result = std.ArrayList(u8).init(allocator.alloc);

    var args = std.process.ArgIterator.init();
    var first = args.next().?;

    std.ArrayList(u8).appendSlice(&result, @ptrCast([]const u8, first)) catch {};

    var stop: usize = 0;

    for (result.items) |item, idx| {
        if (item == '/') {
            stop = idx;
        }
    }

    result.resize(stop) catch {};

    std.ArrayList(u8).appendSlice(&result, "/") catch {};
    std.ArrayList(u8).appendSlice(&result, file) catch {};
    std.ArrayList(u8).appendSlice(&result, "\x00") catch {};

    return @ptrCast([*c]const u8, result.items);
}
