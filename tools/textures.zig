const std = @import("std");
const zigimg = @import("deps/zigimg/zigimg.zig");

// converts a png to a ebi
pub fn convert(b: *std.Build, paths: []const std.Build.LazyPath) !std.ArrayList(u8) {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    var result = std.ArrayList(u8).init(b.allocator);

    var image = try zigimg.Image.fromFilePath(b.allocator, in.getPath3(b, null).sub_path);
    defer image.deinit();

    try result.appendSlice("eimg");

    try result.appendSlice(&std.mem.toBytes(@as(u16, @intCast(image.width))));
    try result.appendSlice(&std.mem.toBytes(@as(u16, @intCast(image.height))));

    var iter = zigimg.color.PixelStorageIterator.init(&image.pixels);

    while (iter.next()) |item| {
        try result.appendSlice(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.r * 255))))));
        try result.appendSlice(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.g * 255))))));
        try result.appendSlice(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.b * 255))))));
        try result.appendSlice(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.a * 255))))));
    }

    return result;
}
