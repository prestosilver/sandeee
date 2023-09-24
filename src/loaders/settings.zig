const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const conf = @import("../system/config.zig");
const files = @import("../system/files.zig");
const allocator = @import("../util/allocator.zig");

const log = @import("../util/log.zig").log;

pub fn loadSettings(self: *worker.WorkerQueueEntry(*const []const u8, *const u8)) !bool {
    log.debug("load settings", .{});

    conf.SettingManager.init();

    const file = try files.root.getFile(self.indata.*);

    const cont = try file.read(null);
    var iter = std.mem.split(u8, cont, "\n");

    while (iter.next()) |line| {
        var comment = std.mem.split(u8, line, "#");
        const aline = comment.first();

        var eqls = std.mem.split(u8, aline, "=");
        const key = eqls.first();
        const value = eqls.rest();
        const tkey = std.mem.trim(u8, key, " ");
        const tvalue = std.mem.trim(u8, value, " ");

        if (tvalue.len > 1 and tvalue[0] == '"' and tvalue[tvalue.len - 1] == '"') {
            try conf.SettingManager.instance.set(tkey, tvalue[1 .. tvalue.len - 1]);
        }
    }

    try files.Folder.setupExtr();

    return true;
}
