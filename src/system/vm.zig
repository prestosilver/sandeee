const std = @import("std");
const streams = @import("stream.zig");
const files = @import("files.zig");
//const shell = @import("shell.zig");

const STACK_MAX = 2048;

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub const VM = struct {
    const VMError = error{
        StackUnderflow,
        ValueMissing,
        StringMissing,
        InvalidOp,
        InvalidSys,
        NotImplemented,
        UnknownFunction,
    };

    const StackEntryKind = enum {
        string,
        value,
    };

    pub const StackEntry = union(StackEntryKind) {
        string: *[]u8,
        value: *u64,
    };

    pub const RetStackEntry = struct {
        function: ?[]const u8,
        location: u64,
    };

    pub const VMFunc = struct {
        string: []const u8,
        ops: []Operation,
    };

    allocator: std.mem.Allocator,
    stack: [STACK_MAX]StackEntry,
    rsp: usize = 0,

    functions: std.StringHashMap(VMFunc),
    inside_fn: ?[]const u8 = null,

    retStack: [256]RetStackEntry = undefined,
    retRsp: u8 = 0,

    pc: usize = 0,
    code: ?[]const Operation = null,
    stopped: bool = false,
    yield: bool = false,
    miscData: std.StringHashMap([]const u8),
    input: std.ArrayList(u8),

    streams: std.ArrayList(?*streams.FileStream),

    out: std.ArrayList(u8) = undefined,
    args: [][]u8,
    root: *files.Folder,
    heap: []u8,

    checker: bool = false,

    pub fn init(alloc: std.mem.Allocator, root: *files.Folder, args: []const u8, comptime checker: bool) !VM {
        var splitIter = std.mem.split(u8, args, " ");

        var tmpArgs = try alloc.alloc([]u8, std.mem.count(u8, args, " ") + 1);

        var idx: usize = 0;
        while (splitIter.next()) |item| {
            tmpArgs[idx] = try alloc.alloc(u8, item.len);
            std.mem.copy(u8, tmpArgs[idx], item);
            idx += 1;
        }

        return VM{
            .stack = undefined,
            .allocator = alloc,
            .streams = std.ArrayList(?*streams.FileStream).init(alloc),
            .functions = std.StringHashMap(VMFunc).init(alloc),
            .miscData = std.StringHashMap([]const u8).init(alloc),
            .out = std.ArrayList(u8).init(alloc),
            .input = std.ArrayList(u8).init(alloc),
            .heap = try alloc.alloc(u8, 0),
            .args = tmpArgs,
            .root = root,
            .checker = checker,
        };
    }

    inline fn pushStack(self: *VM, entry: StackEntry) !void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        self.stack[self.rsp] = entry;
        self.rsp += 1;
    }

    inline fn pushStackI(self: *VM, value: u64) !void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        var val = try self.allocator.create(u64);
        val.* = value;

        self.stack[self.rsp] = StackEntry{ .value = val };
        self.rsp += 1;
    }

    inline fn pushStackS(self: *VM, string: []const u8) !void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        var appendString = try self.allocator.create([]u8);

        appendString.* = try self.allocator.dupe(u8, string);

        self.stack[self.rsp] = StackEntry{ .string = appendString };
        self.rsp += 1;
    }

    inline fn popStack(self: *VM) VMError!StackEntry {
        if (self.rsp == 0) return error.StackUnderflow;
        self.rsp -= 1;
        return self.stack[self.rsp];
    }

    inline fn findStack(self: *VM, idx: u64) VMError!StackEntry {
        if (self.rsp <= idx) return error.StackUnderflow;
        return self.stack[self.rsp - 1 - @intCast(usize, idx)];
    }

    fn replaceStack(self: *VM, a: StackEntry, b: StackEntry) !void {
        for (self.stack[0..self.rsp]) |*entry| {
            if ((a == .string and entry.* == .string and entry.string == a.string) or
                (a == .value and entry.* == .value and entry.value == a.value))
            {
                entry.* = b;
            }
        }
    }

    pub const Operation = struct {
        pub const Code = enum(u8) {
            Nop,
            Sys,

            Push,
            Add,
            Sub,
            Copy,

            Jmp,
            Jz,
            Jnz,
            Jmpf,

            Mul,
            Div,

            And,
            Or,
            Not,
            Eq,

            Getb,

            Ret,
            Call,

            Neg,
            Xor,
            Disc,
            Asign,
            Dup,

            Less,
            Greater,

            Cat,
            Mod,
            Create,
            Size,
            Len,

            Sin,
            Cos,

            Last,
            _,
        };

        code: Code,
        string: ?[]const u8 = null,
        value: ?u64 = null,

        pub fn format(
            self: Operation,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;
            if (self.string != null) {
                return std.fmt.format(writer, "{s} \"{s}\"", .{ @tagName(self.code), self.string.? });
            } else if (self.value != null) {
                return std.fmt.format(writer, "{s} {}", .{ @tagName(self.code), self.value.? });
            } else {
                return std.fmt.format(writer, "{s}", .{@tagName(self.code)});
            }
        }
    };

    pub fn deinit(self: *VM) !void {
        // var iter = cnts.iterator();

        // while (iter.next()) |entry| {
        //     std.log.debug("op: {}, calls: {} time: {}", .{ entry.key, entry.value.*, times.get(entry.key) });
        // }

        // std.log.debug("=======", .{});

        var oldrsp = self.rsp;
        self.rsp = 0;

        self.free(self.stack[0..oldrsp]);

        if (self.code) |code| {
            for (code) |entry| {
                if (entry.string) |str| {
                    self.allocator.free(str);
                }
            }
            self.allocator.free(code);
        }

        var iter = self.functions.iterator();

        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.ops);
            self.allocator.free(entry.value_ptr.string);
        }

        for (self.streams.items) |stream| {
            if (stream != null)
                try stream.?.Close();
        }

        for (self.args, 0..) |_, idx| {
            self.allocator.free(self.args[idx]);
        }

        var miscIter = self.miscData.iterator();

        while (miscIter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }

        self.allocator.free(self.args);
        self.allocator.free(self.heap);
        self.functions.deinit();
        self.miscData.deinit();
        self.streams.deinit();
        self.out.deinit();
    }

    pub fn freeValue(self: *VM, val: *u64) void {
        if (self.rsp != 0) {
            for (self.stack[0..self.rsp]) |entry| {
                if (entry == .value and entry.value == val) {
                    return;
                }
            }
        }
        self.allocator.destroy(val);
    }

    pub fn freeString(self: *VM, val: *[]const u8) void {
        if (self.rsp != 0) {
            for (self.stack[0..self.rsp]) |entry| {
                if (entry == .string and entry.string == val) {
                    return;
                }
            }
        }
        self.allocator.free(val.*);
        self.allocator.destroy(val);
    }

    pub fn free(self: *VM, vals: []StackEntry) void {
        var toFree = std.ArrayList(StackEntry).init(self.allocator);
        defer toFree.deinit();

        for (vals) |val| {
            var add = true;
            for (toFree.items) |item| {
                if ((val == .string and item == .string and item.string == val.string) or
                    (val == .value and item == .value and item.value == val.value))
                {
                    add = false;
                    break;
                }
            }
            if (add) {
                toFree.append(val) catch {};
            }
        }

        for (toFree.items) |val| {
            if (val == .value) self.freeValue(val.value);
            if (val == .string) self.freeString(val.string);
        }
    }

    pub inline fn runOp(self: *VM, op: Operation) !void {
        // std.log.debug("{?s}:{}", .{ self.inside_fn, op });
        self.pc += 1;

        switch (op.code) {
            Operation.Code.Nop => {
                return;
            },
            Operation.Code.Push => {
                if (op.string != null) {
                    try self.pushStackS(op.string.?);
                    return;
                }

                if (op.value != null) {
                    try self.pushStackI(op.value.?);
                    return;
                }
            },
            Operation.Code.Add => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a != .value) return error.ValueMissing;

                if (b == .string) {
                    if (b.string.len < a.value.*) {
                        try self.pushStackS("");
                    } else {
                        try self.pushStackS(b.string.*[@intCast(usize, a.value.*)..]);
                    }
                    return;
                }

                if (b == .value) {
                    try self.pushStackI(a.value.* +% b.value.*);
                    return;
                }
            },
            Operation.Code.Sub => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a != .value) return error.ValueMissing;

                if (b == .string) {
                    if (b.string.len < a.value.*) {
                        try self.pushStackS("");
                    } else {
                        try self.pushStackS(b.string.*[0..@intCast(usize, b.string.*.len - a.value.*)]);
                    }
                    return;
                }

                if (b == .value) {
                    try self.pushStackI(b.value.* -% a.value.*);
                    return;
                }
            },
            Operation.Code.Size => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a != .value) return error.ValueMissing;
                if (b != .string) return error.StringMissing;

                if (b.string.len < a.value.*) {
                    try self.pushStackS(b.string.*);
                } else {
                    try self.pushStackS(b.string.*[0..@intCast(usize, a.value.*)]);
                }
                return;
            },
            Operation.Code.Len => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .string) return error.StringMissing;

                try self.pushStackI(a.string.len);

                return;
            },
            Operation.Code.Copy => {
                if (op.value == null) return error.ValueMissing;

                var a = try self.findStack(op.value.?);
                try self.pushStack(a);
                return;
            },
            Operation.Code.Dup => {
                if (op.value == null) return error.ValueMissing;

                var a = try self.findStack(op.value.?);
                if (a == .string) {
                    try self.pushStackS(a.string.*);
                    return;
                }

                if (a == .value) {
                    try self.pushStackI(a.value.*);
                    return;
                }
            },
            Operation.Code.Jmp => {
                if (op.value == null) return error.ValueMissing;

                self.pc = @intCast(usize, op.value.?);
                return;
            },
            Operation.Code.Jz => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a == .string) {
                    if (a.string.len == 0) {
                        self.pc = @intCast(usize, op.value.?);
                    }
                    return;
                }

                if (a == .value) {
                    if (a.value.* == 0) {
                        self.pc = @intCast(usize, op.value.?);
                    }
                    return;
                }
            },
            Operation.Code.Jnz => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a == .string) {
                    if (a.string.len != 0) {
                        self.pc = @intCast(usize, op.value.?);
                    }
                    return;
                }

                if (a == .value) {
                    if (a.value.* != 0) {
                        self.pc = @intCast(usize, op.value.?);
                    }
                    return;
                }
            },
            Operation.Code.Sys => {
                if (op.value != null) {
                    switch (op.value.?) {
                        // print
                        0 => {
                            var a = try self.popStack();
                            defer self.free(&[_]StackEntry{a});

                            if (a == .string) {
                                try self.out.appendSlice(a.string.*);

                                return;
                            }

                            if (a == .value) {
                                var str = try std.fmt.allocPrint(self.allocator, "{}", .{a.value.*});
                                defer self.allocator.free(str);

                                try self.out.appendSlice(str);

                                return;
                            }
                        },
                        // quit
                        1 => {
                            if (self.functions.contains("_quit")) {
                                if (self.inside_fn) |func| {
                                    if (std.mem.eql(u8, func, "_quit")) {
                                        self.stopped = true;
                                        return;
                                    }
                                }
                                self.retStack[self.retRsp].location = self.pc;
                                self.retStack[self.retRsp].function = self.inside_fn;
                                self.pc = 0;
                                self.inside_fn = "_quit";
                                self.retRsp += 1;

                                return;
                            }

                            self.stopped = true;
                            return;
                        },
                        // create file
                        2 => {
                            var path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});

                            if (path != .string) return error.StringMissing;

                            if (path.string.*[0] == '/') {
                                _ = try files.root.newFile(path.string.*);
                            } else {
                                _ = try self.root.newFile(path.string.*);
                            }

                            return;
                        },
                        // open file
                        3 => {
                            var path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});

                            if (path != .string) return error.StringMissing;

                            try self.streams.append(try streams.FileStream.Open(self.root, path.string.*, self));
                            try self.pushStackI(self.streams.items.len - 1);

                            return;
                        },
                        // read
                        4 => {
                            var len = try self.popStack();
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{ len, idx });

                            if (len != .value) return error.ValueMissing;
                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;

                            var fs = self.streams.items[@intCast(usize, idx.value.*)];
                            if (fs == null) return error.InvalidStream;

                            var cont = try fs.?.Read(@intCast(u32, len.value.*));
                            defer self.allocator.free(cont);

                            try self.pushStackS(cont);

                            return;
                        },
                        // write file
                        5 => {
                            if (self.checker) return;
                            var str = try self.popStack();
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{ str, idx });

                            if (str != .string) return error.StringMissing;
                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;

                            var fs = self.streams.items[@intCast(usize, idx.value.*)];
                            if (fs == null) return error.InvalidStream;

                            try fs.?.Write(str.string.*);

                            return;
                        },
                        // flush file
                        6 => {
                            if (self.checker) return;
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;
                            var fs = self.streams.items[@intCast(usize, idx.value.*)];
                            if (fs == null) return error.InvalidStream;

                            try fs.?.Flush();

                            return;
                        },
                        // close file
                        7 => {
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;
                            var fs = self.streams.items[@intCast(usize, idx.value.*)];
                            if (fs == null) return error.InvalidStream;

                            try fs.?.Close();
                            self.streams.items[@intCast(usize, idx.value.*)] = null;

                            return;
                        },
                        // arg
                        8 => {
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.args.len) {
                                try self.pushStackS("");
                                return;
                            }

                            try self.pushStackS(self.args[@intCast(usize, idx.value.*)]);

                            return;
                        },
                        // time
                        9 => {
                            try self.pushStackI(@intCast(u64, std.time.milliTimestamp()));

                            return;
                        },
                        // checkfn
                        10 => {
                            var name = try self.popStack();
                            defer self.free(&[_]StackEntry{name});

                            if (name != .string) return error.StringMissing;

                            var val: u64 = 0;

                            if (self.functions.contains(name.string.*)) val = 1;

                            try self.pushStackI(val);

                            return;
                        },
                        // TODO decide
                        // 11 => {
                        //     var len = try self.popStack();
                        //     defer self.free(&[_]StackEntry{len});

                        //     if (len != .value) return error.ValueMissing;

                        //     var adds = try self.allocator.create([]u8);
                        //     adds.* = try self.allocator.alloc(u8, @intCast(usize, len.value.*));
                        //     self.stack[self.rsp] = StackEntry{ .string = adds };
                        //     self.rsp += 1;
                        //     return;
                        // },
                        // regfn
                        12 => {
                            var name = try self.popStack();
                            var func = try self.popStack();
                            defer self.free(&[_]StackEntry{ name, func });

                            if (func != .string) return error.StringMissing;
                            if (name != .string) return error.StringMissing;

                            var dup = try self.allocator.dupe(u8, func.string.*);

                            var ops = try self.stringToOps(dup);
                            defer ops.deinit();

                            var finalOps = try self.allocator.dupe(Operation, ops.items);
                            var finalName = try self.allocator.dupe(u8, name.string.*);

                            try self.functions.put(finalName, .{
                                .string = dup,
                                .ops = finalOps,
                            });

                            return;
                        },
                        // clear function
                        13 => {
                            var name = try self.popStack();
                            defer self.free(&[_]StackEntry{name});

                            if (name != .string) return error.StringMissing;

                            if (self.functions.fetchRemove(name.string.*)) |entry| {
                                self.allocator.free(entry.key);
                                self.allocator.free(entry.value.ops);
                                self.allocator.free(entry.value.string);
                            }

                            return;
                        },
                        // resize heap
                        14 => {
                            var size = try self.popStack();
                            defer self.free(&[_]StackEntry{size});

                            if (size != .value) return error.ValueMissing;

                            var start = self.heap.len;
                            self.heap = try self.allocator.realloc(self.heap, @intCast(usize, size.value.*));

                            if (start < self.heap.len)
                                @memset(self.heap[start..], 0);

                            return;
                        },
                        // read heap
                        15 => {
                            var size = try self.popStack();
                            var start = try self.popStack();
                            defer self.free(&[_]StackEntry{ start, size });

                            if (start != .value) return error.ValueMissing;
                            if (size != .value) return error.ValueMissing;

                            try self.pushStackS(self.heap[@intCast(usize, start.value.*)..@intCast(usize, start.value.* + size.value.*)]);

                            return;
                        },
                        // write heap
                        16 => {
                            var data = try self.popStack();
                            var start = try self.popStack();
                            defer self.free(&[_]StackEntry{ start, data });

                            if (start != .value) return error.ValueMissing;
                            if (data != .string) return error.StringMissing;

                            std.mem.copy(u8, self.heap[@intCast(usize, start.value.*)..@intCast(usize, start.value.* + data.string.*.len)], data.string.*);

                            return;
                        },
                        // yield
                        17 => {
                            self.yield = true;
                            return;
                        },
                        // error
                        18 => {
                            var msg = try self.popStack();
                            defer self.free(&[_]StackEntry{msg});

                            if (msg != .string) return error.StringMissing;

                            var msgString = try self.getOp();
                            defer self.allocator.free(msgString);

                            try self.out.appendSlice("Error: ");
                            try self.out.appendSlice(msg.string.*);
                            try self.out.appendSlice("\n");
                            try self.out.appendSlice(msgString);

                            self.stopped = true;
                            return;
                        },
                        // file size
                        19 => {
                            var path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});

                            if (path != .string) return error.StringMissing;

                            if (try self.root.getFile(path.string.*)) |file| {
                                try self.pushStackI(file.size());

                                return;
                            }

                            return error.FileMissing;
                        },
                        // setrsp
                        20 => {
                            var num = try self.popStack();
                            defer self.free(&[_]StackEntry{num});

                            if (num != .value) return error.ValueMissing;
                            if (self.rsp < num.value.*) return error.InvalidValue;

                            var oldRsp = self.rsp;

                            self.rsp = num.value.*;

                            self.free(self.stack[self.rsp..oldRsp]);

                            return;
                        },
                        // panic
                        128 => {
                            @panic("VM Crash Called");
                        },
                        // misc
                        else => {
                            return error.InvalidSys;
                        },
                    }
                } else return error.ValueMissing;
            },
            Operation.Code.Jmpf => {
                if (op.value == null) return error.dValueMissing;
                self.pc += @intCast(usize, op.value.?);
                return;
            },
            Operation.Code.Mul => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* *% b.value.*);

                return;
            },
            Operation.Code.Div => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                if (a.value.* == 0) return error.DivZero;

                try self.pushStackI(b.value.* / a.value.*);

                return;
            },
            Operation.Code.Mod => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                if (a.value.* == 0) return error.DivZero;

                try self.pushStackI(b.value.* % a.value.*);

                return;
            },
            Operation.Code.And => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* & b.value.*);

                return;
            },
            Operation.Code.Or => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* | b.value.*);

                return;
            },
            Operation.Code.Neg => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                try self.pushStackI(0 -% a.value.*);

                return;
            },
            Operation.Code.Xor => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* ^ b.value.*);

                return;
            },
            Operation.Code.Not => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                var val: u64 = 0;
                if (a.value.* == 0) val = 1;

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Sin => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                var val: u64 = @floatToInt(u64, (std.math.sin(@intToFloat(f32, a.value.*) * (std.math.pi * 2) / 255) + 1.0) * 127.0);

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Cos => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                var val: u64 = @floatToInt(u64, (std.math.cos(@intToFloat(f32, a.value.*) * (std.math.pi * 2) / 255) + 1.0) * 127.0);

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Asign => {
                var a = try self.popStack();
                var b = try self.popStack();

                defer self.free(&[_]StackEntry{ b, a });

                try self.pushStack(a);

                try self.replaceStack(b, a);

                return;
            },
            Operation.Code.Disc => {
                if (op.value == null) return error.ValueMissing;

                if (op.value.? > self.rsp) return error.StackUnderflow;

                var items = self.stack[self.rsp - @intCast(usize, op.value.?) .. self.rsp];
                self.rsp -= @intCast(u8, op.value.?);
                var disc = try self.popStack();
                defer self.free(&[_]StackEntry{disc});

                for (items) |item| {
                    try self.pushStack(item);
                }

                return;
            },
            Operation.Code.Eq => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a == .string) {
                    if (b == .string) {
                        var val: u64 = 0;
                        if (std.mem.eql(u8, a.string.*, b.string.*)) val = 1;
                        try self.pushStackI(val);
                        return;
                    }

                    if (b == .value) {
                        var val: u64 = 0;
                        if (a.string.*.len != 0 and a.string.*[0] == @intCast(u8, b.value.*)) val = 1;
                        if (a.string.*.len == 0 and 0 == b.value.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    }
                }

                if (a == .value) {
                    if (b == .string) {
                        var val: u64 = 0;
                        if (b.string.*.len != 0 and b.string.*[0] == @intCast(u8, a.value.*)) val = 1;
                        if (b.string.*.len == 0 and 0 == a.value.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    }

                    if (b == .value) {
                        var val: u64 = 0;
                        if (a.value.* == b.value.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    }
                }
            },
            Operation.Code.Less => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                var val: u64 = 0;
                if (a.value.* > b.value.*) val = 1;
                try self.pushStackI(val);
                return;
            },
            Operation.Code.Greater => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                var val: u64 = 0;
                if (a.value.* < b.value.*) val = 1;
                try self.pushStackI(val);
                return;
            },
            Operation.Code.Getb => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a == .string) {
                    if (a.string.len == 0) {
                        try self.pushStackI(0);
                    } else {
                        var val = @intCast(u64, a.string.*[0]);
                        try self.pushStackI(val);
                    }
                    return;
                }

                if (a == .value) {
                    try self.pushStackS(std.mem.asBytes(a.value)[0..1]);

                    return;
                }
            },
            Operation.Code.Ret => {
                self.retRsp -= 1;
                self.pc = @intCast(usize, self.retStack[self.retRsp].location);
                self.inside_fn = self.retStack[self.retRsp].function;
                return;
            },
            Operation.Code.Call => {
                if (op.string != null) {
                    self.retStack[self.retRsp].location = self.pc;
                    self.retStack[self.retRsp].function = self.inside_fn;
                    self.pc = 0;
                    self.inside_fn = op.string;
                    self.retRsp += 1;

                    return;
                }

                self.retStack[self.retRsp].location = self.pc;
                self.retStack[self.retRsp].function = self.inside_fn;
                self.pc = @intCast(usize, op.value.?);
                self.retRsp += 1;
                return;
            },
            Operation.Code.Cat => {
                var b = try self.popStack();
                var a = try self.popStack();

                defer self.free(&[_]StackEntry{ b, a });

                if (a != .string) return error.StringMissing;

                if (b == .string) {
                    var appends = try std.mem.concat(self.allocator, u8, &.{ a.string.*, b.string.* });
                    defer self.allocator.free(appends);

                    try self.pushStackS(appends);

                    return;
                }

                if (b == .value) {
                    var appends = try std.mem.concat(self.allocator, u8, &.{ a.string.*, std.mem.asBytes(b.value) });
                    defer self.allocator.free(appends);

                    try self.pushStackS(appends);

                    return;
                }
            },
            Operation.Code.Create => {
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{b});

                if (b != .value) return error.ValueMissing;

                var adds = try self.allocator.alloc(u8, @intCast(usize, b.value.*));
                defer self.allocator.free(adds);
                @memset(adds, 0);
                try self.pushStackS(adds);

                return;
            },
            else => {},
        }
        return error.InvalidOp;
    }

    pub fn loadList(self: *VM, ops: []Operation) !void {
        var list = try self.allocator.alloc(Operation, ops.len);

        for (ops, 0..) |_, idx| {
            list[idx] = ops[idx];

            if (ops[idx].string != null) {
                var str = try self.allocator.alloc(u8, ops[idx].string.?.len);

                for (ops[idx].string.?, 0..) |_, jdx| {
                    str[jdx] = ops[idx].string.?[jdx];
                }

                list[idx].string = str;
            }
        }
        self.code = list;
    }

    pub fn stringToOps(self: *VM, conts: []const u8) !std.ArrayList(Operation) {
        var ops = std.ArrayList(Operation).init(self.allocator);

        var parsePtr: usize = 0;
        while (parsePtr < conts.len) {
            if (parsePtr >= conts.len) {
                ops.deinit();
                return error.InvalidAsm;
            }
            var code: Operation.Code = try std.meta.intToEnum(Operation.Code, conts[parsePtr]);
            parsePtr += 1;
            if (parsePtr >= conts.len) {
                ops.deinit();
                return error.InvalidAsm;
            }
            var kind = conts[parsePtr];
            parsePtr += 1;

            if (kind == 1) {
                if (parsePtr + 7 >= conts.len) {
                    ops.deinit();
                    return error.InvalidAsm;
                }
                var value = @bitCast(u64, conts[parsePtr..][0..8].*);

                parsePtr += 8;

                try ops.append(VM.Operation{ .code = code, .value = value });
            } else if (kind == 2) {
                var buffPtr: usize = 0;
                while (conts[parsePtr + buffPtr] != 0) {
                    buffPtr += 1;
                    if (buffPtr + parsePtr >= conts.len) {
                        ops.deinit();
                        return error.InvalidAsm;
                    }
                }
                try ops.append(VM.Operation{ .code = code, .string = conts[parsePtr .. parsePtr + buffPtr] });
                parsePtr += buffPtr + 1;
            } else if (kind == 3) {
                if (parsePtr >= conts.len) {
                    ops.deinit();
                    return error.InvalidAsm;
                }
                var value = conts[parsePtr];
                parsePtr += 1;

                try ops.append(VM.Operation{ .code = code, .value = @intCast(u64, value) });
            } else if (kind == 0) {
                try ops.append(VM.Operation{ .code = code });
            } else {
                ops.deinit();
                return error.InvalidAsm;
            }
        }

        return ops;
    }

    pub fn loadString(self: *VM, conts: []const u8) !void {
        var ops = try self.stringToOps(conts);
        defer ops.deinit();

        try self.loadList(ops.items);
    }

    pub fn done(self: *VM) bool {
        return self.stopped or (self.pc >= self.code.?.len and self.inside_fn == null);
    }

    pub fn getOp(self: *VM) ![]u8 {
        var oper: Operation = undefined;
        if (self.inside_fn) |inside| {
            if (self.functions.getPtr(inside)) |func| {
                oper = func.*.ops[self.pc - 1];
            } else {
                if (@enumToInt(oper.code) < @enumToInt(Operation.Code.Last)) {
                    var result = try std.fmt.allocPrint(self.allocator, "In function '{?s}?' @ {}:\nOperation: {s}", .{ self.inside_fn, self.pc, @tagName(oper.code) });
                    return result;
                } else {
                    var result = try std.fmt.allocPrint(self.allocator, "In function '{?s}?' @ {}:\nOperation: ?", .{ self.inside_fn, self.pc });
                    return result;
                }
            }
        } else {
            oper = self.code.?[self.pc - 1];
        }

        var result = try std.fmt.allocPrint(self.allocator, "In function '{?s}' @ {}:\nOperation: {s}", .{ self.inside_fn, self.pc, @tagName(oper.code) });

        return result;
    }

    pub fn getOper(self: *VM) !?Operation {
        if (self.inside_fn) |inside| {
            if (self.functions.getPtr(inside)) |func| {
                if (func.*.ops.len <= self.pc) return .{
                    .code = .Ret,
                };

                return func.*.ops[self.pc];
            }
            //std.log.err("'{s}', {any}", .{inside, self.functions.get(inside)});
            return error.UnknownFunction;
        } else {
            if (self.code.?.len <= self.pc) return null;
            return self.code.?[self.pc];
        }

        return null;
    }

    pub fn runStep(self: *VM) !bool {
        var oper = try self.getOper() orelse return true;

        try self.runOp(oper);

        return self.done();
    }

    pub fn runAll(self: *VM) !void {
        while (!try self.runStep()) {}
    }

    pub fn runTime(self: *VM, ns: u64, comptime _: bool) !bool {
        var timer = try std.time.Timer.start();

        timer.reset();

        while (timer.read() < ns and !self.done() and !self.yield) {
            if (try self.runStep()) {
                return true;
            }
        }

        self.yield = false;

        return self.done();
    }

    pub fn runNum(self: *VM, num: u64) !bool {
        for (range(num)) |_| {
            if (self.runStep() catch |err| {
                return err;
            }) {
                return true;
            }
        }

        return self.done();
    }
};

test "VM Compile bad returns error" {
    var vm = try VM.init(std.testing.allocator, undefined, &[_]u8{}, false);
    var err: anyerror!std.ArrayList(VM.Operation) = undefined;
    err = vm.stringToOps("\x00");
    try std.testing.expectError(error.InvalidAsm, err);
    err = vm.stringToOps("\x00\x02\x01");
    try std.testing.expectError(error.InvalidAsm, err);
    err = vm.stringToOps("\x00\x01\x01");
    try std.testing.expectError(error.InvalidAsm, err);
    err = vm.stringToOps("\x00\x03");
    try std.testing.expectError(error.InvalidAsm, err);

    try vm.deinit();
}
