const std = @import("std");

const Operation = @import("sandeee_operation");

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();

    _ = args.next();

    const mode = args.next() orelse return error.MissingMode;
    const input_file = args.next() orelse return error.MissingInputFile;

    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();

    const alloc = arena.allocator();
    const output_file = args.next() orelse return error.MissingOutputFile;

    if (std.mem.eql(u8, mode, "exe")) {
        try compileExecutable(alloc, init.io, input_file, output_file);
    } else if (std.mem.eql(u8, mode, "lib")) {
        try compile_library(alloc, init.io, input_file, output_file);
    } else return error.BadBuildMode;
}

pub fn addNumber(list: *std.array_list.Managed(u8), number: u64) !void {
    if (number > 255) {
        try list.print("\x01{s}", .{&std.mem.toBytes(number)});
    } else {
        try list.print("\x03{s}", .{&std.mem.toBytes(@as(u8, @intCast(number)))});
    }
}

pub fn addString(list: *std.array_list.Managed(u8), allocator: std.mem.Allocator, string: []const u8) !void {
    if (string.len <= 2) {
        try list.appendSlice("\x02\x00");
    } else {
        const target_tmp = try std.zig.string_literal.parseAlloc(allocator, string);
        defer allocator.free(target_tmp);

        try list.print("\x02{s}\x00", .{target_tmp});
    }
}

pub fn binFromLine(
    allocator: std.mem.Allocator,
    consts: *std.StringHashMap(u64),
    funcs: *std.array_list.Managed([]const u8),
    line: []const u8,
) ![]const u8 {
    var result: std.array_list.Managed(u8) = .init(allocator);
    defer result.deinit();

    var no_comment = std.mem.splitScalar(u8, line, ';');
    var l = no_comment.first();
    if (l.len == 0) return "";
    while (l.len != 0 and l[0] == ' ') l = l[1..];
    while (l[l.len - 1] == ' ') l = l[0 .. l.len - 1];
    if (l.len == 0 or l[l.len - 1] == ':')
        return "";

    var op = l;
    if (std.mem.indexOf(u8, l, " ") != null)
        op = l[0..std.mem.indexOf(u8, l, " ").?];

    var code: ?Operation.Code = null;

    if (std.mem.eql(u8, op, "nop")) code = .nop;
    if (std.mem.eql(u8, op, "sys")) code = .sys;
    if (std.mem.eql(u8, op, "push")) code = .push;
    if (std.mem.eql(u8, op, "add")) code = .add;
    if (std.mem.eql(u8, op, "sub")) code = .sub;
    if (std.mem.eql(u8, op, "copy")) code = .copy;
    if (std.mem.eql(u8, op, "jmp")) code = .jmp;
    if (std.mem.eql(u8, op, "jz")) code = .jz;
    if (std.mem.eql(u8, op, "jnz")) code = .jnz;
    if (std.mem.eql(u8, op, "jmpf")) code = .jmpf;
    if (std.mem.eql(u8, op, "mul")) code = .mul;
    if (std.mem.eql(u8, op, "div")) code = .div;
    if (std.mem.eql(u8, op, "and")) code = .land;
    if (std.mem.eql(u8, op, "or")) code = .lor;
    if (std.mem.eql(u8, op, "not")) code = .lnot;
    if (std.mem.eql(u8, op, "eq")) code = .eq;
    if (std.mem.eql(u8, op, "getb")) code = .getb;
    if (std.mem.eql(u8, op, "ret")) code = .ret;
    if (std.mem.eql(u8, op, "call")) code = .call;
    if (std.mem.eql(u8, op, "neg")) code = .neg;
    if (std.mem.eql(u8, op, "xor")) code = .xor;
    if (std.mem.eql(u8, op, "disc")) code = .disc;
    if (std.mem.eql(u8, op, "set")) code = .asign;
    if (std.mem.eql(u8, op, "dup")) code = .dup;
    if (std.mem.eql(u8, op, "lt")) code = .less;
    if (std.mem.eql(u8, op, "gt")) code = .greater;
    if (std.mem.eql(u8, op, "cat")) code = .cat;
    if (std.mem.eql(u8, op, "mod")) code = .mod;
    if (std.mem.eql(u8, op, "create")) code = .create;
    if (std.mem.eql(u8, op, "size")) code = .size;
    if (std.mem.eql(u8, op, "len")) code = .len;
    if (std.mem.eql(u8, op, "sin")) code = .sin;
    if (std.mem.eql(u8, op, "cos")) code = .cos;
    if (std.mem.eql(u8, op, "rand")) code = .random;
    if (std.mem.eql(u8, op, "seed")) code = .seed;
    if (std.mem.eql(u8, op, "zero")) code = .zero;
    if (std.mem.eql(u8, op, "mem")) code = .mem;
    if (std.mem.eql(u8, op, "ndisc")) code = .disc_at;

    if (code == null) {
        std.log.info("{s}", .{op});
        return error.UnknownOp;
    }
    try result.appendSlice(&.{@as(u8, @backingInt(code.?))});

    if (std.mem.eql(u8, op, l)) {
        try result.appendSlice("\x00");
    } else if (std.fmt.parseUnsigned(u64, l[op.len + 1 ..], 0)) |int| {
        try addNumber(&result, int);
    } else |_| {
        var target = l[op.len + 1 ..];
        while (target[0] == ' ') target = target[1..];
        while (target[target.len - 1] == ' ') target = target[0 .. target.len - 1];
        if (target[0] == '"' and target[target.len - 1] == '"') {
            try addString(&result, allocator, target);
        } else {
            if (consts.contains(target)) {
                const value = consts.get(target).?;
                try addNumber(&result, value);
            } else for (funcs.items) |func| {
                if (std.mem.eql(u8, func, target)) {
                    try result.print("\x02{s}\x00", .{target});
                    break;
                }
            } else {
                std.log.info("{s}", .{target});
                return error.UnknownConst;
            }
        }
    }

    return result.toOwnedSlice();
}

pub fn compileExecutable(allocator: std.mem.Allocator, io: std.Io, input_file: []const u8, output_file: []const u8) !void {
    var consts = std.StringHashMap(u64).init(allocator);

    {
        var inreader = try std.Io.Dir.cwd().openFile(io, input_file, .{});
        defer inreader.close(io);

        var reader_buffer: [1024]u8 = undefined;
        var reader_stream = inreader.reader(io, &reader_buffer);

        var idx: u64 = 0;

        while (try reader_stream.interface.takeDelimiter('\n')) |in_line| {
            const line = std.mem.trim(u8, in_line, &std.ascii.whitespace);

            var no_comment = std.mem.splitScalar(u8, line, ';');
            var l = no_comment.first();
            if (l.len == 0) continue;
            while (l.len != 0 and l[0] == ' ') l = l[1..];
            while (l[l.len - 1] == ' ') l = l[0 .. l.len - 1];
            if (l.len == 0) {
                continue;
            }
            if (l[l.len - 1] == ':') {
                const key = try allocator.dupe(u8, l[0 .. l.len - 1]);

                try consts.put(key, idx);
            } else {
                idx += 1;
            }
        }
    }

    const file = try std.Io.Dir.cwd().createFile(io, output_file, .{});
    defer file.close(io);

    var writer_buffer: [1024]u8 = undefined;
    var writer = file.writer(io, &writer_buffer);
    defer writer.flush() catch {};

    const in_file = try std.Io.Dir.cwd().openFile(io, input_file, .{});
    defer in_file.close(io);

    var reader_buffer: [1024]u8 = undefined;
    var reader_stream = in_file.reader(io, &reader_buffer);

    try writer.interface.writeAll("EEEp");

    var funcs = std.array_list.Managed([]const u8).init(allocator);

    while (try reader_stream.interface.takeDelimiter('\n')) |in_line| {
        const line = std.mem.trim(u8, in_line, &std.ascii.whitespace);
        const bin = try binFromLine(allocator, &consts, &funcs, line);
        defer allocator.free(bin);

        try writer.interface.writeAll(bin);
    }
}

pub fn compile_library(allocator: std.mem.Allocator, io: std.Io, input_file: []const u8, output_file: []const u8) !void {
    var toc = std.array_list.Managed(u8).init(allocator);
    var data = std.array_list.Managed(u8).init(allocator);
    var funcs = std.array_list.Managed([]const u8).init(allocator);

    var consts = std.StringHashMap(u64).init(allocator);

    var toc_count: u8 = 0;

    {
        var inreader = try std.Io.Dir.cwd().openFile(io, input_file, .{});
        defer inreader.close(io);

        var reader_buffer: [1024]u8 = undefined;
        var reader_stream = inreader.reader(io, &reader_buffer);

        var idx: u64 = 0;

        while (try reader_stream.interface.takeDelimiter('\n')) |in_line| {
            const line = std.mem.trim(u8, in_line, &std.ascii.whitespace);

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
                    const key = try allocator.dupe(u8, l[1 .. l.len - 1]);
                    try funcs.append(key);
                }

                const key = try allocator.dupe(u8, l[0 .. l.len - 1]);

                try consts.put(key, idx);
            } else {
                idx += 1;
            }
        }
    }

    var file = try std.Io.Dir.cwd().createFile(io, output_file, .{});
    defer file.close(io);

    var writer_buffer: [1024]u8 = undefined;
    var writer = file.writer(io, &writer_buffer);
    defer writer.flush() catch {};

    try toc.append(@as(u8, @intCast(toc_count)));

    var reader_buffer: [1024]u8 = undefined;
    const inreader = try std.Io.Dir.cwd().openFile(io, input_file, .{});
    defer inreader.close(io);

    var reader_stream = inreader.reader(io, &reader_buffer);
    var prev_toc: usize = 0;

    try writer.interface.writeAll("elib");

    while (try reader_stream.interface.takeDelimiter('\n')) |in_line| {
        const line = std.mem.trim(u8, in_line, &std.ascii.whitespace);
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

        const bin = try binFromLine(allocator, &consts, &funcs, line);
        defer allocator.free(bin);

        try data.appendSlice(bin);
    }
    const len = data.items.len - prev_toc + 1;
    try toc.append(@as(u8, @intCast(len / 256)));
    try toc.append(@as(u8, @intCast(len % 256)));

    try writer.interface.writeAll(&.{
        @as(u8, @intCast((toc.items.len + 6) / 256)),
        @as(u8, @intCast((toc.items.len + 6) % 256)),
    });
    try writer.interface.writeAll(toc.items);
    try writer.interface.writeAll(data.items);
}
