const std = @import("std");

const system = @import("../../system.zig");
const util = @import("../../util.zig");

const Shell = system.Shell;
const files = system.files;

const allocator = util.allocator;

pub const NAME = "dnew";
pub const DESCRIPTION = "Creates a new directory";
pub const HELP = "dnew [:help] [:parent] paths+";

pub fn dnew(self: *Shell, params: *Shell.Params) !Shell.Result {
    var parent: bool = false;

    {
        const copy = params.*;
        defer params.* = copy;
        while (params.next()) |param| {
            if (param[0] == ':') {
                if (std.mem.eql(u8, param, ":parent")) {
                    parent = true;
                } else return error.InvalidFlag;
            }
        }
    }

    var created = false;
    while (params.next()) |path| {
        if (path[0] == ':')
            continue;

        const root = if (path[0] == '/')
            try files.FolderLink.resolve(.root)
        else
            try self.root.resolve();

        try root.newFolder(path, parent);

        created = true;
    }

    return if (created) .{
        .data = try allocator.dupe(u8, "Created"),
    } else error.MissingParameter;
}
