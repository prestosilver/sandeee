// TODO: new imports
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

const SplitResult = struct {
    path: []const u8,
    name: ?[]const u8,
    file: ?[]const u8,
    ext: ?[]const u8,
};

pub fn splitPath(path: []const u8) SplitResult {
    const slash = std.mem.lastIndexOf(u8, path, "/");
    const dot = if (slash) |slash_idx| // dot is after slash
        if (std.mem.lastIndexOf(u8, path[slash_idx..], ".")) |dot_idx|
            dot_idx + slash_idx
        else
            null
    else
        null;

    return .{
        .path = if (slash) |slash_idx| path[0..slash_idx] else path,
        .name = if (slash) |slash_idx|
            if (dot) |dot_idx|
                path[(slash_idx + 1)..dot_idx]
            else
                path[(slash_idx + 1)..]
        else
            null,
        .file = if (slash) |slash_idx| path[(slash_idx + 1)..] else null,
        .ext = if (dot) |dot_idx| path[(dot_idx + 1)..] else null,
    };
}

test "Path split fuzzing" {
    const Context = struct {
        fn testSplitpath(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const split = splitPath(input);
            if (split.file) |file| {
                try std.testing.expectFmt(input, "{s}/{s}", .{ split.path, file });

                if (split.name) |name| {
                    if (split.ext) |ext| {
                        try std.testing.expectFmt(file, "{s}.{s}", .{ name, ext });
                    } else {
                        try std.testing.expectEqualStrings(file, name);
                    }
                } else {
                    try std.testing.expectEqual(split.ext, null);
                }
            } else {
                try std.testing.expectEqual(split.name, null);
                try std.testing.expectEqual(split.ext, null);
                try std.testing.expectEqualStrings(input, split.path);
            }
        }
    };

    try std.testing.fuzz(Context{}, Context.testSplitpath, .{});
}
