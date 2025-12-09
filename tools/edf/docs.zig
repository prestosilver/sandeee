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

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const root_name = args.next() orelse return error.MissingRootName;
    const input_path = args.next() orelse return error.MissingInputPath;
    const output_path = args.next() orelse return error.MissingOutputPath;

    std.fs.deleteTreeAbsolute(output_path) catch {};
    try std.fs.makeDirAbsolute(output_path);

    var walker = try std.fs.openDirAbsolute(input_path, .{
        .iterate = true,
    });

    var iter = try walker.walk(allocator);

    while (try iter.next()) |path| {
        switch (path.kind) {
            .directory => {
                const dir_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ output_path, path.path });
                defer allocator.free(dir_path);
                try std.fs.cwd().makePath(dir_path);
            },
            .file => {
                const input_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ input_path, path.path });
                defer allocator.free(input_file_path);

                const output_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ output_path, path.path });
                defer allocator.free(output_file_path);

                const input_file = try std.fs.cwd().openFile(input_file_path, .{ .mode = .read_only });
                defer input_file.close();
                const output_file = try std.fs.cwd().createFile(output_file_path, .{});
                defer output_file.close();

                var reader = input_file.reader();

                _ = try output_file.write(DOC_HEADER);

                while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
                    defer allocator.free(line);

                    if (std.mem.containsAtLeast(u8, line, 1, "> ")) {
                        const link_index = std.mem.indexOf(u8, line, "> ") orelse unreachable;
                        const index = link_index + 2 + (std.mem.indexOf(u8, line[link_index..], ": ") orelse 0);
                        _ = try output_file.write(line[0..index]);
                        _ = try output_file.write(root_name);
                        _ = try output_file.write(line[index..]);
                    } else {
                        _ = try output_file.write(line);
                    }

                    _ = try output_file.write("\n");
                }

                _ = try output_file.write(DOC_FOOTER);
            },
            else => {
                continue;
            },
        }
    }
}
