const std = @import("std");

const system = @import("../system.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const mail = system.mail;

const log = util.log;

const strings = data.strings;

const Self = @This();

folder: []const u8,

pub fn load(self: *const Self) anyerror!void {
    log.debug("load mail", .{});

    try mail.EmailManager.init();

    try mail.EmailManager.instance.loadFromFolder(self.folder);

    mail.EmailManager.instance.loadStateFile(strings.EMAIL_DATA_PATH) catch {};
}

pub fn unload(_: *const Self) void {
    // save email data
    mail.EmailManager.instance.saveStateFile(strings.EMAIL_DATA_PATH) catch |err|
        log.err("email save failed {}", .{err});
    mail.EmailManager.instance.deinit();
}
