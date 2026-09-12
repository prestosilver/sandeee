const std = @import("std");

var data: [100_000_000]u8 = undefined;

// converts a eep to a epk
pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();

    const output_file_path = args.next() orelse return error.MissingOutputFile;

    var output_file = try std.Io.Dir.createFileAbsolute(init.io, output_file_path, .{});
    var output_writer = output_file.writer(init.io, &.{});

    try output_writer.interface.writeAll("epak");

    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--file")) {
            const dest_path = args.next() orelse return error.MissingDestPath;
            const source_file = args.next() orelse return error.MissingSourceFile;
            const name_len: u16 = @intCast(dest_path.len);

            try output_writer.interface.writeAll(&.{std.mem.asBytes(&name_len)[1]});
            try output_writer.interface.writeAll(&.{std.mem.asBytes(&name_len)[0]});
            try output_writer.interface.writeAll(dest_path);

            const input_file = try std.Io.Dir.cwd().openFile(init.io, source_file, .{});
            defer input_file.close(init.io);

            var input_reader = input_file.reader(init.io, &.{});
            const data_len: u16 = @intCast(try input_reader.interface.readSliceShort(&data));

            try output_writer.interface.writeAll(&.{std.mem.asBytes(&data_len)[1]});
            try output_writer.interface.writeAll(&.{std.mem.asBytes(&data_len)[0]});
            try output_writer.interface.writeAll(data[0..data_len]);
        } else return error.UnknownArg;
    }
}
