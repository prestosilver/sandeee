const std = @import("std");
const files = @import("sandeee").system.files;

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

var content: [100_000_000]u8 = undefined;

pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const output_file = args.next() orelse return error.MissingOutputFile;

    const files_root = try allocator.create(files.Folder);

    files_root.* = .{
        .parent = null,
        .name = files.ROOT_NAME,
    };

    files.named_paths.set(.root, files_root);

    var count: usize = 0;
    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--dir")) {
            const folder_path = args.next() orelse return error.MissingDirectory;
            files_root.newFolder(folder_path) catch |err| switch (err) {
                error.FolderExists => {},
                else => |e| return e,
            };
        } else if (std.mem.eql(u8, kind, "--file")) {
            const input_path = args.next() orelse return error.MissingFile;
            const disk_path = args.next() orelse return error.MissingPath;

            try files_root.newFile(disk_path);

            const file = try std.fs.openFileAbsolute(input_path, .{});
            defer file.close();

            const content_len = try file.readAll(&content);

            try files_root.writeFile(disk_path, content[0..content_len], null);
            count += 1;
        } else return error.UnknownArg;
    }

    try std.fs.cwd().writeFile(.{
        .sub_path = output_file,
        .data = (try files.toStr()).items,
    });
}
