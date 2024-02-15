const std = @import("std");
const files = @import("files.zig");

const OpenError = error{
    CommandNotFound,
};

pub fn openFile(path: []const u8) ![]const u8 {
    var back = std.mem.splitBackwards(u8, path, ".");
    const ext = back.first();
    const file = try files.root.getFile("/conf/opener.cfg");

    const cont = try file.read(null);
    var lines = std.mem.split(u8, cont, "\n");

    while (lines.next()) |line| {
        const spaceIdx = std.mem.indexOf(u8, line, " ") orelse continue;
        const line_ext = line[0..spaceIdx];
        if (std.mem.eql(u8, ext, line_ext)) {
            return line[spaceIdx + 1 ..];
        }
    }

    return error.CommandNotFound;
}
