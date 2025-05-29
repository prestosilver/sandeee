const std = @import("std");
const zigimg = @import("../deps/zigimg/zigimg.zig");

// converts a png to a ebi
pub fn convert(
    b: *std.Build,
    paths: []const std.Build.LazyPath,
    output: std.Build.LazyPath,
) !void {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    const path = output.getPath(b);
    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    const writer = file.writer();

    var image = try zigimg.Image.fromFilePath(b.allocator, in.getPath(b));
    defer image.deinit();

    try writer.writeAll("eimg");

    try writer.writeAll(&std.mem.toBytes(@as(u16, @intCast(image.width))));
    try writer.writeAll(&std.mem.toBytes(@as(u16, @intCast(image.height))));

    var iter = zigimg.color.PixelStorageIterator.init(&image.pixels);

    while (iter.next()) |item| {
        try writer.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.r * 255))))));
        try writer.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.g * 255))))));
        try writer.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.b * 255))))));
        try writer.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.a * 255))))));
    }
}
