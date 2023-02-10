const std = @import("std");

const lol = error {
    UnknownOp,
};

pub fn compile(in: []const u8, out: []const u8, alloc: std.mem.Allocator) !void {
    var inreader = try std.fs.cwd().openFile(in, .{});
    defer inreader.close();
    var result = std.ArrayList(u8).init(alloc);
    defer result.deinit();

    var buf_reader = std.io.bufferedReader(inreader.reader());
    var reader_stream = buf_reader.reader();

    var consts = std.StringHashMap(u64).init(alloc);
    var idx: u64 = 0;

    var buf: [1024]u8 = undefined;

    while (try reader_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var lo = std.mem.split(u8, line, ";");
        var l = lo.first();
        while (l[0] == ' ') l = l[1..];
        while (l[l.len - 1] == ' ') l = l[0..l.len - 1];
        if (l.len == 0) {
            continue;
        }
        if (l[l.len - 1] == ':') {
            try consts.put(l[0 .. l.len - 2], idx);
        } else {
            idx += 1;
        }
    }

    inreader.close();
    inreader = try std.fs.cwd().openFile(in, .{});
    buf_reader = std.io.bufferedReader(inreader.reader());
    reader_stream = buf_reader.reader();

    try result.appendSlice("EEEp");

    while (try reader_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var lo = std.mem.split(u8, line, ";");
        var l = lo.first();
        while (l[0] == ' ') l = l[1..];
        while (l[l.len - 1] == ' ') l = l[0..l.len - 1];
        if (l.len == 0 or l[l.len - 1] == ':') {
            continue;
        }

        var op = l;
        if (std.mem.indexOf(u8, l, " ") != null) {
            op = l[0..std.mem.indexOf(u8, l, " ").?];
        }
        var code: u8 = 255;

        if (std.mem.eql(u8, op, "nop")) code = 0;
        if (std.mem.eql(u8, op, "sys")) code = 1;
        if (std.mem.eql(u8, op, "push")) code = 2;
        if (std.mem.eql(u8, op, "add")) code = 3;
        if (std.mem.eql(u8, op, "sub")) code = 4;
        if (std.mem.eql(u8, op, "copy")) code = 5;
        if (std.mem.eql(u8, op, "jmp")) code = 6;
        if (std.mem.eql(u8, op, "jz")) code = 7;
        if (std.mem.eql(u8, op, "jnz")) code = 8;
        if (std.mem.eql(u8, op, "jmpf")) code = 9;
        if (std.mem.eql(u8, op, "mul")) code = 10;
        if (std.mem.eql(u8, op, "div")) code = 11;
        if (std.mem.eql(u8, op, "and")) code = 12;
        if (std.mem.eql(u8, op, "or")) code = 13;
        if (std.mem.eql(u8, op, "not")) code = 14;
        if (std.mem.eql(u8, op, "eq")) code = 15;
        if (std.mem.eql(u8, op, "getb")) code = 16;
        if (std.mem.eql(u8, op, "ret")) code = 17;
        if (std.mem.eql(u8, op, "call")) code = 18;
        if (std.mem.eql(u8, op, "neg")) code = 19;
        if (std.mem.eql(u8, op, "xor")) code = 20;
        if (std.mem.eql(u8, op, "disc")) code = 21;
        if (std.mem.eql(u8, op, "set")) code = 22;
        if (std.mem.eql(u8, op, "dup")) code = 23;
        if (std.mem.eql(u8, op, "lt")) code = 24;
        if (std.mem.eql(u8, op, "gt")) code = 25;

        if (code == 255) {
            return error.UnknownOp;
        }
        try result.appendSlice(&std.mem.toBytes(code));

        if (std.mem.eql(u8, op, l)) {
            try result.appendSlice("\x00");
        } else {
            var int: u64 = std.fmt.parseUnsigned(u64, l[op.len + 1..], 0) catch {
                var target = l[op.len + 1..];
                if (target[0] == '"' and target[target.len - 1] == '"') {
                    var target_tmp = try alloc.alloc(u8, std.mem.replacementSize(u8, target[1..target.len - 1], "\\n", "\n"));
                    _ = std.mem.replace(u8, target[1..target.len - 1], "\\n", "\n", target_tmp);

                    try result.appendSlice("\x02");
                    try result.appendSlice(target_tmp);
                    try result.appendSlice("\x00");
                } else {
                    return error.UnknownOp;
                }

                continue;
            };
            if (int > 255) {
                try result.appendSlice("\x01");
                try result.appendSlice(&std.mem.toBytes(int));
            } else {
                try result.appendSlice("\x03");
                try result.appendSlice(&std.mem.toBytes(@intCast(u8, int)));
            }
        }
    }

    try std.fs.cwd().writeFile(out, result.items);
}
