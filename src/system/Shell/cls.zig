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
pub const NAME = "cls";
pub const DESCRIPTION = "Clears the console";
pub const HELP = "cls [:help]";

pub fn cls(shell: *Shell, params: *Shell.Params) !Shell.Result {
    _ = shell;
    _ = params;

    const result: Shell.Result = .{
        .data = &.{},
        .clear = true,
    };
    return result;
}
