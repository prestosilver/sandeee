const std = @import("std");
const files = @import("sandeee").system.files;
const strings = @import("sandeee").data.strings;

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
        .name = strings.ROOT_PATH,
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

            const file = try std.fs.cwd().openFile(input_path, .{});
            defer file.close();

            const content_len = try file.readAll(&content);

            try files_root.writeFile(disk_path, content[0..content_len], null);
            count += 1;
        } else if (std.mem.eql(u8, kind, "--disk")) {
            const input_path = args.next() orelse return error.MissingFile;

            const recovery = try std.fs.cwd().openFile(input_path, .{});
            defer recovery.close();

            var overlay_disk = try files.Folder.loadDisk(recovery);
            defer overlay_disk.deinit();

            var folder_list = std.array_list.Managed(*const files.Folder).init(allocator);
            defer folder_list.deinit();
            try overlay_disk.getFoldersRec(&folder_list);

            for (folder_list.items) |folder| {
                files_root.newFolder(folder.name) catch |err| switch (err) {
                    error.FolderExists => {},
                    else => |e| return e,
                };
            }

            var file_list = std.array_list.Managed(*files.File).init(allocator);
            defer file_list.deinit();
            try overlay_disk.getFilesRec(&file_list);

            for (file_list.items) |file| {
                if (file.data != .disk) continue;

                try files_root.newFile(file.name);
                try files_root.writeFile(file.name, file.data.disk, null);
            }
        } else {
            std.log.info("{s}", .{kind});
            return error.UnknownArg;
        }
    }

    try std.fs.cwd().writeFile(.{
        .sub_path = output_file,
        .data = (try files.toStr()).items,
    });
}
