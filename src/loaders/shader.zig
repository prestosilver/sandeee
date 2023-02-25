const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const gfx = @import("../graphics.zig");


pub fn loadShader(self: *worker.WorkerQueueEntry(*const [2]shd.ShaderFile, *shd.Shader)) bool {
    std.log.debug("load shader", .{});

    self.out.* = shd.Shader.new(2, self.indata.*);
    gfx.regShader(gfx.gContext, self.out.*) catch {
        return false;
    };

    return true;
}
