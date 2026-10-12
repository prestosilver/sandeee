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
        const output_dir = try std.Io.Dir.cwd().openDir(init.io, output_path, .{});
        defer output_dir.close(init.io);

        output_dir.deleteTree(init.io, output_path) catch {};
    }

    std.Io.Dir.cwd().createDir(init.io, output_path, .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const output_dir = try std.Io.Dir.cwd().openDir(init.io, output_path, .{});
    defer output_dir.close(init.io);

    var input_dir = try std.Io.Dir.cwd().openDir(init.io, input_path, .{
        .iterate = true,
    });
    defer input_dir.close(init.io);

    var iter = try input_dir.walk(init.gpa);
    defer iter.deinit();

    while (try iter.next(init.io)) |path| {
        switch (path.kind) {
            .directory => {
                try output_dir.createDirPath(init.io, path.path);
            },
            .file => {
                const input_file = try input_dir.openFile(init.io, path.path, .{ .mode = .read_only });
                defer input_file.close(init.io);
                const output_file = try output_dir.createFile(init.io, path.path, .{});
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
