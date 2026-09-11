const std = @import("std");
const zigimg = @import("zigimg");

// converts a png to a eia
pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next();

    const input_file = args.next() orelse return error.MissingInputFile;
    const output_file = args.next() orelse return error.MissingOutputFile;

    var file = try std.Io.Dir.createFileAbsolute(init.io, output_file, .{});
    defer file.close(init.io);

    var writer = file.writer(init.io, &.{});

    var reader_buffer: [1024]u8 = undefined;
    var image = try zigimg.Image.fromFilePath(init.gpa, init.io, input_file, &reader_buffer);
    defer image.deinit(init.gpa);

    try writer.interface.writeAll("eimg");

    try writer.interface.writeAll(&std.mem.toBytes(@as(u16, @intCast(image.width))));
    try writer.interface.writeAll(&std.mem.toBytes(@as(u16, @intCast(image.height))));

    var iter = zigimg.color.PixelStorageIterator.init(&image.pixels);

    while (iter.next()) |item| {
        try writer.interface.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.r * 255))))));
        try writer.interface.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.g * 255))))));
        try writer.interface.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.b * 255))))));
        try writer.interface.writeAll(&std.mem.toBytes(@as(u8, @intCast(@as(u8, @intFromFloat(item.a * 255))))));
    }
}
