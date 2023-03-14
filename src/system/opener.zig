const std = @import("std");
const files = @import("files.zig");

const OpenError = error{
    CommandNotFound,
};

pub fn openFile(file: []const u8) ![]const u8 {
    var back = std.mem.splitBackwards(u8, file, ".");
    var ext = back.first();
    var fileo = try files.root.getFile("/conf/opener.cfg");

    if (fileo) |filereal| {
        var cont = try filereal.read();
        var lines = std.mem.split(u8, cont, "\n");

        while (lines.next()) |line| {
            var line_iter = std.mem.split(u8, line, " ");
            var line_ext = line_iter.first();
            if (std.mem.eql(u8, ext, line_ext)) {
                return line[line_ext.len + 1 ..];
            }
        }
    }

    return error.CommandNotFound;
}
