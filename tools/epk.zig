const std = @import("std");
const eon = @import("eon.zig");
const asma = @import("asm.zig");
const sounds = @import("sound.zig");
const textures = @import("textures.zig");

var eonLock = std.Thread.Mutex{};

// converts a eep to a epk
pub fn convert(in: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(alloc);

    try result.appendSlice("epak");

    var split = std.mem.split(u8, in, ";");

    while (split.next()) |item| {
        const idx = std.mem.indexOf(u8, item, ":") orelse return error.BadInput;
        const name = item[idx + 1 ..];
        const nameLen: u16 = @intCast(name.len);

        try result.append(std.mem.asBytes(&nameLen)[1]);
        try result.append(std.mem.asBytes(&nameLen)[0]);
        try result.appendSlice(name);

        const ext = item[idx - 4 .. idx];

        if (std.mem.eql(u8, ext, ".eon")) {
            eonLock.lock();
            defer eonLock.unlock();
            {
                const data = try eon.compileEon(item[0..idx], alloc);

                const file = try std.fs.createFileAbsolute("/tmp/eon.asm", .{});
                defer file.close();

                try file.writeAll(data.items);
            }

            const data = try asma.compile("/tmp/eon.asm", alloc);
            defer data.deinit();

            const dataLen: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&dataLen)[1]);
            try result.append(std.mem.asBytes(&dataLen)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        if (std.mem.eql(u8, ext, ".asm")) {
            const data = try asma.compile(item[0..idx], alloc);
            defer data.deinit();

            const dataLen: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&dataLen)[1]);
            try result.append(std.mem.asBytes(&dataLen)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        if (std.mem.eql(u8, ext, ".wav")) {
            const data = try sounds.convert(item[0..idx], alloc);
            defer data.deinit();

            const dataLen: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&dataLen)[1]);
            try result.append(std.mem.asBytes(&dataLen)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        if (std.mem.eql(u8, ext, ".png")) {
            const data = try textures.convert(item[0..idx], alloc);
            defer data.deinit();

            const dataLen: u16 = @intCast(data.items.len);

            try result.append(std.mem.asBytes(&dataLen)[1]);
            try result.append(std.mem.asBytes(&dataLen)[0]);
            try result.appendSlice(data.items);

            continue;
        }

        return error.BadInput;
    }

    return result;
}
