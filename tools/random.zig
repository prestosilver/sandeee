const std = @import("std");

pub fn create(_: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var result = try std.ArrayList(u8).initCapacity(alloc, 1024);

    try result.appendSlice("EEEp");

    var buffer: [1020]u8 = undefined;

    var idx: usize = 0;
    var rnd = std.rand.DefaultPrng.init(@intCast(std.time.microTimestamp()));

    while (true) {
        const inst = rnd.random().int(u8) % 34;
        const dataType = rnd.random().int(u8) % 3;
        switch (dataType) {
            else => {
                if (idx + 2 >= buffer.len) break;
                buffer[idx + 0] = inst;
                buffer[idx + 1] = 0;
                idx += 2;
            },
            1 => {
                if (idx + 3 >= buffer.len) break;
                buffer[idx + 0] = inst;
                buffer[idx + 1] = 3;
                buffer[idx + 2] = rnd.random().int(u8);
                idx += 3;
            },
            2 => {
                if (idx + 6 >= buffer.len) break;
                buffer[idx + 0] = inst;
                buffer[idx + 1] = 2;
                buffer[idx + 2] = 'f';
                buffer[idx + 3] = 'o';
                buffer[idx + 4] = 'o';
                buffer[idx + 5] = 0;
                idx += 6;
            },
        }
    }

    try result.appendSlice(buffer[0..idx]);

    return result;
}
