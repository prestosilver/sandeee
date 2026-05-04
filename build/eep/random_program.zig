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
    .{ .stack_out = 1, .stack_in = 3, .params = .{ false, true, false } }, // sys
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

pub var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 10 }){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();

    const mode = args.next() orelse return error.MissingMode;
    const output_file_path = args.next() orelse return error.MissingOutputFile;

    if (std.mem.eql(u8, mode, "--script")) {
        const count_value = args.next() orelse return error.MissingOutputFile;
        const count = try std.fmt.parseInt(usize, count_value, 10);

        return genScript(output_file_path, count);
    } else if (std.mem.eql(u8, mode, "--rand")) {
        return genFile(output_file_path);
    } else return error.InvalidMode;
}

pub fn genFile(output: []const u8) !void {
    const output_file = try std.fs.createFileAbsolute(output, .{});
    defer output_file.close();

    var writer = output_file.writer(&.{});

    try writer.interface.writeAll("EEEp");

    var buffer: [1020]u8 = undefined;

    var idx: usize = 0;
    var rnd = std.Random.DefaultPrng.init(@intCast(std.time.microTimestamp()));
    var stack: usize = 0;
    var cstack: usize = 0;

    while (true) {
        var inst = rnd.random().int(u8) % 34;
        while (INSTRUCTION_TYPES[inst].stack_in > stack or (cstack == 0 and INSTRUCTION_TYPES[inst].cstack[1])) {
            inst = rnd.random().int(u8) % 34;
        }

        stack -= INSTRUCTION_TYPES[inst].stack_in;

        var data_type = rnd.random().int(u8) % 3;

        while (!INSTRUCTION_TYPES[inst].params[data_type]) {
            data_type = rnd.random().int(u8) % 3;
        }

        if (INSTRUCTION_TYPES[inst].cstack[0])
            cstack += 1;

        if (INSTRUCTION_TYPES[inst].cstack[1])
            cstack -= 1;

        switch (data_type) {
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

    try writer.interface.writeAll(buffer[0..idx]);
}

pub fn genScript(output: []const u8, count: usize) !void {
    const output_file = try std.fs.createFileAbsolute(output, .{});
    defer output_file.close();

    var writer = output_file.writer(&.{});

    for (0..count) |idx| {
        const text = try std.fmt.allocPrint(allocator, "{}.eep\n", .{idx});
        defer allocator.free(text);

        try writer.interface.writeAll(text);
    }
}
