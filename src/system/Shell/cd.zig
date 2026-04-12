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
pub const NAME = "cd";
pub const DESCRIPTION = "Changes the current directory";
pub const HELP = "cd [:help] [path]";

pub fn cd(shell: *Shell, params: *Shell.Params) !Shell.Result {
    shell.root = if (params.next()) |child|
        if (std.mem.eql(u8, child, "/"))
            .root
        else blk: {
            const root_link: files.FolderLink = if (std.mem.startsWith(u8, child, "/"))
                .root
            else
                shell.root;
            const root = try root_link.resolve();
            const folder = try root.getFolder(child);

            break :blk .link(folder);
        }
    else
        .home;

    return .{};
}
