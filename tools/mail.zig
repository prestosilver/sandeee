const std = @import("std");
const mail = @import("../src/system/mail.zig");

var mail_lock = std.Thread.Mutex{};

pub fn emails(paths: []const []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    if (paths.len != 1) return error.BadPaths;

    mail_lock.lock();
    defer mail_lock.unlock();

    try mail.EmailManager.init();
    defer mail.EmailManager.instance.deinit();

    var root = try std.fs.cwd().openDir(paths[0], .{ .access_sub_paths = true, .iterate = true });
    var walker = try root.walk(alloc);

    var count: usize = 0;

    while (try walker.next()) |file| {
        switch (file.kind) {
            .file => {
                var f = try root.openFile(file.path, .{});
                defer f.close();
                try mail.EmailManager.instance.append(try mail.EmailManager.Email.parseTxt(f));
                count += 1;
            },
            else => {},
        }
    }

    // std.log.info("packed {} emails", .{count});

    var result = std.ArrayList(u8).init(alloc);
    const appends = try mail.EmailManager.instance.exportData();

    try result.appendSlice(appends);

    return result;
}
