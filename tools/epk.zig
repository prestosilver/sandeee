const std = @import("std");

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

var data: [100_000_000]u8 = undefined;

// converts a eep to a epk
pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const output_file_path = args.next() orelse return error.MissingOutputFile;

    var output_file = try std.fs.createFileAbsolute(output_file_path, .{});

    try output_file.writeAll("epak");

    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--file")) {
            const dest_path = args.next() orelse return error.MissingDestPath;
            const source_file = args.next() orelse return error.MissingSourceFile;
            const name_len: u16 = @intCast(dest_path.len);

            try output_file.writeAll(&.{std.mem.asBytes(&name_len)[1]});
            try output_file.writeAll(&.{std.mem.asBytes(&name_len)[0]});
            try output_file.writeAll(dest_path);

            const input_file = try std.fs.cwd().openFile(source_file, .{});
            defer input_file.close();

            const data_len: u16 = @intCast(try input_file.readAll(&data));

            try output_file.writeAll(&.{std.mem.asBytes(&data_len)[1]});
            try output_file.writeAll(&.{std.mem.asBytes(&data_len)[0]});
            try output_file.writeAll(data[0..data_len]);
        } else return error.UnknownArg;
    }
}
