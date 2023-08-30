const std = @import("std");

const InstructionData = struct {
    params: [3]bool,
    stack_in: u8,
    stack_out: u8,
    cstack: [2]bool = .{ false, false },
};

const INSTRUCTION_TYPES = [_]InstructionData{
    // none, int, string
    .{ .stack_out = 0, .stack_in = 0, .params = .{ true, false, false } }, // nop
    .{ .stack_out = 0, .stack_in = 3, .params = .{ false, true, false } }, // sys
    .{ .stack_out = 1, .stack_in = 0, .params = .{ false, true, true } }, // push
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // add
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // sub
    .{ .stack_out = 2, .stack_in = 1, .params = .{ false, true, false } }, // copy
    .{ .stack_out = 0, .stack_in = 0, .params = .{ false, true, false } }, // jmp
    .{ .stack_out = 0, .stack_in = 0, .params = .{ false, true, false } }, // jz
    .{ .stack_out = 0, .stack_in = 1, .params = .{ false, true, false } }, // jnz
    .{ .stack_out = 0, .stack_in = 1, .params = .{ false, true, false } }, // jmpf
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // mul
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // div
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // and
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // or
    .{ .stack_out = 1, .stack_in = 1, .params = .{ true, false, false } }, // not
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // eq
    .{ .stack_out = 1, .stack_in = 1, .params = .{ true, false, false } }, // getb
    .{ .stack_out = 0, .stack_in = 0, .params = .{ true, false, false }, .cstack = .{ false, true } }, // ret
    .{ .stack_out = 0, .stack_in = 1, .params = .{ true, false, false }, .cstack = .{ true, false } }, // call
    .{ .stack_out = 1, .stack_in = 1, .params = .{ true, false, false } }, // neg
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // xor
    .{ .stack_out = 0, .stack_in = 1, .params = .{ true, false, false } }, // disc
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // asign
    .{ .stack_out = 2, .stack_in = 1, .params = .{ false, true, false } }, // dup
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // less
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // gt
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // cat
    .{ .stack_out = 1, .stack_in = 2, .params = .{ true, false, false } }, // mod
    .{ .stack_out = 1, .stack_in = 1, .params = .{ false, true, false } }, // create
    .{ .stack_out = 1, .stack_in = 1, .params = .{ true, false, false } }, // size
    .{ .stack_out = 1, .stack_in = 1, .params = .{ true, false, false } }, // len
    .{ .stack_out = 1, .stack_in = 1, .params = .{ true, false, false } }, // sin
    .{ .stack_out = 1, .stack_in = 1, .params = .{ true, false, false } }, // cos
    .{ .stack_out = 1, .stack_in = 0, .params = .{ true, false, false } }, // rand
    .{ .stack_out = 0, .stack_in = 0, .params = .{ false, true, false } }, // seed
};

pub fn create(_: []const u8, alloc: std.mem.Allocator) !std.ArrayList(u8) {
    var result = try std.ArrayList(u8).initCapacity(alloc, 1024);

    try result.appendSlice("EEEp");

    var buffer: [1020]u8 = undefined;

    var idx: usize = 0;
    var rnd = std.rand.DefaultPrng.init(@intCast(std.time.microTimestamp()));
    var stack: usize = 0;
    var cstack: usize = 0;

    while (true) {
        var inst = rnd.random().int(u8) % 34;
        while (INSTRUCTION_TYPES[inst].stack_in > stack or (cstack == 0 and INSTRUCTION_TYPES[inst].cstack[1])) {
            inst = rnd.random().int(u8) % 34;
        }

        stack -= INSTRUCTION_TYPES[inst].stack_in;

        var dataType = rnd.random().int(u8) % 3;

        while (!INSTRUCTION_TYPES[inst].params[dataType]) {
            dataType = rnd.random().int(u8) % 3;
        }

        if (INSTRUCTION_TYPES[inst].cstack[0])
            cstack += 1;

        if (INSTRUCTION_TYPES[inst].cstack[1])
            cstack -= 1;

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

        stack += INSTRUCTION_TYPES[inst].stack_out;
    }

    try result.appendSlice(buffer[0..idx]);

    return result;
}
