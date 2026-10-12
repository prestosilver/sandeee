const std = @import("std");
const util = @import("../util.zig");

const allocator = util.allocator;

disks_dir: *std.Io.Dir,

const DiskSorter = @This();

fn getDate(self: DiskSorter, name: []const u8) std.Io.Timestamp {
    const bad = std.Io.Clock.real.now(util.io);

    // return is fine here as this is used to sort
    const file = self.disks_dir.openFile(util.io, name, .{}) catch return bad;
    defer file.close(util.io);

    return (file.stat(util.io) catch return bad).mtime;
}

pub fn sort(ctx: DiskSorter, a: []const u8, b: []const u8) bool {
    return ctx.getDate(a).compare(.lt, ctx.getDate(b));
}
