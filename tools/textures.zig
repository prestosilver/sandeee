const std = @import("std");
const zigimg = @import("deps/zigimg/zigimg.zig");

const lol = error{};

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub fn read_next(stream: anytype, size: u8, first: u8) u32 {
    var total: u32 = first;

    for (range(size)) |_| {
        total = @intCast(u32, total << 8) + @intCast(u32, stream.readInt(u8, std.builtin.Endian.Little) catch 0);
    }

    return total;
}

// converts a png to a ebi
pub fn convert(in: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(alloc);

    var image = try zigimg.Image.fromFilePath(alloc, in);
    defer image.deinit();

    try result.appendSlice("eimg");

    try result.appendSlice(&std.mem.toBytes(@intCast(u16, image.width)));
    try result.appendSlice(&std.mem.toBytes(@intCast(u16, image.height)));

    var iter = zigimg.color.PixelStorageIterator.init(&image.pixels);

    while (iter.next()) |item| {
        try result.appendSlice(&std.mem.toBytes(@intCast(u8, @floatToInt(u8, item.r * 255))));
        try result.appendSlice(&std.mem.toBytes(@intCast(u8, @floatToInt(u8, item.g * 255))));
        try result.appendSlice(&std.mem.toBytes(@intCast(u8, @floatToInt(u8, item.b * 255))));
        try result.appendSlice(&std.mem.toBytes(@intCast(u8, @floatToInt(u8, item.a * 255))));
    }

    return result;
}
