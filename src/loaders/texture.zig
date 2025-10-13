const std = @import("std");
const c = @import("../c.zig");

const loaders = @import("mod.zig");

const util = @import("../util/mod.zig");
const system = @import("../system/mod.zig");

const config = system.config;

const Texture = util.Texture;
const Shader = util.Shader;

const TextureManager = util.TextureManager;
const graphics = util.graphics;
const log = util.log;

const Self = @This();

name: []const u8,
path: []const u8,

pub fn load(self: *const Self) anyerror!void {
    const path = config.SettingManager.instance.get(self.path) orelse
        self.path;

    var loaded_tex = Texture.init();

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
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    TextureManager.instance.remove(self.name);
}
