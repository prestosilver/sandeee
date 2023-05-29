const std = @import("std");
const worker = @import("worker.zig");
const font = @import("../util/font.zig");
const mail = @import("../system/mail.zig");
const c = @import("../c.zig");

pub fn loadMail(self: *worker.WorkerQueueEntry(*const []const u8, *mail.EmailManager)) !bool {
    std.log.debug("load mail", .{});

    self.out.* = mail.EmailManager.init();

    try self.out.loadFromFolder(self.indata.*);

    try self.out.loadStateFile("/conf/emails.bin");

    return true;
}
