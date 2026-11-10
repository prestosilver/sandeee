const std = @import("std");

const options = @import("docs_options");

test "Docs have Style" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    var input_dir = try std.Io.Dir.cwd().openDir(io, options.www_path, .{
        .iterate = true,
    });
    defer input_dir.close(io);

    var iter = try input_dir.walk(allocator);
    defer iter.deinit();

    while (try iter.next(io)) |path| {
        switch (path.kind) {
            .file => {
                const input_file = try input_dir.openFile(io, path.path, .{ .mode = .read_only });
                defer input_file.close(io);

                var reader_buffer: [1024]u8 = undefined;
                var reader = input_file.reader(io, &reader_buffer);

                var line = try reader.interface.takeDelimiter('\n') orelse "";
                if (!std.mem.eql(u8, line, "#Style @/style.eds")) {
                    std.log.err("{s}", .{path.path});
                    return error.MissingStyle;
                }

                while (try reader.interface.takeDelimiter('\n')) |cur_line|
                    line = cur_line;

                if (!std.mem.eql(u8, line, ":center: --- EEE Sees all ---")) {
                    std.log.err("{s}", .{path.path});
                    return error.MissingFooter;
                }
            },
            else => continue,
        }
    }
}

test "Docs have Indexes" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    var input_dir = try std.Io.Dir.cwd().openDir(io, options.www_path, .{
        .iterate = true,
    });
    defer input_dir.close(io);

    var iter = try input_dir.walk(allocator);
    defer iter.deinit();

    while (try iter.next(io)) |path| {
        switch (path.kind) {
            .directory => {
                const dir = try input_dir.openDir(io, path.path, .{});
                defer dir.close(io);

                _ = dir.statFile(io, "index.edf", .{}) catch {
                    std.log.err("{s}", .{path.path});
                    return error.NoIndex;
                };
            },
            else => continue,
        }
    }
}

test "Docs have no hidden entries" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    var input_dir = try std.Io.Dir.cwd().openDir(io, options.www_path, .{
        .iterate = true,
    });
    defer input_dir.close(io);

    var iter = try input_dir.walk(allocator);
    defer iter.deinit();

    while (try iter.next(io)) |path| {
        if (std.mem.startsWith(u8, path.basename, "_")) {
            std.log.err("{s}", .{path.path});
            return error.HiddenItem;
        }
    }
}