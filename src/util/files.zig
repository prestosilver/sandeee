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

    var args = std.process.ArgIterator.initWithAllocator(allocator.alloc) catch {
        return result;
    };
    defer args.deinit();
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

    return result;
}

pub fn getContentDir() []const u8 {
    var args = std.process.ArgIterator.initWithAllocator(allocator.alloc) catch {
        return "";
    };
    defer args.deinit();
    var first = args.next().?;

    var stop: usize = 0;

    for (first) |item, idx| {
        if (item == '/') {
            stop = idx;
        }
    }

    var result = first[0..stop];

    return result;
}
