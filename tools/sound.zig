const std = @import("std");

// Converts a wav file to a era file
pub fn convert(paths: []const []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    var result = std.ArrayList(u8).init(alloc);

    var inreader = try std.fs.cwd().openFile(in, .{});
    defer inreader.close();

    var buf_reader = std.io.bufferedReader(inreader.reader());
    var reader_stream = buf_reader.reader();

    var name: [4]u8 = undefined;

    try reader_stream.skipBytes(12, .{});

    var chanels: u16 = 0;
    var sr: u16 = 0;

    while (true) {
        if (try reader_stream.read(&name) != 4) break;
        const size = try reader_stream.readInt(u32, .little);
        const section = try alloc.alloc(u8, size);
        defer alloc.free(section);
        if (size != try reader_stream.read(section)) return error.BadSection;

        if (std.mem.eql(u8, &name, "RIFF")) {
            continue;
        }
        if (std.mem.eql(u8, &name, "fmt ")) {
            chanels = @as(u8, @intCast(section[10])); //HACK 99% of wavs have 2 chanels
            sr = @as(u8, @intCast(section[14] >> 3));

            continue;
        }
        if (std.mem.eql(u8, &name, "LIST")) {
            continue;
        }
        if (std.mem.eql(u8, &name, "data")) {
            if (chanels == 1) {
                try result.appendSlice(section);
            } else {
                for (0..section.len) |idx| {
                    if ((chanels * sr) == 0 or idx % (chanels * sr) == 0) {
                        var tmp: i16 = @as(i16, @intCast(@as(i8, @bitCast(section[idx + sr - 1]))));
                        tmp += 128;

                        try result.append(@as(u8, @intCast(tmp)));
                    }
                }
            }

            continue;
        }
        return error.BadSection;
    }

    return result;
}
