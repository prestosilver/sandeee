const std = @import("std");

const DOC_HEADER: []const u8 =
    \\#Style @/style.eds
    \\:logo: [@/logo.eia]
    \\
    \\
;

const DOC_FOOTER =
    \\
    \\:center: --- EEE Sees all ---
;

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();

    const root_name = args.next() orelse return error.MissingRootName;
    const input_path = args.next() orelse return error.MissingInputPath;
    const output_path = args.next() orelse return error.MissingOutputPath;

    {
        const output_dir = try std.Io.Dir.openDirAbsolute(init.io, output_path, .{});
        defer output_dir.close(init.io);

        output_dir.deleteTree(init.io, output_path) catch {};
    }

    try std.Io.Dir.createDirAbsolute(init.io, output_path, .default_dir);

    var walker = try std.Io.Dir.openDirAbsolute(init.io, input_path, .{
        .iterate = true,
    });
    defer walker.close(init.io);

    var iter = try walker.walk(init.gpa);
    defer iter.deinit();

    while (try iter.next(init.io)) |path| {
        switch (path.kind) {
            .directory => {
                const dir_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ output_path, path.path });
                defer init.gpa.free(dir_path);

                try std.Io.Dir.cwd().createDirPath(init.io, dir_path);
            },
            .file => {
                const input_file_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ input_path, path.path });
                defer init.gpa.free(input_file_path);

                const output_file_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ output_path, path.path });
                defer init.gpa.free(output_file_path);

                const input_file = try std.Io.Dir.cwd().openFile(init.io, input_file_path, .{ .mode = .read_only });
                defer input_file.close(init.io);
                const output_file = try std.Io.Dir.cwd().createFile(init.io, output_file_path, .{});
                defer output_file.close(init.io);

                var reader_buffer: [1024]u8 = undefined;
                var reader = input_file.reader(init.io, &reader_buffer);

                var writer_buffer: [1024]u8 = undefined;
                var writer = output_file.writer(init.io, &writer_buffer);

                _ = try writer.interface.write(DOC_HEADER);

                while (try reader.interface.takeDelimiter('\n')) |line| {
                    if (std.mem.containsAtLeast(u8, line, 1, "> ")) {
                        const link_index = std.mem.indexOf(u8, line, "> ") orelse unreachable;
                        const index = link_index + 2 + (std.mem.indexOf(u8, line[link_index..], ": ") orelse 0);
                        try writer.interface.writeAll(line[0..index]);
                        try writer.interface.writeAll(root_name);
                        try writer.interface.writeAll(line[index..]);
                    } else {
                        try writer.interface.writeAll(line);
                    }

                    try writer.interface.writeAll("\n");
                }

                try writer.interface.writeAll(DOC_FOOTER);
            },
            else => {
                continue;
            },
        }
    }
}
