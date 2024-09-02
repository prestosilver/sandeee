const std = @import("std");
const mail = @import("../src/system/mail.zig");

var mail_lock = std.Thread.Mutex{};

pub fn emails(b: *std.Build, paths: []const std.Build.LazyPath) anyerror!std.ArrayList(u8) {
    if (paths.len != 1) return error.BadPaths;

    mail_lock.lock();
    defer mail_lock.unlock();

    try mail.EmailManager.init();
    defer mail.EmailManager.instance.deinit();

    var root = try std.fs.cwd().openDir(paths[0].getPath3(b, null).sub_path, .{ .access_sub_paths = true, .iterate = true });
    var walker = try root.walk(b.allocator);

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

    var result = std.ArrayList(u8).init(b.allocator);
    const appends = try mail.EmailManager.instance.exportData();

    try result.appendSlice(appends);

    return result;
}
