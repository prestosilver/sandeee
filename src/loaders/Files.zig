const std = @import("std");

const util = @import("../util.zig");
const system = @import("../system.zig");

const allocator = util.allocator;

const files = system.files;
const log = util.log;

pub const Self = @This();

disk: []const u8,

pub fn load(self: *const Self) anyerror!void {
    log.debug("load files: {s}", .{self.disk});

    try files.Folder.init(self.disk);
}

pub fn unload(self: *const Self) void {
    // save the disk
    files.write();
    files.deinit();
    allocator.free(self.disk);
}
