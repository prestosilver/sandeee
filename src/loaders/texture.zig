const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const tex = @import("../texture.zig");
const gfx = @import("../util/graphics.zig");
const c = @import("../c.zig");

pub fn loadTexture(self: *worker.WorkerQueueEntry(*const []const u8, *tex.Texture)) !bool {
    gfx.gContext.makeCurrent();

    std.log.debug("load tex: {s}", .{self.indata.*});
    self.out.* = try tex.newTextureFile(self.indata.*);
    gfx.gContext.makeNotCurrent();

    return true;
}
