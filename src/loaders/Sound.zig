const std = @import("std");

const util = @import("../util.zig");
const system = @import("../system.zig");

const allocator = util.allocator;
const audio = util.audio;
const log = util.log;

const config = system.config;
const files = system.files;

path: []const u8,
output: *audio.Sound,

const Self = @This();

pub fn load(self: *const Self) anyerror!void {
    const path = config.SettingManager.instance.get(self.path) orelse self.path;

    const root = try files.FolderLink.resolve(.root);
    self.output.* = audio.Sound.init(try (try root.getFile(path)).read(null));

    log.debug("Loaded sound {s}", .{self.path});
}

pub fn unload(self: *const Self) void {
    self.output.deinit();

    log.debug("Unloaded sound {s}", .{self.path});
}
