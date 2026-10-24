const std = @import("std");

const FormatCode = enum(u16) {
    pcm = 1,
    ieee_float = 3,
    alaw = 6,
    mulaw = 7,
    extensible = 0xFFFE,
    _,
};

const FormatSection = struct {
    code: FormatCode,
    channels: u16,
    sample_rate: u32,
    bytes_per_second: u32,
    block_align: u16,
    bits: u16,
};

// Converts a wav file to a era file
pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();

    _ = args.next();

    const input_file = args.next() orelse return error.MissingInputFile;
    const output_file = args.next() orelse return error.MissingOutputFile;

    var file = try std.Io.Dir.cwd().createFile(init.io, output_file, .{});
    defer file.close(init.io);

    var writer = file.writer(init.io, &.{});

    var inreader = try std.Io.Dir.cwd().openFile(init.io, input_file, .{});
    defer inreader.close(init.io);

    var reader_buffer: [1024]u8 = undefined;
    var reader_stream = inreader.reader(init.io, &reader_buffer);

    var name: [4]u8 = undefined;

    try reader_stream.interface.discardAll(12);

    var format: FormatSection = undefined;

    while (true) {
        reader_stream.interface.readSliceAll(&name) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        const size = try reader_stream.interface.takeInt(u32, .little);
        const section = try init.gpa.alloc(u8, size);
        defer init.gpa.free(section);
        try reader_stream.interface.readSliceAll(section);

        if (std.mem.eql(u8, &name, "fmt ")) {
            format = @as(*align(1) FormatSection, @ptrCast(&section[0])).*;
        } else if (std.mem.eql(u8, &name, "data")) {
            const tmp_out = try init.gpa.alloc(u8, section.len / format.channels / (format.bits / 8));
            defer init.gpa.free(tmp_out);

            inline for (.{ i32, i24, i16, u8 }) |SampleT| {
                if (@bitSizeOf(SampleT) == format.bits) {
                    for (0.., tmp_out) |idx, *sample| {
                        const in_sample: f32 = @floatFromInt(@as(*align(1) SampleT, @ptrCast(&section[idx * @sizeOf(SampleT) * format.channels])).*);
                        const max_sample: f32 = @floatFromInt(std.math.maxInt(SampleT));
                        const min_sample: f32 = @floatFromInt(std.math.minInt(SampleT));

                        const normalized_sample = @min((in_sample - min_sample) / (max_sample - min_sample), 255);

                        sample.* = @intFromFloat(normalized_sample * 255);
                    }

                    break;
                }
            } else return error.InvalidFormat;

            try writer.interface.writeAll(tmp_out);
        } else if (std.mem.eql(u8, &name, "LIST")) {} else if (std.mem.eql(u8, &name, "RIFF")) {} else return error.BadSection;
    }
}
