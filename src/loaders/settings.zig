const std = @import("std");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const conf = @import("../system/config.zig");
const files = @import("../system/files.zig");
const allocator = @import("../util/allocator.zig");
const opener = @import("../system/opener.zig");

const log = @import("../util/log.zig").log;

const Self = @This();

path: []const u8,

pub fn load(self: *const Self) anyerror!void {
    log.debug("load settings", .{});

    conf.SettingManager.instance = .{};

    const root = try files.FolderLink.resolve(.root);

    const file = try root.getFile(self.path);
    const cont = try file.read(null);

    var iter = std.mem.splitScalar(u8, cont, '\n');

    while (iter.next()) |line| {
        var comment = std.mem.splitScalar(u8, line, '#');
        const aline = comment.first();

        var eqls = std.mem.splitScalar(u8, aline, '=');
        const key = eqls.first();
        const value = eqls.rest();
        const tkey = std.mem.trim(u8, key, " ");
        const tvalue = std.mem.trim(u8, value, " ");

        if (tvalue.len > 1 and tvalue[0] == '"' and tvalue[tvalue.len - 1] == '"') {
            try conf.SettingManager.instance.set(tkey, tvalue[1 .. tvalue.len - 1]);
        }
    }

    try opener.instance.setup();
    try files.Folder.setupExtr();
}

pub fn unload(_: *const Self) void {
    conf.SettingManager.deinit();
    opener.instance.deinit();
}
