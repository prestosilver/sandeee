const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");
const allocator = @import("../util/allocator.zig");

pub fn loadFontPath(self: *worker.WorkerQueueEntry(*const []const u8, *font.Font)) !bool {
    std.log.debug("load font: {s}", .{self.indata.*});

    gfx.gContext.makeCurrent();

    self.out.* = try font.Font.init(self.indata.*);

    gfx.gContext.makeNotCurrent();

    return true;
}

pub fn loadFont(self: *worker.WorkerQueueEntry(*const []const u8, *font.Font)) !bool {
    gfx.gContext.makeCurrent();

    std.log.debug("load font in mem", .{});

    self.out.* = try font.Font.initMem(self.indata.*);

    gfx.gContext.makeNotCurrent();

    return true;
}
