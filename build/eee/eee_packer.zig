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
        if (std.mem.eql(u8, kind, "--overlay")) {
            const overlay_path = args.next() orelse return error.MissingDirectory;
            var dir = std.Io.Dir.cwd().openDir(init.io, overlay_path, .{ .iterate = true }) catch unreachable;
            defer dir.close(init.io);

            var iter = dir.walk(init.gpa) catch unreachable;
            while (iter.next(init.io) catch unreachable) |path| {
                switch (path.kind) {
                    .file => {
                        var path_buf: [128]u8 = undefined;
                        const disk_path = try std.fmt.bufPrint(&path_buf, "/{s}", .{path.path});

                        files_root.newFile(disk_path) catch |err| switch (err) {
                            error.FileExists => {},
                            else => |e| return e,
                        };

                        const file = try dir.openFile(init.io, path.path, .{});
                        defer file.close(init.io);

                        var tmp_buffer: [512]u8 = undefined;
                        var reader = file.reader(init.io, &tmp_buffer);
                        const content_len = try reader.interface.readSliceShort(&content);

                        try files_root.writeFile(disk_path, content[0..content_len], null);
                        count += 1;
                    },
                    else => {},
                }
            }
        } else if (std.mem.eql(u8, kind, "--skeleton")) {
            const flag = args.next() orelse return error.MissingFlag;
            const skel_path = args.next() orelse return error.MissingFile;
            const skel_file = try std.Io.Dir.cwd().openFile(init.io, skel_path, .{});
            defer skel_file.close(init.io);

            var buffer: [512]u8 = undefined;
            var reader = skel_file.reader(init.io, &buffer);
            while (try reader.interface.takeDelimiter('\n')) |line| {
                if (line.len == 0)
                    continue;

                const first_space = std.mem.indexOf(u8, line, " ") orelse continue;

                if (std.mem.eql(u8, line[0..first_space], flag)) {
                    const folder_path = line[first_space + 1 ..];
                    files_root.newFolder(folder_path, true) catch |err| switch (err) {
                        error.FolderExists => {},
                        else => |e| return e,
                    };
                }
            }
        } else if (std.mem.eql(u8, kind, "--dir")) {
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
