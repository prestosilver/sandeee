const std = @import("std");
const c = @import("../c.zig");

const loaders = @import("mod.zig");

const util = @import("../util/mod.zig");
const system = @import("../system/mod.zig");

const TextureManager = util.TextureManager;
const graphics = util.graphics;

const Self = @This();

pub fn load(_: *const Self) anyerror!void {
    // texture manager
    TextureManager.instance = .{};

    try graphics.Context.init("SandEEE");
}

pub fn unload(_: *const Self) void {
    graphics.Context.deinit();
}
