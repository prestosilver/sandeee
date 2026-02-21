const std = @import("std");

const system = @import("../../system.zig");
const util = @import("../../util.zig");
const windows = @import("../../windows.zig");
const drawers = @import("../../drawers.zig");
const events = @import("../../events.zig");
const math = @import("../../math.zig");

const Window = drawers.Window;

const Rect = math.Rect;

const Shell = system.Shell;
const files = system.files;

const window_events = events.windows;

const allocator = util.allocator;

pub const GUI = true;
pub const NAME = "edit";
pub const DESCRIPTION = "Opens the text editor";
pub const HELP = "edit [:help] [file]";

pub fn edit(self: *Shell, params: *Shell.Params) !Shell.Result {
    const window: Window = .atlas("win", .{
        .source = Rect{ .w = 1, .h = 1 },
        .contents = try windows.editor.init(Shell.shader),
        .active = true,
    });

    if (params.next()) |file_name| {
        const ed_self: *windows.editor.EditorData = @ptrCast(@alignCast(window.data.contents.ptr));
        const root_link: files.FolderLink = if (std.mem.startsWith(u8, file_name, "/"))
            .root
        else
            self.root;

        const root = try root_link.resolve();
        ed_self.file = try root.getFile(file_name);

        if (ed_self.file) |file| {
            const file_conts = try file.read(null);
            const lines = std.mem.count(u8, file_conts, "\n") + 1;

            if (ed_self.buffer == null)
                ed_self.buffer = try .initCapacity(allocator, lines);
            try ed_self.buffer.?.resize(lines);

            var iter = std.mem.splitScalar(u8, file_conts, '\n');
            var idx: usize = 0;
            while (iter.next()) |line| : (idx += 1) {
                ed_self.buffer.?.items[idx] = .{
                    .text = try allocator.dupe(u8, line),
                    .render = null,
                };
            }
        } else return .{};
    }

    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });

    return .{};
}
