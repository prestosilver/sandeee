const std = @import("std");
const c = @import("../c.zig");

const gfx = @import("../util/graphics.zig");

const TextureManager = @import("../util/texmanager.zig");

const Self = @This();

pub fn load(_: *const Self) anyerror!void {
    // texture manager
    TextureManager.instance = .{};

    try gfx.Context.init("SandEEE");
}

pub fn unload(_: *const Self) void {
    gfx.Context.deinit();
}
