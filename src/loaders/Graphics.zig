const std = @import("std");
const c = @import("../c.zig");

const loaders = @import("../loaders.zig");

const util = @import("../util.zig");
const system = @import("../system.zig");

const TextureManager = util.TextureManager;
const graphics = util.graphics;
const log = util.log;

const Self = @This();

real_fullscreen: bool,

pub fn load(self: *const Self) anyerror!void {
    // init texture manager
    TextureManager.instance = .{};

    try graphics.Context.init("SandEEE", self.real_fullscreen);
}

pub fn unload(_: *const Self) void {
    graphics.Context.deinit();
}
