const std = @import("std");
const worker = @import("worker.zig");
const font = @import("../util/font.zig");
const mail = @import("../system/mail.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

pub fn loadMail(self: *worker.WorkerQueueEntry(*const []const u8, *const u8)) !bool {
    log.debug("load mail", .{});

    try mail.EmailManager.init();

    try mail.EmailManager.instance.loadFromFolder(self.indata.*);

    mail.EmailManager.instance.loadStateFile("/_priv/emails.bin") catch {};

    return true;
}
