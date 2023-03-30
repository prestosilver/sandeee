const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const gfx = @import("../util/graphics.zig");
const c = @import("../c.zig");

pub fn loadShader(self: *worker.WorkerQueueEntry(*const [2]shd.ShaderFile, *shd.Shader)) !bool {
    gfx.gContext.makeCurrent();

    std.log.debug("load shader", .{});
    self.out.* = try shd.Shader.new(2, self.indata.*);
    try gfx.regShader(gfx.gContext, self.out.*);

    gfx.gContext.makeNotCurrent();

    return true;
}
