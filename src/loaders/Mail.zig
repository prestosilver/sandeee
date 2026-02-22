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
    try mail.EmailManager.init();

    try mail.EmailManager.instance.loadFromFolder(self.folder);

    mail.EmailManager.instance.loadStateFile(strings.EMAIL_DATA_PATH) catch {};

    log.debug("Loaded emails {s}", .{self.folder});
}

pub fn unload(self: *const Self) void {
    // save email data
    mail.EmailManager.instance.saveStateFile(strings.EMAIL_DATA_PATH) catch |err|
        log.err("Email progress save failed {}", .{err});
    mail.EmailManager.instance.deinit();

    log.debug("Unloaded emails {s}", .{self.folder});
}
