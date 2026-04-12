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
pub const NAME = "help";
pub const DESCRIPTION = "Prints a help message";
pub const HELP = "help [:help]";

pub fn help(shell: *Shell, _: *Shell.Params) !Shell.Result {
    var data: std.array_list.Managed(u8) = .init(allocator);
    defer data.deinit();

    try data.appendSlice("Sh" ++ strings.EEE ++ "ll Help:\n" ++ "=============\n");
    if (shell.headless or builtin.is_test) {
        inline for (Shell.headless_help_data) |help_group| {
            try data.append('\n');
            try data.appendSlice(help_group.name ++ "\n");
            try data.appendNTimes('-', help_group.name.len);
            try data.append('\n');
            inline for (help_group.cmds) |command| {
                try data.appendSlice(std.fmt.comptimePrint("{s} - {s}\n", .{ command.@"1".name, command.@"1".desc }));
            }
        }
    } else {
        inline for (Shell.help_data) |help_group| {
            try data.append('\n');
            try data.appendSlice(help_group.name ++ "\n");
            try data.appendNTimes('-', help_group.name.len);
            try data.append('\n');
            inline for (help_group.cmds) |command| {
                try data.appendSlice(std.fmt.comptimePrint("{s} - {s}\n", .{ command.@"1".name, command.@"1".desc }));
            }
        }
    }

    return .{
        .data = try data.toOwnedSlice(),
    };
}
