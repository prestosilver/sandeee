const std = @import("std");

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

var data: [100_000_000]u8 = undefined;

// converts a eep to a epk
pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const output_file_path = args.next() orelse return error.MissingOutputFile;

    var output_file = try std.fs.createFileAbsolute(output_file_path, .{});

    try output_file.writeAll("epak");

    while (args.next()) |kind| {
        if (std.mem.eql(u8, kind, "--file")) {
            // const idx = std.mem.indexOf(u8, item, ":") orelse return error.BadInput;
            // const name = item[idx + 1 ..];
            // const name_len: u16 = @intCast(name.len);
            const dest_path = args.next() orelse return error.MissingDestPath;
            const source_file = args.next() orelse return error.MissingSourceFile;
            const name_len: u16 = @intCast(dest_path.len);

            try output_file.writeAll(&.{std.mem.asBytes(&name_len)[1]});
            try output_file.writeAll(&.{std.mem.asBytes(&name_len)[0]});
            try output_file.writeAll(dest_path);

            const input_file = try std.fs.openFileAbsolute(source_file, .{});
            defer input_file.close();

            const data_len: u16 = @intCast(try input_file.readAll(&data));

            try output_file.writeAll(&.{std.mem.asBytes(&data_len)[1]});
            try output_file.writeAll(&.{std.mem.asBytes(&data_len)[0]});
            try output_file.writeAll(data[0..data_len]);

            // const ext = item[idx - 4 .. idx];

            // if (std.mem.eql(u8, ext, ".eon")) {
            //     eonLock.lock();
            //     defer eonLock.unlock();

            //     {
            //         const data = try eon.compileEon(b, &.{b.path(item[0..idx])});

            //         const file = try std.fs.createFileAbsolute("/tmp/eon.asm", .{});
            //         defer file.close();

            //         try file.writeAll(data.items);
            //     }

            //     const data = try asma.compile(b, b.path("/tmp/eon.asm"));
            //     defer data.deinit();

            //     const data_len: u16 = @intCast(data.items.len);

            //     try result.append(std.mem.asBytes(&data_len)[1]);
            //     try result.append(std.mem.asBytes(&data_len)[0]);
            //     try result.appendSlice(data.items);

            //     continue;
            // }

            // if (std.mem.eql(u8, ext, ".asm")) {
            //     const data = try asma.compile(b, &.{item[0..idx]});
            //     defer data.deinit();

            //     const data_len: u16 = @intCast(data.items.len);

            //     try result.append(std.mem.asBytes(&data_len)[1]);
            //     try result.append(std.mem.asBytes(&data_len)[0]);
            //     try result.appendSlice(data.items);

            //     continue;
            // }

            // if (std.mem.eql(u8, ext, ".wav")) {
            //     const data = try sounds.convert(b, &.{item[0..idx]});
            //     defer data.deinit();

            //     const data_len: u16 = @intCast(data.items.len);

            //     try result.append(std.mem.asBytes(&data_len)[1]);
            //     try result.append(std.mem.asBytes(&data_len)[0]);
            //     try result.appendSlice(data.items);

            //     continue;
            // }

            // if (std.mem.eql(u8, ext, ".png")) {
            //     const data = try textures.convert(b, &.{item[0..idx]});
            //     defer data.deinit();

            //     const data_len: u16 = @intCast(data.items.len);

            //     try result.append(std.mem.asBytes(&data_len)[1]);
            //     try result.append(std.mem.asBytes(&data_len)[0]);
            //     try result.appendSlice(data.items);

            //     continue;
            // }

            // if (std.mem.eql(u8, ext, ".eln")) {
            //     const data = try std.fs.cwd().readFileAlloc(b.allocator, item[0..idx], 100);
            //     defer b.allocator.free(data);

            //     const data_len: u16 = @intCast(data.len);

            //     try result.append(std.mem.asBytes(&data_len)[1]);
            //     try result.append(std.mem.asBytes(&data_len)[0]);
            //     try result.appendSlice(data);

            //     continue;
            // }

            // return error.BadInput;
        } else return error.UnknownArg;
    }
}
