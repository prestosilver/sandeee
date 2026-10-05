const std = @import("std");
const mail = @import("sandeee").system.mail;
const util = @import("sandeee").util;

var mail_lock = std.Thread.Mutex{};

pub fn main(init: std.process.Init) !void {
    util.io = init.io;

    var args = init.minimal.args.iterate();
    _ = args.next();
    const output_file = args.next() orelse return error.MissingOutputFile;

    try mail.EmailManager.init();
    defer mail.EmailManager.instance.deinit();

    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--file")) {
            const file_path = args.next() orelse return error.MissingFile;
            var f = try std.Io.Dir.cwd().openFile(init.io, file_path, .{});
            defer f.close(init.io);
            try mail.EmailManager.instance.append(try mail.EmailManager.Email.parseTxt(f));
        } else if (std.mem.eql(u8, kind, "--dir")) {
            const mail_path = args.next() orelse return error.MissingDir;

            var root = try std.Io.Dir.cwd().openDir(init.io, mail_path, .{ .iterate = true });
            var walker = try root.walk(b.allocator);

            while (try walker.next(init.io)) |file| {
                switch (file.kind) {
                    .file => {
                        var f = try std.Io.Dir.cwd().openFile(init.io, file_path, .{});
                        defer f.close(init.io);
                        try mail.EmailManager.instance.append(try mail.EmailManager.Email.parseTxt(file.path));
                    },
                    else => {},
                }
            }
        } else {
            std.log.info("{s}", .{kind});
            return error.UnknownArg;
        }
    }

    const appends = try mail.EmailManager.instance.exportData();

    var file = try std.Io.Dir.cwd().createFile(init.io, output_file, .{});
    defer file.close(init.io);

    var writer = file.writer(init.io, &.{});
    try writer.interface.writeAll(appends);
}
