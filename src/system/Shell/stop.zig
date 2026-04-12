const std = @import("std");

const system = @import("../../system.zig");
const util = @import("../../util.zig");

const Vm = system.Vm;

const Shell = system.Shell;
const files = system.files;

const allocator = util.allocator;

pub const NAME = "stop";
pub const DESCRIPTION = "Stops a background vm process";
pub const HELP = "stop [:help] id";

pub fn stop(_: *Shell, params: *Shell.Params) !Shell.Result {
    if (params.next()) |id_string| {
        const id = try std.fmt.parseInt(u8, id_string, 16);
        Vm.Manager.instance.destroy(@enumFromInt(id));

        return .{
            .data = try allocator.dupe(u8, "Stopped"),
        };
    }

    return error.MissingParameter;
}
