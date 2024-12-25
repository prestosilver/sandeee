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

pub fn convert(b: *std.Build, paths: []const std.Build.LazyPath) !std.ArrayList(u8) {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    var result = std.ArrayList(u8).init(b.allocator);

    var image = try zigimg.Image.fromFilePath(b.allocator, in.getPath3(b, null).sub_path);
    defer image.deinit();

    try result.appendSlice("efnt");

    const chw = image.width / 16;
    const chh = image.height / 16 + SPACING;

    try result.append(@intCast(chw));
    try result.append(@intCast(chh));
    try result.append(1);

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

            try result.appendSlice(ch);
        }
    }

    return result;
}
