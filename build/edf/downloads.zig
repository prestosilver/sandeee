const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();

    const output_file = args.next() orelse return error.MissingOutputFile;
    const output_path = args.next() orelse return error.MissingOutputPath;

    var out_file = std.Io.Dir.createFileAbsolute(init.io, output_file, .{ .exclusive = true }) catch |err| switch (err) {
        error.PathAlreadyExists => try std.Io.Dir.openFileAbsolute(init.io, output_file, .{}),
        else => |e| return e,
    };
    defer out_file.close(init.io);

    var writer = out_file.writer(init.io, &.{});

    try writer.interface.writeAll("#Style @/style.eds\n\n");
    try writer.interface.writeAll(":logo: [@/logo.eia]\n\n");
    try writer.interface.writeAll(":center: -- Downloads --\n\n");
    var section_folder: []const u8 = "";
    defer init.gpa.free(section_folder);

    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--section")) {
            const section_name = args.next() orelse return error.MissingSectionName;
            const section_folder_name = args.next() orelse return error.MissingSectionName;

            if (section_folder.len != 0)
                try writer.interface.writeAll("\n");

            init.gpa.free(section_folder);
            section_folder = try init.gpa.dupe(u8, section_folder_name);

            const targ_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}/", .{ output_path, section_folder });
            defer init.gpa.free(targ_path);

            try std.Io.Dir.createDirAbsolute(init.io, targ_path, .default_dir);

            try writer.interface.print(":hs: {s}\n\n", .{section_name});
        } else if (std.mem.eql(u8, kind, "--file")) {
            const file_name = args.next() orelse return error.MissingFileName;
            const file_path = args.next() orelse return error.MissingFilePath;
            const slash_index = std.mem.lastIndexOf(u8, file_path, "/") orelse return error.BadPath;

            const targ_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ section_folder, file_path[slash_index + 1 ..] });
            defer init.gpa.free(targ_path);

            try std.Io.Dir.cwd().copyFile(file_path, try std.Io.Dir.openDirAbsolute(init.io, output_path, .{}), targ_path, init.io, .{});

            try writer.interface.print(":biglink: > {s}: @/downloads/{s}/{s}\n", .{ file_name, section_folder, file_path[slash_index + 1 ..] });
        } else return error.UnknownArg;
    }

    try writer.interface.writeAll("\n:center: --- EEE Sees all ---");
}
