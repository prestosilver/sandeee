const std = @import("std");
const eon = @import("eon.zig");
const asma = @import("asm.zig");
const sounds = @import("sound.zig");
const textures = @import("textures.zig");

var eonLock = std.Thread.Mutex{};

// converts a eep to a epk
pub fn convert(b: *std.Build, in: []const []const u8) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(b.allocator);

    try result.appendSlice("epak");

    for (in) |item| {
        const idx = std.mem.indexOf(u8, item, ":") orelse return error.BadInput;
        const name = item[idx + 1 ..];
        const name_len: u16 = @intCast(name.len);

        try result.append(std.mem.asBytes(&name_len)[1]);
        try result.append(std.mem.asBytes(&name_len)[0]);
        try result.appendSlice(name);

        const ext = item[idx - 4 .. idx];

        if (std.mem.eql(u8, ext, ".eon")) {
            eonLock.lock();
            defer eonLock.unlock();
            {
                const data = try eon.compileEon(b, &.{b.path(item[0..idx])});

                const file = try std.fs.createFileAbsolute("/tmp/eon.asm", .{});
                defer file.close();

                try file.writeAll(data.items);
            }

            const data = try asma.compile(b, &.{"/tmp/eon.asm"});
            defer data.deinit();

            const data_len: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&data_len)[1]);
            try result.append(std.mem.asBytes(&data_len)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        if (std.mem.eql(u8, ext, ".asm")) {
            const data = try asma.compile(b, &.{item[0..idx]});
            defer data.deinit();

            const data_len: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&data_len)[1]);
            try result.append(std.mem.asBytes(&data_len)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        if (std.mem.eql(u8, ext, ".wav")) {
            const data = try sounds.convert(b, &.{item[0..idx]});
            defer data.deinit();

            const data_len: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&data_len)[1]);
            try result.append(std.mem.asBytes(&data_len)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        if (std.mem.eql(u8, ext, ".png")) {
            const data = try textures.convert(b, &.{item[0..idx]});
            defer data.deinit();

            const data_len: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&data_len)[1]);
            try result.append(std.mem.asBytes(&data_len)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        if (std.mem.eql(u8, ext, ".eln")) {
            const data = try std.fs.cwd().readFileAlloc(b.allocator, item[0..idx], 100);
            defer b.allocator.free(data);

            const data_len: u16 = @intCast(data.len);

            try result.append(std.mem.asBytes(&data_len)[1]);
            try result.append(std.mem.asBytes(&data_len)[0]);
            try result.appendSlice(data);

            continue;
        }

        return error.BadInput;
    }

    return result;
}
