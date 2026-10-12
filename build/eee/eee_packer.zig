const std = @import("std");
const files = @import("sandeee").system.files;
const Disk = @import("sandeee").system.Disk;
const strings = @import("sandeee").data.strings;
const util = @import("sandeee").util;

var content: [100_000_000]u8 = undefined;

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();
    const output_file = args.next() orelse return error.MissingOutputFile;

    util.io = init.io;

    {
        var file = try std.Io.Dir.cwd().createFile(init.io, output_file, .{});
        defer file.close(init.io);

        var buf: [1024]u8 = undefined;
        var writer = file.writer(init.io, &buf);
        try writer.interface.writeAll(&std.mem.toBytes(Disk.BLANK_DISK));
    }

    var disk_file = try std.Io.Dir.cwd().openFile(init.io, output_file, .{ .mode = .read_write });
    defer disk_file.close(init.io);

    files.disk = try .init(init.io, init.gpa, disk_file);
    defer files.disk.deinit();

    const files_root = files.disk.root();
    files.named_paths.set(.root, files_root);

    var count: usize = 0;
    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--dir")) {
            const folder_path = args.next() orelse return error.MissingDirectory;
            _ = files_root.createFolder(folder_path);
        } else if (std.mem.eql(u8, kind, "--file")) {
            const input_path = args.next() orelse return error.MissingFile;
            const disk_path = args.next() orelse return error.MissingPath;

            var created_file = files_root.createFile(disk_path);
            defer created_file.deinit();

            const file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
            defer file.close(init.io);

            var tmp_buffer: [512]u8 = undefined;
            var reader = file.reader(init.io, &tmp_buffer);
            const content_len = try reader.interface.readSliceShort(&content);

            try created_file.write(content[0..content_len], null);
            count += 1;
        } else if (std.mem.eql(u8, kind, "--disk")) {
            const input_path = args.next() orelse return error.MissingFile;

            const recovery = try std.Io.Dir.cwd().openFile(init.io, input_path, .{ .mode = .read_write });
            defer recovery.close(init.io);

            var overlay_disk: Disk = try .init(init.io, init.gpa, recovery);
            defer overlay_disk.deinit();

            // var folder_list = std.array_list.Managed(*const files.Folder).init(init.gpa);
            // defer folder_list.deinit();
            // try overlay_disk.getFoldersRec(&folder_list, false);
            //
            // for (folder_list.items) |folder| {
            //     files_root.newFolder(folder.name, true) catch |err| switch (err) {
            //         error.FolderExists => {},
            //         else => |e| return e,
            //     };
            // }
            //
            // var file_list = std.array_list.Managed(*files.File).init(init.gpa);
            // defer file_list.deinit();
            // try overlay_disk.getFilesRec(&file_list, false);

            // for (file_list.items) |file| {
            //     if (file.data != .disk) continue;

            //     files_root.newFile(file.name) catch |err| switch (err) {
            //         error.FileExists => {},
            //         else => |e| return e,
            //     };
            //     try files_root.writeFile(file.name, file.data.disk, null);
            // }
        } else {
            std.log.info("{s}", .{kind});
            return error.UnknownArg;
        }
    }
}
