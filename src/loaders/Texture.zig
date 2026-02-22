const std = @import("std");
const c = @import("../c.zig");

const loaders = @import("../loaders.zig");

const util = @import("../util.zig");
const system = @import("../system.zig");

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

    if (loaded_tex.loadFile(path)) {
        try loaded_tex.upload();
        try TextureManager.instance.put(self.name, loaded_tex);
        log.debug("Loaded texture {s}", .{self.path});
    } else |err| {
        log.err("Could not load texture {s}, {s}", .{ self.path, @errorName(err) });
    }
}

pub fn unload(self: *const Self) void {
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    TextureManager.instance.remove(self.name);

    log.debug("Unloaded texture {s}", .{self.path});
}
