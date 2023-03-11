const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const gfx = @import("../graphics.zig");

var lol: bool = true;

pub fn loadFont(self: *worker.WorkerQueueEntry(*[]u8, *font.Font)) bool {
    gfx.gContext.makeCurrent();

    std.log.debug("load font: {s}", .{self.indata.*});
    var size: u32 = 22;
    if (lol) size = 32;
    lol = false;

    self.out.* = font.Font.init(self.indata.*, size) catch {
        return false;
    };

    gfx.gContext.makeNotCurrent();

    return true;
}
