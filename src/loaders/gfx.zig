const std = @import("std");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");
const texture_manager = @import("../util/texmanager.zig");

const Self = @This();

pub fn load(_: *const Self) anyerror!void {
    // texture manager
    texture_manager.TextureManager.instance = .{};

    try gfx.Context.init("SandEEE");
}

pub fn unload(_: *const Self) void {
    gfx.Context.deinit();
}
