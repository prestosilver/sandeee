const std = @import("std");
const worker = @import("worker.zig");
const font = @import("../util/font.zig");
const mail = @import("../system/mail.zig");
const c = @import("../c.zig");

pub fn loadMail(self: *worker.WorkerQueueEntry(*const []const u8, *mail.EmailManager)) !bool {
    std.log.debug("load mail", .{});

    self.out.* = try mail.EmailManager.init();

    try self.out.loadFromFolder(self.indata.*);

    self.out.loadStateFile("/_priv/emails.bin") catch {};

    return true;
}
