const std = @import("std");

const util = @import("../util.zig");
const system = @import("../system.zig");

const allocator = util.allocator;

const files = system.files;
const log = util.log;

pub const Self = @This();

disk: []const u8,

pub fn load(self: *const Self) anyerror!void {
    try files.Folder.init(self.disk);

    log.debug("Loaded disk file {s}", .{self.disk});
}

pub fn unload(self: *const Self) void {
    // save the disk
    files.write();
    files.deinit();

    log.debug("Unloaded disk file {s}", .{self.disk});

    allocator.free(self.disk);
}
