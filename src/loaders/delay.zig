const std = @import("std");
const worker = @import("worker.zig");
const c = @import("../c.zig");

pub fn loadDelay(self: *worker.WorkerQueueEntry(*const u64, *const u8)) !bool {
    std.time.sleep(self.indata.* * 1000 * 1000);

    return true;
}
