const std = @import("std");

const Self = @This();

state: [256]u8,

pub fn init(key: []const u8) Self {
    var result: Self = undefined;
    for (&result.state, 0..) |*box, idx| {
        box.* = @intCast(idx);
    }

    var j: u8 = 0;

    for (&result.state, 0..) |*box, idx| {
        j = (j +% box.* +% key[idx % key.len]);
        const temp = box.*;
        box.* = result.state[j];
        result.state[j] = temp;
    }

    return result;
}

pub fn crypt(self: *Self, data: []u8) void {
    var i: u32 = 0;
    var j: u32 = 0;

    for (data) |*value| {
        i = (i + 1) % 256;
        j = (j + self.state[i]) % 256;

        const temp = self.state[i];
        self.state[i] = self.state[j];
        self.state[j] = temp;

        value.* ^= self.state[(self.state[i] +% self.state[j])];
    }
}

test "Check crypto" {
    const key = "SecretKey123";

    const in_msg = "Hello World!";
    var msg: [in_msg.len]u8 = undefined;
    @memcpy(&msg, in_msg);

    var encrypt: Self = .init(key);
    encrypt.crypt(&msg);

    var decrypt: Self = .init(key);
    decrypt.crypt(&msg);

    try std.testing.expectEqualSlices(u8, in_msg, &msg);
}
