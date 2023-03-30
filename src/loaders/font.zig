const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");
const allocator = @import("../util/allocator.zig");

var lol: bool = true;

pub fn loadFont(self: *worker.WorkerQueueEntry(*[]u8, *font.Font)) !bool {
    gfx.gContext.makeCurrent();

    std.log.debug("load font: {s}", .{self.indata.*});
    var size: u32 = 22;
    if (lol) size = 32;
    lol = false;

    var path = try allocator.alloc.alloc(u8, self.indata.*.len + 1);
    std.mem.copy(u8, path, self.indata.*);
    path[path.len - 1] = 0;

    self.out.* = try font.Font.init(@ptrCast([*c]const u8, path), size);

    allocator.alloc.free(path);

    gfx.gContext.makeNotCurrent();

    return true;
}
