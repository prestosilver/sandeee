const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const tex = @import("../util/texture.zig");
const texMan = @import("../util/texmanager.zig");
const gfx = @import("../util/graphics.zig");
const conf = @import("../system/config.zig");
const c = @import("../c.zig");

pub var settingManager: *conf.SettingManager = undefined;
pub var textureManager: *texMan.TextureManager = undefined;

pub fn loadTexture(self: *worker.WorkerQueueEntry(*const []const u8, *const []const u8)) !bool {
    var path = conf.SettingManager.get(settingManager, self.indata.*) orelse
        self.indata.*;

    var texture = try tex.newTextureSize(.{ .x = 0, .y = 0 });

    std.log.debug("load tex: {s}", .{path});

    try tex.uploadTextureFile(&texture, path);

    try textureManager.put(self.out.*, texture);

    return true;
}
