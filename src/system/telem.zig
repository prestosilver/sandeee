const std = @import("std");
const files = @import("files.zig");
const allocator = @import("../util/allocator.zig");

pub const Telem = struct {
    pub const PATH = "/_telem";

    pub var instance: Telem = .{};

    logins: u64 = 0,
    instructionCalls: u128 = 0,

    pub fn save() !void {
        const conts = std.mem.asBytes(&instance);

        _ = try files.root.newFile(PATH);
        try files.root.writeFile(PATH, conts, null);
    }

    pub fn load() !void {
        if (files.root.getFile(PATH) catch null) |file| {
            const conts = try file.read(null);

            if (conts.len != @sizeOf(Telem)) return;

            instance = std.mem.bytesToValue(Telem, conts[0..@sizeOf(Telem)]);
        }
    }
};
