const std = @import("std");
const builtin = @import("builtin");

const system = @import("../../system.zig");
const util = @import("../../util.zig");
const windows = @import("../../windows.zig");
const drawers = @import("../../drawers.zig");
const events = @import("../../events.zig");
const math = @import("../../math.zig");
const sandeee_data = @import("../../data.zig");

const Window = drawers.Window;

const Rect = math.Rect;

const Shell = system.Shell;
const files = system.files;

const window_events = events.windows;

const strings = sandeee_data.strings;

const allocator = util.allocator;

pub const GUI = false;
pub const NAME = "bg";
pub const DESCRIPTION = "Runs a command in the background";
pub const HELP = "bg [:help] command";

pub fn bg(shell: *Shell, params: *Shell.Params) !Shell.Result {
    if (params.peek()) |_| {
        try shell.runBg(params.rest());
        const result: Shell.Result = .{
            .data = try allocator.dupe(u8, "Running"),
        };
        return result;
    }
    const result: Shell.Result = .{
        .data = try allocator.dupe(u8, "No Command Specified"),
    };
    return result;
}
