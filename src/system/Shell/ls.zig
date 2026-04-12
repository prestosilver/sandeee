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
pub const NAME = "ls";
pub const DESCRIPTION = "Lists files and folders in a directory";
pub const HELP = "ls [:help] [path]";

pub fn ls(shell: *Shell, params: *Shell.Params) !Shell.Result {
    var result_data: std.array_list.Managed(u8) = .init(allocator);
    defer result_data.deinit();

    const root = try shell.root.resolve();
    if (params.next()) |path| {
        const folder = try root.getFolder(path);
        const rootlen = folder.name.len;
        var sub_folder = try folder.getFolders();
        while (sub_folder) |item| : (sub_folder = item.next_sibling) {
            try result_data.appendSlice(item.name[rootlen..]);
            try result_data.append(' ');
        }
        var sub_file = try folder.getFiles();
        while (sub_file) |item| : (sub_file = item.next_sibling) {
            try result_data.appendSlice(item.name[rootlen..]);
            try result_data.append(' ');
        }
    } else {
        const folder = try shell.root.resolve();
        const rootlen = folder.name.len;
        var sub_folder = try folder.getFolders();
        while (sub_folder) |item| : (sub_folder = item.next_sibling) {
            try result_data.appendSlice(item.name[rootlen..]);
            try result_data.append(' ');
        }
        var sub_file = try folder.getFiles();
        while (sub_file) |item| : (sub_file = item.next_sibling) {
            try result_data.appendSlice(item.name[rootlen..]);
            try result_data.append(' ');
        }
    }

    return .{
        .data = try result_data.toOwnedSlice(),
    };
}
