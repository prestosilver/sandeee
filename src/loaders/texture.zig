const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const tex = @import("../util/texture.zig");
const texture_manager = @import("../util/texmanager.zig");
const gfx = @import("../util/graphics.zig");
const conf = @import("../system/config.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

pub fn loadTexture(self: *worker.WorkerQueueEntry(*const []const u8, *const []const u8)) !bool {
    const path = conf.SettingManager.instance.get(self.indata.*) orelse
        self.indata.*;

    log.debug("load tex: {s}", .{path});

    if (tex.newTextureFile(path)) |texture| {
        try texture_manager.TextureManager.instance.put(self.out.*, texture);
    } else |err| {
        log.err("Could not load image {s}, {s}", .{ path, @errorName(err) });
    }

    return true;
}
