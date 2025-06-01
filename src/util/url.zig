const std = @import("std");
const allocator = @import("allocator.zig");

pub const UrlKind = enum(u8) {
    Steam = '$',
    Web = '@',
    Local = '/',
    _,
};

const Self = @This();

kind: UrlKind,
domain: []const u8,
path: []const u8,

pub fn parse(path: []const u8) !Self {
    if (std.mem.count(u8, path, ":") > 1) return error.InvalidUrl;

    if (std.mem.indexOf(u8, path, ":")) |colon_index| {
        if (colon_index == 0)
            return error.InvalidUrl;

        return .{
            .kind = @as(UrlKind, @enumFromInt(path[0])),
            .domain = try allocator.alloc.dupe(u8, path[1..colon_index]),
            .path = try allocator.alloc.dupe(u8, path[(colon_index + 1)..]),
        };
    }

    if (path.len != 0 and @as(UrlKind, @enumFromInt(path[0])) == .Local) return .{
        .kind = .Local,
        .domain = try allocator.alloc.dupe(u8, ""),
        .path = try allocator.alloc.dupe(u8, path),
    };

    return error.InvalidUrl;
}

pub fn child(self: *const Self, path: []const u8) !Self {
    if (std.mem.count(u8, path, ":") > 1) return error.InvalidUrl;

    if (std.mem.indexOf(u8, path, ":")) |colon_index| {
        if (colon_index == 0)
            return error.InvalidUrl;

        return .{
            .kind = @as(UrlKind, @enumFromInt(path[0])),
            .domain = try allocator.alloc.dupe(u8, path[1..colon_index]),
            .path = try allocator.alloc.dupe(u8, path[(colon_index + 1)..]),
        };
    }

    if (self.path.len == 0) return .{
        .kind = self.kind,
        .domain = try allocator.alloc.dupe(u8, self.domain),
        .path = try allocator.alloc.dupe(u8, path[1..]),
    };

    if (path.len > 1 and @as(UrlKind, @enumFromInt(path[0])) == .Web) return .{
        .kind = self.kind,
        .domain = try allocator.alloc.dupe(u8, self.domain),
        .path = try allocator.alloc.dupe(u8, path[1..]),
    };

    if (std.mem.indexOf(u8, self.path, "/")) |slash_idx|
        return .{
            .kind = self.kind,
            .domain = try allocator.alloc.dupe(u8, self.domain),
            .path = try std.mem.concat(allocator.alloc, u8, &.{ self.path[1..slash_idx], "/", path }),
        };

    return error.InvalidUrl;
}

pub fn deinit(self: *const Self) void {
    allocator.alloc.free(self.domain);
    allocator.alloc.free(self.path);
}

test "Url parse fuzzing" {
    const Context = struct {
        fn testSplitpath(context: @This(), input: []const u8) anyerror!void {
            _ = context;

            for (input, 0..) |_, i| {
                const url = Self.parse(input[0..i]) catch continue;
                defer url.deinit();

                const child_url = url.child(input[i..]) catch continue;
                defer child_url.deinit();
            }
        }
    };

    try std.testing.fuzz(Context{}, Context.testSplitpath, .{});
}
