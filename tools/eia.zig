const std = @import("std");
const zigimg = @import("zigimg");

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

// converts a png to a eia
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const input_file = args.next() orelse return error.MissingInputFile;
    const output_file = args.next() orelse return error.MissingOutputFile;

    var file = try std.fs.createFileAbsolute(output_file, .{});
    defer file.close();

    const writer = file.writer();

    var image = try zigimg.Image.fromFilePath(allocator, input_file);
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
