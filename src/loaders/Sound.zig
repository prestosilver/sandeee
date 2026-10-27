const std = @import("std");

const util = @import("../util.zig");
const system = @import("../system.zig");

const allocator = util.allocator;
const audio = util.audio;
const log = util.log;

const config = system.config;
const files = system.files;

data: union(enum) {
    path: []const u8,
    mem: []const u8,
},
output: *audio.Sound,

const Self = @This();

pub fn load(self: *const Self) !void {
    switch (self.data) {
        .path => |config_path| {
            const path = config.SettingManager.instance.get(config_path) orelse config_path;

            const root = try files.FolderLink.resolve(.root);
            self.output.* = try audio.Sound.init(audio.instance, try (try root.getFile(path)).read(null));

            log.debug("Loaded sound {s}", .{path});
        },
        .mem => |data| {
            self.output.* = try audio.Sound.init(audio.instance, data);

            log.debug("Loaded sound {} bytes", .{data.len});
        },
    }
}

pub fn unload(self: *const Self) void {
    self.output.deinit();

    switch (self.data) {
        .path => |config_path| {
            const path = config.SettingManager.instance.get(config_path) orelse config_path;
            log.debug("Unloaded sound {s}", .{path});
        },

        .mem => |data| {
            log.debug("Unloaded sound {} bytes", .{data.len});
        },
    }
}
