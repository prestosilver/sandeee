const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const tex = @import("../util/texture.zig");
const texMan = @import("../util/texmanager.zig");
const gfx = @import("../util/graphics.zig");
const conf = @import("../system/config.zig");
const c = @import("../c.zig");

const log = @import("../util/log.zig").log;

pub fn loadTexture(self: *worker.WorkerQueueEntry(*const []const u8, *const []const u8)) !bool {
    const path = conf.SettingManager.instance.get(self.indata.*) orelse
        self.indata.*;

    var texture = try tex.newTextureSize(.{ .x = 0, .y = 0 });

    log.debug("load tex: {s}", .{path});

    try tex.uploadTextureFile(&texture, path);

    try texMan.TextureManager.instance.put(self.out.*, texture);

    return true;
}
