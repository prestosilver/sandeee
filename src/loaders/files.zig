const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");
const gfx = @import("../graphics.zig");


pub fn loadFiles(self: *worker.WorkerQueueEntry(*const ?[]const u8, *const u8)) bool {
    std.log.debug("load files: {?s}", .{self.indata.*});

    files.Folder.init(self.indata.*) catch |msg| {
        std.log.err("{}", .{msg});
        return false;
    };

    return true;
}
