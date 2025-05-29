const std = @import("std");
const zigimg = @import("../deps/zigimg/zigimg.zig");

// struct FontChar {
//   []const []const u1: data,
// }
//
// struct FontFile {
//   u8: char_height,
//   u8: char_width,
//   u8: bottom_y,
//   FontChar: [256] chars,
// }

const SPACING = 1;

pub fn convert(b: *std.Build, paths: []const std.Build.LazyPath, output: std.Build.LazyPath) !void {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    const path = output.getPath(b);
    var file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    const writer = file.writer();

    var image = try zigimg.Image.fromFilePath(b.allocator, in.getPath3(b, null).sub_path);
    defer image.deinit();

    try writer.writeAll("efnt");

    const chw = image.width / 16;
    const chh = image.height / 16 + SPACING;

    try writer.writeAll(&.{
        @intCast(chw),
        @intCast(chh),
        1,
    });

    for (0..16) |x| {
        for (0..16) |y| {
            var ch = try b.allocator.alloc(u8, chw * chh);
            defer b.allocator.free(ch);
            @memset(ch, 0);

            for (0..chw) |chx| {
                for (0..chh - SPACING) |chy| {
                    const pixelx = x * chw + chx;
                    const pixely = y * (chh - SPACING) + chy;

                    const pixel = image.pixels.rgba32[pixely + pixelx * image.height];

                    ch[chy + chx * (chh - SPACING)] = pixel.r * @divTrunc(pixel.a, 255);
                }
            }

            try writer.writeAll(ch);
        }
    }
}
