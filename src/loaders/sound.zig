const std = @import("std");
const shd = @import("../util/shader.zig");
const audio = @import("../util/audio.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");
const allocator = @import("../util/allocator.zig");
const conf = @import("../system/config.zig");

const log = @import("../util/log.zig").log;

path: []const u8,
output: *audio.Sound,

const Self = @This();

pub fn load(self: *const Self) anyerror!void {
    const path = conf.SettingManager.instance.get(self.path) orelse self.path;

    log.debug("load sound: {s}", .{path});

    const root = try files.FolderLink.resolve(.root);
    self.output.* = audio.Sound.init(try (try root.getFile(path)).read(null));

    return;
}
