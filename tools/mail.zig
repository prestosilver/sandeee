const std = @import("std");
const mail = @import("../src/system/mail.zig");

pub fn emails(path: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var root = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });
    var dir = try std.fs.cwd().openIterableDir(path, .{ .access_sub_paths = true });
    var walker = try dir.walk(alloc);
    var entry = try walker.next();

    mail.emails = std.ArrayList(mail.Email).init(alloc);

    var count: usize = 0;

    while (entry) |file| : (entry = walker.next() catch null) {
        switch (file.kind) {
            .File => {
                var f = try root.openFile(file.path, .{});
                defer f.close();
                try mail.append(try mail.parseTxt(f));
                count += 1;
            },
            else => {},
        }
    }

    std.log.info("packed {} emails", .{count});

    var result = std.ArrayList(u8).init(alloc);
    try result.appendSlice(try mail.toStr());

    return result;
}
