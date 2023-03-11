const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");
const gfx = @import("../graphics.zig");


pub fn loadDelay(self: *worker.WorkerQueueEntry(*const u64, *const u8)) bool {
    std.time.sleep(self.indata.* * 1000 * 1000);

    return true;
}
