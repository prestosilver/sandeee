const std = @import("std");
const zigimg = @import("zigimg");

// Binary repr:
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

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const input_file = args.next() orelse return error.MissingInputFile;
    const output_file = args.next() orelse return error.MissingOutputFile;

    var file = try std.fs.createFileAbsolute(output_file, .{});
    defer file.close();

    var writer_buffer: [1024]u8 = undefined;
    var writer = file.writer(&writer_buffer);

    var reader_buffer: [1024]u8 = undefined;
    var image = try zigimg.Image.fromFilePath(allocator, input_file, &reader_buffer);
    defer image.deinit(allocator);

    try writer.interface.writeAll("efnt");

    const chw = image.width / 16;
    const chh = image.height / 16 + SPACING;

    try writer.interface.writeAll(&.{
        @intCast(chw),
        @intCast(chh),
        1,
    });

    for (0..16) |x| {
        for (0..16) |y| {
            var ch = try allocator.alloc(u8, chw * chh);
            defer allocator.free(ch);
            @memset(ch, 0);

            for (0..chw) |chx| {
                for (0..chh - SPACING) |chy| {
                    const pixelx = x * chw + chx;
                    const pixely = y * (chh - SPACING) + chy;

                    const pixel = image.pixels.rgba32[pixely + pixelx * image.height];

                    ch[chy + chx * (chh - SPACING)] = pixel.r * @divTrunc(pixel.a, 255);
                }
            }

            try writer.interface.writeAll(ch);
        }
    }
}
