const std = @import("std");
const worker = @import("worker.zig");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const conf = @import("../system/config.zig");
const files = @import("../system/files.zig");
const allocator = @import("../util/allocator.zig");

pub fn loadSettings(self: *worker.WorkerQueueEntry(*const []const u8, *conf.SettingManager)) !bool {
    std.log.debug("load settings", .{});

    self.out.init();

    var ofile = try files.root.getFile(self.indata.*);

    if (ofile) |file| {
        var cont = try file.read(null);
        var iter = std.mem.split(u8, cont, "\n");

        while (iter.next()) |line| {
            var comment = std.mem.split(u8, line, "#");
            var aline = comment.first();

            var eqls = std.mem.split(u8, aline, "=");
            var key = eqls.first();
            var value = eqls.rest();
            var tkey = std.mem.trim(u8, key, " ");
            var tvalue = std.mem.trim(u8, value, " ");

            if (tvalue.len > 1 and tvalue[0] == '"' and tvalue[tvalue.len - 1] == '"') {
                try self.out.set(try allocator.alloc.dupe(u8, tkey), tvalue[1 .. tvalue.len - 1]);
            }
        }
    } else {
        return false;
    }

    return true;
}
