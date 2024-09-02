const std = @import("std");
const vm = @import("../src/system/vm.zig");

pub fn compile(b: *std.Build, paths: []const std.Build.LazyPath) !std.ArrayList(u8) {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    var inreader = try std.fs.cwd().openFile(in.getPath3(b, null).sub_path, .{});
    defer inreader.close();
    try inreader.sync();

    var result = std.ArrayList(u8).init(b.allocator);

    var buf_reader = std.io.bufferedReader(inreader.reader());
    var reader_stream = buf_reader.reader();

    var consts = std.StringHashMap(u64).init(b.allocator);
    var idx: u64 = 0;

    var buf: [1024]u8 = undefined;

    while (try reader_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var no_comment = std.mem.splitScalar(u8, line, ';');
        var l = no_comment.first();
        if (l.len == 0) continue;
        while (l.len != 0 and l[0] == ' ') l = l[1..];
        while (l[l.len - 1] == ' ') l = l[0 .. l.len - 1];
        if (l.len == 0) {
            continue;
        }
        if (l[l.len - 1] == ':') {
            const key = try std.fmt.allocPrint(b.allocator, "{s}", .{l[0 .. l.len - 1]});

            try consts.put(key, idx);
        } else {
            idx += 1;
        }
    }

    inreader.close();
    inreader = try std.fs.cwd().openFile(in.getPath3(b, null).sub_path, .{});
    try inreader.sync();

    buf_reader = std.io.bufferedReader(inreader.reader());
    reader_stream = buf_reader.reader();

    try result.appendSlice("EEEp");

    while (try reader_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var no_comment = std.mem.splitScalar(u8, line, ';');
        var l = no_comment.first();
        if (l.len == 0) continue;
        while (l.len != 0 and l[0] == ' ') l = l[1..];
        while (l[l.len - 1] == ' ') l = l[0 .. l.len - 1];
        if (l.len == 0 or l[l.len - 1] == ':') {
            continue;
        }

        var op = l;
        if (std.mem.indexOf(u8, l, " ") != null) {
            op = l[0..std.mem.indexOf(u8, l, " ").?];
        }
        var code: vm.VM.Operation.Code = .Last;

        if (std.mem.eql(u8, op, "nop")) code = .Nop;
        if (std.mem.eql(u8, op, "sys")) code = .Sys;
        if (std.mem.eql(u8, op, "push")) code = .Push;
        if (std.mem.eql(u8, op, "add")) code = .Add;
        if (std.mem.eql(u8, op, "sub")) code = .Sub;
        if (std.mem.eql(u8, op, "copy")) code = .Copy;
        if (std.mem.eql(u8, op, "jmp")) code = .Jmp;
        if (std.mem.eql(u8, op, "jz")) code = .Jz;
        if (std.mem.eql(u8, op, "jnz")) code = .Jnz;
        if (std.mem.eql(u8, op, "jmpf")) code = .Jmpf;
        if (std.mem.eql(u8, op, "mul")) code = .Mul;
        if (std.mem.eql(u8, op, "div")) code = .Div;
        if (std.mem.eql(u8, op, "and")) code = .And;
        if (std.mem.eql(u8, op, "or")) code = .Or;
        if (std.mem.eql(u8, op, "not")) code = .Not;
        if (std.mem.eql(u8, op, "eq")) code = .Eq;
        if (std.mem.eql(u8, op, "getb")) code = .Getb;
        if (std.mem.eql(u8, op, "ret")) code = .Ret;
        if (std.mem.eql(u8, op, "call")) code = .Call;
        if (std.mem.eql(u8, op, "neg")) code = .Neg;
        if (std.mem.eql(u8, op, "xor")) code = .Xor;
        if (std.mem.eql(u8, op, "disc")) code = .Disc;
        if (std.mem.eql(u8, op, "set")) code = .Asign;
        if (std.mem.eql(u8, op, "dup")) code = .Dup;
        if (std.mem.eql(u8, op, "lt")) code = .Less;
        if (std.mem.eql(u8, op, "gt")) code = .Greater;
        if (std.mem.eql(u8, op, "cat")) code = .Cat;
        if (std.mem.eql(u8, op, "mod")) code = .Mod;
        if (std.mem.eql(u8, op, "create")) code = .Create;
        if (std.mem.eql(u8, op, "size")) code = .Size;
        if (std.mem.eql(u8, op, "len")) code = .Len;
        if (std.mem.eql(u8, op, "sin")) code = .Sin;
        if (std.mem.eql(u8, op, "cos")) code = .Cos;
        if (std.mem.eql(u8, op, "rand")) code = .Random;
        if (std.mem.eql(u8, op, "seed")) code = .Seed;
        if (std.mem.eql(u8, op, "zero")) code = .Zero;
        if (std.mem.eql(u8, op, "mem")) code = .Mem;
        if (std.mem.eql(u8, op, "ndisc")) code = .DiscN;

        if (code == .Last) {
            std.log.info("{s}", .{op});
            return error.UnknownOp;
        }
        try result.append(@as(u8, @intFromEnum(code)));

        if (std.mem.eql(u8, op, l)) {
            try result.appendSlice("\x00");
        } else {
            const int: u64 = std.fmt.parseUnsigned(u64, l[op.len + 1 ..], 0) catch {
                var target = l[op.len + 1 ..];
                while (target[0] == ' ') target = target[1..];
                while (target[target.len - 1] == ' ') target = target[0 .. target.len - 1];
                if (target[0] == '"' and target[target.len - 1] == '"') {
                    if (target.len <= 2) {
                        try result.appendSlice("\x02");
                        try result.appendSlice("\x00");
                    } else {
                        const target_tmp = try std.zig.string_literal.parseAlloc(b.allocator, target);

                        try result.appendSlice("\x02");
                        try result.appendSlice(target_tmp);
                        try result.appendSlice("\x00");
                    }
                } else {
                    if (!consts.contains(target)) {
                        std.log.info("{s}", .{target});
                        return error.UnknownConst;
                    } else {
                        const value = consts.get(target).?;
                        if (value > 255) {
                            try result.appendSlice("\x01");
                            try result.appendSlice(&std.mem.toBytes(value));
                        } else {
                            try result.appendSlice("\x03");
                            try result.appendSlice(&std.mem.toBytes(@as(u8, @intCast(value))));
                        }
                    }
                }

                continue;
            };
            if (int > 255) {
                try result.appendSlice("\x01");
                try result.appendSlice(&std.mem.toBytes(int));
            } else {
                try result.appendSlice("\x03");
                try result.appendSlice(&std.mem.toBytes(@as(u8, @intCast(int))));
            }
        }
    }

    return result;
}

pub fn compileLib(b: *std.Build, paths: []const std.Build.LazyPath) !std.ArrayList(u8) {
    if (paths.len != 1) return error.BadPaths;
    const in = paths[0];

    var inreader = try std.fs.cwd().openFile(in.getPath3(b, null).sub_path, .{});
    defer inreader.close();
    try inreader.sync();

    var result = std.ArrayList(u8).init(b.allocator);
    var toc = std.ArrayList(u8).init(b.allocator);
    var data = std.ArrayList(u8).init(b.allocator);
    var funcs = std.ArrayList([]const u8).init(b.allocator);

    var buf_reader = std.io.bufferedReader(inreader.reader());
    var reader_stream = buf_reader.reader();

    var consts = std.StringHashMap(u64).init(b.allocator);
    var idx: u64 = 0;
    var toc_count: u8 = 0;

    var buf: [1024]u8 = undefined;

    while (try reader_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var no_comment = std.mem.splitScalar(u8, line, ';');
        var l = no_comment.first();
        if (l.len == 0) continue;
        while (l.len != 0 and l[0] == ' ') l = l[1..];
        while (l[l.len - 1] == ' ') l = l[0 .. l.len - 1];
        if (l.len == 0) {
            continue;
        }
        if (l[l.len - 1] == ':') {
            if (l[0] == '_') {
                idx = 0;
                toc_count += 1;
                const key = try std.fmt.allocPrint(b.allocator, "{s}", .{l[1 .. l.len - 1]});
                try funcs.append(key);
            }

            const key = try std.fmt.allocPrint(b.allocator, "{s}", .{l[0 .. l.len - 1]});

            try consts.put(key, idx);
        } else {
            idx += 1;
        }
    }

    try toc.append(@as(u8, @intCast(toc_count)));

    inreader.close();
    inreader = try std.fs.cwd().openFile(in.getPath3(b, null).sub_path, .{});
    try inreader.sync();

    buf_reader = std.io.bufferedReader(inreader.reader());
    reader_stream = buf_reader.reader();
    var prev_toc: usize = 0;

    try result.appendSlice("elib");

    while (try reader_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var no_comment = std.mem.splitScalar(u8, line, ';');
        var l = no_comment.first();
        if (l.len == 0) continue;
        while (l.len != 0 and l[0] == ' ') l = l[1..];
        while (l[l.len - 1] == ' ') l = l[0 .. l.len - 1];
        if (l.len == 0 or l[l.len - 1] == ':') {
            if (l.len != 0) {
                if (l[0] == '_') {
                    if (prev_toc != 0) {
                        const len = data.items.len - prev_toc + 1;
                        try toc.append(@as(u8, @intCast(len / 256)));
                        try toc.append(@as(u8, @intCast(len % 256)));
                    }
                    try toc.append(@as(u8, @intCast(l.len - 2)));
                    try toc.appendSlice(l[1 .. l.len - 1]);
                    try toc.append(0);
                    prev_toc = data.items.len + 1;
                }
            }
            continue;
        }

        var op = l;
        if (std.mem.indexOf(u8, l, " ") != null) {
            op = l[0..std.mem.indexOf(u8, l, " ").?];
        }
        var code: vm.VM.Operation.Code = .Last;

        if (std.mem.eql(u8, op, "nop")) code = .Nop;
        if (std.mem.eql(u8, op, "sys")) code = .Sys;
        if (std.mem.eql(u8, op, "push")) code = .Push;
        if (std.mem.eql(u8, op, "add")) code = .Add;
        if (std.mem.eql(u8, op, "sub")) code = .Sub;
        if (std.mem.eql(u8, op, "copy")) code = .Copy;
        if (std.mem.eql(u8, op, "jmp")) code = .Jmp;
        if (std.mem.eql(u8, op, "jz")) code = .Jz;
        if (std.mem.eql(u8, op, "jnz")) code = .Jnz;
        if (std.mem.eql(u8, op, "jmpf")) code = .Jmpf;
        if (std.mem.eql(u8, op, "mul")) code = .Mul;
        if (std.mem.eql(u8, op, "div")) code = .Div;
        if (std.mem.eql(u8, op, "and")) code = .And;
        if (std.mem.eql(u8, op, "or")) code = .Or;
        if (std.mem.eql(u8, op, "not")) code = .Not;
        if (std.mem.eql(u8, op, "eq")) code = .Eq;
        if (std.mem.eql(u8, op, "getb")) code = .Getb;
        if (std.mem.eql(u8, op, "ret")) code = .Ret;
        if (std.mem.eql(u8, op, "call")) code = .Call;
        if (std.mem.eql(u8, op, "neg")) code = .Neg;
        if (std.mem.eql(u8, op, "xor")) code = .Xor;
        if (std.mem.eql(u8, op, "disc")) code = .Disc;
        if (std.mem.eql(u8, op, "set")) code = .Asign;
        if (std.mem.eql(u8, op, "dup")) code = .Dup;
        if (std.mem.eql(u8, op, "lt")) code = .Less;
        if (std.mem.eql(u8, op, "gt")) code = .Greater;
        if (std.mem.eql(u8, op, "cat")) code = .Cat;
        if (std.mem.eql(u8, op, "mod")) code = .Mod;
        if (std.mem.eql(u8, op, "create")) code = .Create;
        if (std.mem.eql(u8, op, "size")) code = .Size;
        if (std.mem.eql(u8, op, "len")) code = .Len;
        if (std.mem.eql(u8, op, "sin")) code = .Sin;
        if (std.mem.eql(u8, op, "cos")) code = .Cos;
        if (std.mem.eql(u8, op, "rand")) code = .Random;
        if (std.mem.eql(u8, op, "seed")) code = .Seed;
        if (std.mem.eql(u8, op, "zero")) code = .Zero;
        if (std.mem.eql(u8, op, "mem")) code = .Mem;
        if (std.mem.eql(u8, op, "ndisc")) code = .DiscN;

        if (code == .Last) {
            std.log.info("{s}", .{op});
            return error.UnknownOp;
        }
        try data.append(@as(u8, @intFromEnum(code)));

        if (std.mem.eql(u8, op, l)) {
            try data.appendSlice("\x00");
        } else {
            const int: u64 = std.fmt.parseUnsigned(u64, l[op.len + 1 ..], 0) catch {
                var target = l[op.len + 1 ..];
                while (target[0] == ' ') target = target[1..];
                while (target[target.len - 1] == ' ') target = target[0 .. target.len - 1];
                if (target[0] == '"' and target[target.len - 1] == '"') {
                    const target_tmp = try std.zig.string_literal.parseAlloc(b.allocator, target);

                    try data.appendSlice("\x02");
                    try data.appendSlice(target_tmp);
                    try data.appendSlice("\x00");
                } else {
                    if (!consts.contains(target)) {
                        var good = false;
                        for (funcs.items) |item| {
                            if (std.mem.eql(u8, item, target)) {
                                try data.appendSlice("\x02");
                                try data.appendSlice(target);
                                try data.appendSlice("\x00");
                                good = true;
                                break;
                            }
                        }
                        if (!good) {
                            std.log.info("{s}", .{target});
                            return error.UnknownConst;
                        }
                    } else {
                        const value = consts.get(target).?;
                        if (value > 255) {
                            try data.appendSlice("\x01");
                            try data.appendSlice(&std.mem.toBytes(value));
                        } else {
                            try data.appendSlice("\x03");
                            try data.appendSlice(&std.mem.toBytes(@as(u8, @intCast(value))));
                        }
                    }
                }

                continue;
            };
            if (int > 255) {
                try data.appendSlice("\x01");
                try data.appendSlice(&std.mem.toBytes(int));
            } else {
                try data.appendSlice("\x03");
                try data.appendSlice(&std.mem.toBytes(@as(u8, @intCast(int))));
            }
        }
    }
    const len = data.items.len - prev_toc + 1;
    try toc.append(@as(u8, @intCast(len / 256)));
    try toc.append(@as(u8, @intCast(len % 256)));

    try result.append(@as(u8, @intCast((toc.items.len + 6) / 256)));
    try result.append(@as(u8, @intCast((toc.items.len + 6) % 256)));
    try result.appendSlice(toc.items);
    try result.appendSlice(data.items);

    return result;
}
