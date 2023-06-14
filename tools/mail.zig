const std = @import("std");
const mail = @import("../src/system/mail.zig");

pub fn emails(path: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var manager = try mail.EmailManager.init();

    var root = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });
    var dir = try std.fs.cwd().openIterableDir(path, .{ .access_sub_paths = true });
    var walker = try dir.walk(alloc);
    var entry = try walker.next();

    var count: usize = 0;

    while (entry) |file| : (entry = walker.next() catch null) {
        switch (file.kind) {
            .file => {
                var f = try root.openFile(file.path, .{});
                defer f.close();
                try manager.append(try mail.EmailManager.Email.parseTxt(f));
                count += 1;
            },
            else => {},
        }
    }

    // std.log.info("packed {} emails", .{count});

    var result = std.ArrayList(u8).init(alloc);
    try result.appendSlice(try manager.exportData());

    manager.deinit();

    return result;
}
