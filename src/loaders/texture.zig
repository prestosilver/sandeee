const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const tex = @import("../texture.zig");


pub fn loadTexture(self: *worker.WorkerQueueEntry(*const []const u8, *tex.Texture)) bool {
    std.log.debug("load tex: {s}", .{self.indata.*});

    self.out.* = tex.newTextureFile(self.indata.*) catch {
        return false;
    };

    return true;
}
