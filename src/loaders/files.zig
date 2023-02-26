const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");
const gfx = @import("../graphics.zig");


pub fn loadFiles(_: *worker.WorkerQueueEntry(void, void)) bool {
    std.log.debug("load files", .{});

    files.Folder.init() catch {
        return false;
    };

    return true;
}
