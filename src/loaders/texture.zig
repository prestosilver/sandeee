const std = @import("std");
const c = @import("../c.zig");

const shd = @import("../util/shader.zig");
const tex = @import("../util/texture.zig");
const gfx = @import("../util/graphics.zig");
const conf = @import("../system/config.zig");
const log = @import("../util/log.zig").log;

const TextureManager = @import("../util/texmanager.zig");

const Self = @This();

name: []const u8,
path: []const u8,

pub fn load(self: *const Self) anyerror!void {
    const path = conf.SettingManager.instance.get(self.path) orelse
        self.path;

    var loaded_tex = tex.Texture.init();

    log.debug("load tex: {s}", .{path});
    if (loaded_tex.loadFile(path)) {
        log.debug("upload tex: {s}", .{path});
        try loaded_tex.upload();
        try TextureManager.instance.put(self.name, loaded_tex);
    } else |err| {
        log.err("Could not load image {s}, {s}", .{ path, @errorName(err) });
    }
}

pub fn unload(self: *const Self) void {
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    TextureManager.instance.remove(self.name);
}
