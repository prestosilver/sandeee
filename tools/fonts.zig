const std = @import("std");
const zigimg = @import("deps/zigimg/zigimg.zig");

const lol = error{};

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

pub fn convert(in: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(alloc);

    var image = try zigimg.Image.fromFilePath(alloc, in);
    defer image.deinit();

    try result.appendSlice("efnt");

    var chw = image.width / 16;
    var chh = image.height / 16;

    try result.append(@intCast(u8, chw));
    try result.append(@intCast(u8, chh));
    try result.append(2);

    for (0..16) |x| {
        for (0..16) |y| {
            var ch = try alloc.alloc(u1, chw * chh);
            for (0..chw) |chx| {
                for (0..chh) |chy| {
                    var pixelx = x * chw + chx;
                    var pixely = y * chh + chy;

                    var pixel = image.pixels.rgba32[pixelx + pixely * image.width];

                    ch[chx + chy * chh] = if (pixel.g != 0) 1 else 0;
                }
            }

            var data = std.mem.toBytes(ch);

            try result.appendSlice(&data);

            alloc.free(ch);
        }
    }

    return result;
}
