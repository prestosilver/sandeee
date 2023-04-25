const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const tex = @import("../util/texture.zig");
const gfx = @import("../util/graphics.zig");
const conf = @import("../system/config.zig");
const c = @import("../c.zig");

pub var settingManager: *conf.SettingManager = undefined;

pub fn loadTexture(self: *worker.WorkerQueueEntry(*const []const u8, *tex.Texture)) !bool {
    var path = conf.SettingManager.get(settingManager, self.indata.*) orelse
        self.indata.*;

    std.log.debug("load tex: {s}", .{path});

    gfx.gContext.makeCurrent();
    defer gfx.gContext.makeNotCurrent();
    self.out.* = try tex.newTextureFile(path);

    return true;
}
