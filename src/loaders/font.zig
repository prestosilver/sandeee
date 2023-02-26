const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const gfx = @import("../graphics.zig");


pub fn loadFont(self: *worker.WorkerQueueEntry(*[]u8, *font.Font)) bool {
    gfx.gContext.makeCurrent();

    std.log.debug("load font", .{});
    self.out.* = font.Font.init(self.indata.*, 22) catch {
        return false;
    };

    gfx.gContext.makeNotCurrent();

    return true;
}
