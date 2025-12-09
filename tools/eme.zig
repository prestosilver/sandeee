const std = @import("std");
const mail = @import("../src/system/mail.zig");

var mail_lock = std.Thread.Mutex{};

pub fn emails(
    b: *std.Build,
    paths: []const std.Build.LazyPath,
    output: std.Build.LazyPath,
) anyerror!void {
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

    const path = output.getPath(b);
    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    const appends = try mail.EmailManager.instance.exportData();

    _ = try file.writer().write(appends);
}
