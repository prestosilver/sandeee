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
    defer gfx.gContext.makeNotCurrent();

    self.out.* = try font.Font.init(self.indata.*);

    return true;
}

pub fn loadFont(self: *worker.WorkerQueueEntry(*const []const u8, *font.Font)) !bool {
    std.log.debug("load font in mem", .{});

    gfx.gContext.makeCurrent();
    defer gfx.gContext.makeNotCurrent();

    self.out.* = try font.Font.initMem(self.indata.*);

    return true;
}
