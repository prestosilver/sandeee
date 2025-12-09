const std = @import("std");

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const output_file = args.next() orelse return error.MissingOutputFile;
    const output_path = args.next() orelse return error.MissingOutputPath;

    var out_file = try std.fs.createFileAbsolute(output_file, .{});
    defer out_file.close();

    const writer = out_file.writer();

    try writer.writeAll("#Style @/style.eds\n\n");
    try writer.writeAll(":logo: [@/logo.eia]\n\n");
    try writer.writeAll(":center: -- Downloads --\n\n");
    var section_folder: []const u8 = "";

    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--section")) {
            const section_name = args.next() orelse return error.MissingSectionName;
            const section_folder_name = args.next() orelse return error.MissingSectionName;

            if (section_folder.len != 0)
                try writer.writeAll("\n");

            section_folder = try allocator.dupe(u8, section_folder_name);

            const targ_path = try std.fmt.allocPrint(allocator, "{s}/{s}/", .{ output_path, section_folder });
            defer allocator.free(targ_path);

            try std.fs.makeDirAbsolute(targ_path);

            try writer.print(":hs: {s}\n\n", .{section_name});
        } else if (std.mem.eql(u8, kind, "--file")) {
            const file_name = args.next() orelse return error.MissingFileName;
            const file_path = args.next() orelse return error.MissingFilePath;
            const slash_index = std.mem.lastIndexOf(u8, file_path, "/") orelse return error.BadPath;

            const targ_path = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ output_path, section_folder, file_path[slash_index + 1 ..] });
            defer allocator.free(targ_path);

            try std.fs.copyFileAbsolute(file_path, targ_path, .{});

            try writer.print(":biglink: > {s}: @/downloads/{s}/{s}\n", .{ file_name, section_folder, file_path[slash_index + 1 ..] });
        } else return error.UnknownArg;
    }

    try writer.writeAll("\n:center: --- EEE Sees all ---");
}
