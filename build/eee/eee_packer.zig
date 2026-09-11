const std = @import("std");
const files = @import("sandeee").system.files;
const strings = @import("sandeee").data.strings;
const util = @import("sandeee").util;

var content: [100_000_000]u8 = undefined;

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();
    const output_file = args.next() orelse return error.MissingOutputFile;

    util.io = init.io;

    const files_root = try init.gpa.create(files.Folder);
    defer init.gpa.destroy(files_root);

    files_root.* = .{
        .parent = null,
        .name = strings.ROOT_PATH,
    };

    files.named_paths.set(.root, files_root);

    var count: usize = 0;
    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--dir")) {
            const folder_path = args.next() orelse return error.MissingDirectory;
            files_root.newFolder(folder_path, true) catch |err| switch (err) {
                error.FolderExists => {},
                else => |e| return e,
            };
        } else if (std.mem.eql(u8, kind, "--file")) {
            const input_path = args.next() orelse return error.MissingFile;
            const disk_path = args.next() orelse return error.MissingPath;

            files_root.newFile(disk_path) catch |err| switch (err) {
                error.FileExists => {},
                else => |e| return e,
            };

            const file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
            defer file.close(init.io);

            var tmp_buffer: [512]u8 = undefined;
            var reader = file.reader(init.io, &tmp_buffer);
            const content_len = try reader.interface.readSliceShort(&content);

            try files_root.writeFile(disk_path, content[0..content_len], null);
            count += 1;
        } else if (std.mem.eql(u8, kind, "--disk")) {
            const input_path = args.next() orelse return error.MissingFile;

            const recovery = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
            defer recovery.close(init.io);

            var overlay_disk = try files.Folder.loadDisk(recovery);
            defer overlay_disk.deinit();

            var folder_list = std.array_list.Managed(*const files.Folder).init(init.gpa);
            defer folder_list.deinit();
            try overlay_disk.getFoldersRec(&folder_list, false);

            for (folder_list.items) |folder| {
                files_root.newFolder(folder.name, true) catch |err| switch (err) {
                    error.FolderExists => {},
                    else => |e| return e,
                };
            }

            var file_list = std.array_list.Managed(*files.File).init(init.gpa);
            defer file_list.deinit();
            try overlay_disk.getFilesRec(&file_list, false);

            for (file_list.items) |file| {
                if (file.data != .disk) continue;

                files_root.newFile(file.name) catch |err| switch (err) {
                    error.FileExists => {},
                    else => |e| return e,
                };
                try files_root.writeFile(file.name, file.data.disk, null);
            }
        } else {
            std.log.info("{s}", .{kind});
            return error.UnknownArg;
        }
    }

    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_file,
        .data = (try files.toStr()).items,
    });
}
