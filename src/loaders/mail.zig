const std = @import("std");
const font = @import("../util/font.zig");
const mail = @import("../system/mail.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

const Self = @This();

folder: []const u8,

pub fn load(self: *Self) anyerror!void {
    log.debug("load mail", .{});

    try mail.EmailManager.init();

    try mail.EmailManager.instance.loadFromFolder(self.folder);

    mail.EmailManager.instance.loadStateFile("/_priv/emails.bin") catch {};

    return true;
}
