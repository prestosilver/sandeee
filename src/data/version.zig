const std = @import("std");

const Version = @This();

program: []const u8,
phase: enum { seed, sapling, tree },
index: usize,
meta: ?[]const u8 = null,

pub fn format(
    self: Version,
    writer: anytype,
) !void {
    return if (self.meta) |meta|
        writer.print("{s}#{}_{s}", .{ @tagName(self.phase), self.index, meta })
    else
        writer.print("{s}#{}", .{ @tagName(self.phase), self.index });
}
