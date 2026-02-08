const std = @import("std");

const system = @import("../../system.zig");
const util = @import("../../util.zig");

const Shell = system.Shell;
const files = system.files;

const allocator = util.allocator;

pub const NAME = "drem";
pub const DESCRIPTION = "Deletes a directory";
pub const HELP =
    \\drem [:help] paths+
;

pub fn drem(self: *Shell, params: *Shell.Params) !Shell.Result {
    if (params.peek() == null)
        return error.MissingParameter;

    const root = try self.root.resolve();
    while (params.next()) |path| {
        try root.removeFolder(path);
    }

    return .{
        .data = try allocator.dupe(u8, "Removed"),
    };
}
