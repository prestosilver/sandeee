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

const Eln = util.Eln;
const allocator = util.allocator;

pub const GUI = false;
pub const NAME = "eln";
pub const DESCRIPTION = "Opens an eln file";
pub const HELP = "eln [:help] file";

pub fn eln(shell: *Shell, params: *Shell.Params) !Shell.Result {
    if (params.next()) |path| {
        const root = try shell.root.resolve();
        const file = try root.getFile(path);
        const data = try Eln.parse(file);
        try data.run(shell, Shell.shader);
        return .{};
    }

    return error.MissingParameter;
}
