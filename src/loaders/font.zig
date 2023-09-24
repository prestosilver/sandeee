const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");
const allocator = @import("../util/allocator.zig");
const conf = @import("../system/config.zig");

const log = @import("../util/log.zig").log;

pub fn loadFontPath(self: *worker.WorkerQueueEntry(*const []const u8, *font.Font)) !bool {
    const path = conf.SettingManager.instance.get(self.indata.*) orelse
        self.indata.*;

    log.debug("load font: {s}", .{path});

    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    self.out.* = try font.Font.init(path);

    return true;
}

pub fn loadFont(self: *worker.WorkerQueueEntry(*const []const u8, *font.Font)) !bool {
    log.debug("load font in mem", .{});

    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    self.out.* = try font.Font.initMem(self.indata.*);

    return true;
}
