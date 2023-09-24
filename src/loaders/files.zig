const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");

const log = @import("../util/log.zig").log;

pub fn loadFiles(self: *worker.WorkerQueueEntry(*?[]u8, *const u8)) !bool {
    log.debug("load files: {?s}", .{self.indata.*});

    try files.Folder.init(self.indata.*);

    return true;
}
