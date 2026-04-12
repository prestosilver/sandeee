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
pub const NAME = "new";
pub const DESCRIPTION = "Creates a new file";
pub const HELP = "new [:help] path";

pub fn new(self: *Shell, param: *Shell.Params) !Shell.Result {
    if (param.next()) |path| {
        // TODO: /root
        const root = try self.root.resolve();
        try root.newFile(path);
        return .{
            .data = try allocator.dupe(u8, "Created"),
        };
    }

    return error.MissingParameter;
}
