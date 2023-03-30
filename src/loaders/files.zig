const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");

pub fn loadFiles(self: *worker.WorkerQueueEntry(*?[]u8, *const u8)) !bool {
    std.log.debug("load files: {?s}", .{self.indata.*});

    try files.Folder.init(self.indata.*);

    return true;
}
