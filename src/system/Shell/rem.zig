const std = @import("std");

const system = @import("../../system.zig");
const util = @import("../../util.zig");

const Shell = system.Shell;
const files = system.files;

const allocator = util.allocator;

pub const NAME = "rem";
pub const DESCRIPTION = "Deletes a file";
pub const HELP =
    \\rem [:help] paths+
;

pub fn rem(self: *Shell, params: *Shell.Params) !Shell.Result {
    if (params.peek() == null)
        return error.MissingParameter;
    // TODO: /root
    const root = try self.root.resolve();
    while (params.next()) |path| {
        try root.removeFile(path);
    }

    return .{
        .data = try allocator.dupe(u8, "Removed"),
    };
}
