const std = @import("std");
const files = @import("files.zig");

const OpenError = error{
    CommandNotFound,
};

pub fn openFile(path: []const u8) ![]const u8 {
    var back = std.mem.splitBackwardsScalar(u8, path, '.');
    const ext = back.first();
    const file = try files.root.getFile("/conf/opener.cfg");

    const cont = try file.read(null);
    var lines = std.mem.splitScalar(u8, cont, '\n');

    while (lines.next()) |line| {
        const space_idx = std.mem.indexOf(u8, line, " ") orelse continue;
        const line_ext = line[0..space_idx];
        if (std.mem.eql(u8, ext, line_ext)) {
            return line[space_idx + 1 ..];
        }
    }

    return error.CommandNotFound;
}
