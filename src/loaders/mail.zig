const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const mail = @import("../system/mail.zig");
const c = @import("../c.zig");
const gfx = @import("../graphics.zig");

pub fn loadMail(_: *worker.WorkerQueueEntry(*const u8, *const u8)) !bool {
    std.log.debug("load mail", .{});

    mail.init();

    try mail.load();

    return true;
}
