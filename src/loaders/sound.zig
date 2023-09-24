const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const audio = @import("../util/audio.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

pub fn loadSound(self: *worker.WorkerQueueEntry(*const []const u8, *audio.Sound)) !bool {
    log.debug("load sound: {s}", .{self.indata.*});
    self.out.* = audio.Sound.init(try (try files.root.getFile(self.indata.*)).read(null));

    return true;
}
