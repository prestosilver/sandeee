const std = @import("std");
const zigimg = @import("zigimg");

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

// converts a png to a eia
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
