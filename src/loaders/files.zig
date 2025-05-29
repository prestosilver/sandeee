const std = @import("std");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");
const allocator = @import("../util/allocator.zig");

const log = @import("../util/log.zig").log;

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
    allocator.alloc.free(self.disk);
}
