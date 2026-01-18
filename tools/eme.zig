const std = @import("std");
const mail = @import("sandeee").system.mail;

var mail_lock = std.Thread.Mutex{};

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const output_file = args.next() orelse return error.MissingOutputFile;

    try mail.EmailManager.init();
    defer mail.EmailManager.instance.deinit();

    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--file")) {
            const file_path = args.next() orelse return error.MissingFile;
            var f = try std.fs.cwd().openFile(file_path, .{});
            defer f.close();
            try mail.EmailManager.instance.append(try mail.EmailManager.Email.parseTxt(f));
        } else {
            std.log.info("{s}", .{kind});
            return error.UnknownArg;
        }
    }

    const appends = try mail.EmailManager.instance.exportData();

    var file = try std.fs.createFileAbsolute(output_file, .{});
    defer file.close();

    var writer = file.writer(&.{});
    try writer.interface.writeAll(appends);
}
