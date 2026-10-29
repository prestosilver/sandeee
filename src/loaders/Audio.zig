const std = @import("std");

const loaders = @import("../loaders.zig");

const util = @import("../util.zig");
const system = @import("../system.zig");

const audio = util.audio;
const log = util.log;

const Self = @This();

pub fn load(_: *const Self) !void {
    try audio.Context.init();

    log.debug("Init audio context", .{});
}

pub fn unload(_: *const Self) void {
    audio.Context.deinit();

    log.debug("Deinit audio context", .{});
}
