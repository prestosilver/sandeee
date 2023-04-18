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

    pub const StackEntry = struct {
        string: ?*[]u8 = null,
        value: ?*u64 = null,
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
    rsp: u64 = 0,

    functions: std.StringHashMap(VMFunc),
    inside_fn: ?[]const u8 = null,

    retStack: [512]RetStackEntry = undefined,
    retRsp: u8 = 0,

    pc: u64 = 0,
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

    pub fn init(alloc: std.mem.Allocator, root: *files.Folder, args: []const u8) !VM {
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
        };
    }

    fn pushStack(self: *VM, entry: StackEntry) !void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        self.stack[self.rsp] = entry;
        self.rsp += 1;
    }

    fn pushStackI(self: *VM, value: u64) !void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        var val = try self.allocator.create(u64);
        val.* = value;

        self.stack[self.rsp] = StackEntry{ .value = val };
        self.rsp += 1;
    }

    fn pushStackS(self: *VM, string: []const u8) !void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        var appendString = try self.allocator.create([]u8);

        appendString.* = try self.allocator.dupe(u8, string);

        self.stack[self.rsp] = StackEntry{ .string = appendString };
        self.rsp += 1;
    }

    fn popStack(self: *VM) VMError!StackEntry {
        if (self.rsp == 0) return error.StackUnderflow;
        self.rsp -= 1;
        return self.stack[self.rsp];
    }

    fn findStack(self: *VM, idx: u64) VMError!StackEntry {
        if (self.rsp <= idx) return error.StackUnderflow;
        return self.stack[self.rsp - 1 - idx];
    }

    fn replaceStack(self: *VM, a: StackEntry, b: StackEntry) !void {
        for (self.stack[0..self.rsp]) |*entry| {
            if (entry.string == a.string and entry.value == a.value) {
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
                return std.fmt.format(writer, "{} \"{s}\"", .{ self.code, self.string.? });
            } else if (self.value != null) {
                return std.fmt.format(writer, "{} {}", .{ self.code, self.value.? });
            } else {
                return std.fmt.format(writer, "{}", .{self.code});
            }
        }
    };

    pub fn deinit(self: *VM) !void {
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

        self.allocator.free(self.args);
        self.allocator.free(self.heap);
        self.functions.deinit();
        self.streams.deinit();
        self.out.deinit();
    }

    pub fn freeValue(self: *VM, val: *u64) void {
        if (self.rsp != 0) {
            for (self.stack[0..self.rsp]) |entry| {
                if (entry.value != null and entry.value.? == val) {
                    return;
                }
            }
        }
        self.allocator.destroy(val);
    }

    pub fn freeString(self: *VM, val: *[]const u8) void {
        if (self.rsp != 0) {
            for (self.stack[0..self.rsp]) |entry| {
                if (entry.string != null and entry.string.? == val) {
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
                if (val.value == item.value and val.string == item.string) {
                    add = false;
                    break;
                }
            }
            if (add) {
                toFree.append(val) catch {};
            }
        }

        for (toFree.items) |val| {
            if (val.value != null) self.freeValue(val.value.?);
            if (val.string != null) self.freeString(val.string.?);
        }
    }

    pub fn runOp(self: *VM, op: Operation) !void {
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
                } else if (op.value != null) {
                    try self.pushStackI(op.value.?);
                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Add => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a.string != null) {
                    return error.ValueMissing;
                } else if (a.value != null) {
                    if (b.string != null) {
                        if (b.string.?.len < a.value.?.*) {
                            try self.pushStackS("");
                        } else {
                            try self.pushStackS(b.string.?.*[a.value.?.*..]);
                        }
                        return;
                    } else if (b.value != null) {
                        try self.pushStackI(a.value.?.* +% b.value.?.*);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Sub => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a.string != null) {
                    return error.ValueMissing;
                } else if (a.value != null) {
                    if (b.string != null) {
                        if (b.string.?.len < a.value.?.*) {
                            try self.pushStackS("");
                        } else {
                            try self.pushStackS(b.string.?.*[0 .. b.string.?.*.len - a.value.?.*]);
                        }
                        return;
                    } else if (b.value != null) {
                        try self.pushStackI(b.value.?.* -% a.value.?.*);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Size => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a.string != null) {
                    return error.ValueMissing;
                } else if (a.value != null) {
                    if (b.string != null) {
                        if (b.string.?.len < a.value.?.*) {
                            try self.pushStackS(b.string.?.*);
                        } else {
                            try self.pushStackS(b.string.?.*[0..a.value.?.*]);
                        }
                        return;
                    } else return error.StringMissing;
                } else return error.InvalidOp;
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
                if (a.string != null) {
                    try self.pushStackS(a.string.?.*);
                    return;
                } else if (a.value != null) {
                    try self.pushStackI(a.value.?.*);
                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Jmp => {
                if (op.value == null) return error.ValueMissing;
                self.pc = op.value.?;
                return;
            },
            Operation.Code.Jz => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a.string != null) {
                    if (a.string.?.len == 0) {
                        self.pc = op.value.?;
                    }
                    return;
                } else if (a.value != null) {
                    if (a.value.?.* == 0) {
                        self.pc = op.value.?;
                    }
                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Jnz => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a.string != null) {
                    if (a.string.?.len != 0) {
                        self.pc = op.value.?;
                    }
                    return;
                } else if (a.value != null) {
                    if (a.value.?.* != 0) {
                        self.pc = op.value.?;
                    }
                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Sys => {
                if (op.value != null) {
                    switch (op.value.?) {
                        // print
                        0 => {
                            var a = try self.popStack();
                            defer self.free(&[_]StackEntry{a});

                            if (a.string != null) {
                                try self.out.appendSlice(a.string.?.*);

                                return;
                            } else if (a.value != null) {
                                var str = try std.fmt.allocPrint(self.allocator, "{}", .{a.value.?.*});
                                defer self.allocator.free(str);

                                try self.out.appendSlice(str);

                                return;
                            } else return error.InvalidOp;
                        },
                        // quit
                        1 => {
                            self.stopped = true;
                            return;
                        },
                        // create file
                        2 => {
                            var path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});
                            if (path.value != null) {
                                return error.StringMissing;
                            } else if (path.string != null) {
                                if (path.string.?.*[0] == '/') {
                                    _ = try files.root.newFile(path.string.?.*);
                                } else {
                                    _ = try self.root.newFile(path.string.?.*);
                                }

                                return;
                            } else return error.InvalidOp;
                        },
                        // open file
                        3 => {
                            var path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});
                            if (path.value != null) {
                                return error.StringMissing;
                            } else if (path.string != null) {
                                try self.streams.append(try streams.FileStream.Open(self.root, path.string.?.*, self));
                                try self.pushStackI(self.streams.items.len - 1);

                                return;
                            } else return error.InvalidOp;
                        },
                        // read
                        4 => {
                            var len = try self.popStack();
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{ len, idx });
                            if (idx.value != null) {
                                if (idx.value.?.* >= self.streams.items.len) return error.StreamBad;
                                var fs = self.streams.items[idx.value.?.*];
                                if (fs == null) return error.InvalidStream;
                                if (len.value != null) {
                                    var cont = try fs.?.Read(@intCast(u32, len.value.?.*));
                                    defer self.allocator.free(cont);

                                    try self.pushStackS(cont);

                                    return;
                                } else if (len.string != null) {
                                    return error.ValueMissing;
                                } else return error.InvalidOp;
                            } else if (idx.string != null) {
                                return error.ValueMissing;
                            } else return error.InvalidOp;
                        },
                        // write file
                        5 => {
                            var str = try self.popStack();
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{ str, idx });
                            if (idx.value != null) {
                                if (idx.value.?.* >= self.streams.items.len) return error.InvalidOp;
                                var fs = self.streams.items[idx.value.?.*];
                                if (fs == null) return error.InvalidOp;
                                if (str.string != null) {
                                    try fs.?.Write(str.string.?.*);

                                    return;
                                } else if (str.value != null) {
                                    return error.StringMissing;
                                } else return error.InvalidOp;
                            } else if (idx.string != null) {
                                return error.ValueMissing;
                            } else return error.InvalidOp;
                        },
                        // flush file
                        6 => {
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx.value != null) {
                                if (idx.value.?.* >= self.streams.items.len) return error.InvalidOp;
                                var fs = self.streams.items[idx.value.?.*];
                                if (fs == null) return error.InvalidOp;
                                try fs.?.Flush();

                                return;
                            } else if (idx.string != null) {
                                return error.ValueMissing;
                            } else return error.InvalidOp;
                        },
                        // close file
                        7 => {
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx.value != null) {
                                if (idx.value.?.* >= self.streams.items.len) return error.InvalidOp;
                                var fs = self.streams.items[idx.value.?.*];
                                if (fs == null) return error.InvalidOp;
                                try fs.?.Close();

                                self.streams.items[idx.value.?.*] = null;

                                return;
                            } else if (idx.string != null) {
                                return error.ValueMissing;
                            } else return error.InvalidOp;
                        },
                        // arg
                        8 => {
                            var idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx.value != null) {
                                if (idx.value.?.* >= self.args.len) {
                                    try self.pushStackS("");
                                    return;
                                }
                                try self.pushStackS(self.args[idx.value.?.*]);

                                return;
                            } else if (idx.string != null) {
                                return error.ValueMissing;
                            } else return error.InvalidOp;
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

                            if (name.string) |nameStr| {
                                var val: u64 = 0;

                                if (self.functions.contains(nameStr.*)) val = 1;

                                try self.pushStackI(val);

                                return;
                            } else {
                                return error.StringMissing;
                            }
                        },
                        // allocate
                        11 => {
                            var len = try self.popStack();
                            defer self.free(&[_]StackEntry{len});
                            if (len.value == null) return error.ValueMissing;

                            var adds = try self.allocator.create([]u8);
                            adds.* = try self.allocator.alloc(u8, len.value.?.*);
                            self.stack[self.rsp] = StackEntry{ .string = adds };
                            self.rsp += 1;
                            return;
                        },
                        // regfn
                        12 => {
                            var name = try self.popStack();
                            var func = try self.popStack();
                            defer self.free(&[_]StackEntry{ name, func });
                            if (func.string == null) return error.StringMissing;
                            if (name.string == null) return error.StringMissing;

                            //std.log.info("reg: {s}", .{name.string.?});

                            var dup = try self.allocator.dupe(u8, func.string.?.*);

                            var ops = try self.stringToOps(dup);
                            defer ops.deinit();

                            var finalOps = try self.allocator.dupe(Operation, ops.items);
                            var finalName = try self.allocator.dupe(u8, name.string.?.*);

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

                            if (name.string) |nameStr| {
                                if (self.functions.fetchRemove(nameStr.*)) |entry| {
                                    self.allocator.free(entry.key);
                                    self.allocator.free(entry.value.ops);
                                    self.allocator.free(entry.value.string);
                                }

                                return;
                            } else {
                                return error.StringMissing;
                            }
                        },
                        // resize heap
                        14 => {
                            var size = try self.popStack();
                            defer self.free(&[_]StackEntry{size});

                            if (size.value) |sizeVal| {
                                var start = self.heap.len;
                                self.heap = try self.allocator.realloc(self.heap, sizeVal.*);

                                if (start < self.heap.len)
                                    std.mem.set(u8, self.heap[start..], 0);

                                return;
                            } else {
                                return error.ValueMissing;
                            }
                        },
                        // read heap
                        15 => {
                            var size = try self.popStack();
                            var start = try self.popStack();
                            defer self.free(&[_]StackEntry{ start, size });
                            if (start.value == null) return error.ValueMissing;
                            if (size.value == null) return error.ValueMissing;

                            try self.pushStackS(self.heap[start.value.?.* .. start.value.?.* + size.value.?.*]);

                            return;
                        },
                        // write heap
                        16 => {
                            var data = try self.popStack();
                            var start = try self.popStack();
                            defer self.free(&[_]StackEntry{ start, data });
                            if (start.value == null) return error.ValueMissing;
                            if (data.string == null) return error.StringMissing;

                            std.mem.copy(u8, self.heap[start.value.?.* .. start.value.?.* + data.string.?.len], data.string.?.*);

                            return;
                        },
                        // yield
                        17 => {
                            self.yield = true;
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
                if (op.value == null) return error.ValueMissing;
                self.pc += op.value.?;
                return;
            },
            Operation.Code.Mul => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* *% b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Div => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.value != null) {
                    if (b.value != null) {
                        if (a.value.?.* == 0) return error.DivZero;

                        try self.pushStackI(b.value.?.* / a.value.?.*);

                        return;
                    } else return error.ValueMissing;
                } else return error.ValueMissing;
            },
            Operation.Code.Mod => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.value != null) {
                    if (b.value != null) {
                        if (a.value.?.* == 0) return error.DivZero;

                        try self.pushStackI(b.value.?.* % a.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.And => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* & b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Or => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* | b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Neg => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a.value != null) {
                    try self.pushStackI(0 -% a.value.?.*);

                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Xor => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* ^ b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Not => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a.value != null) {
                    var val: u64 = 0;
                    if (a.value.?.* == 0) val = 1;

                    try self.pushStackI(val);

                    return;
                } else return error.InvalidOp;
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

                var items = self.stack[self.rsp - op.value.? .. self.rsp];
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

                if (a.string != null) {
                    if (b.string != null) {
                        var val: u64 = 0;
                        if (std.mem.eql(u8, a.string.?.*, b.string.?.*)) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else if (b.value != null) {
                        var val: u64 = 0;
                        if (a.string.?.*.len != 0 and a.string.?.*[0] == @intCast(u8, b.value.?.*)) val = 1;
                        if (a.string.?.*.len == 0 and 0 == b.value.?.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else return error.InvalidOp;
                } else if (a.value != null) {
                    if (b.string != null) {
                        var val: u64 = 0;
                        if (b.string.?.*.len != 0 and b.string.?.*[0] == @intCast(u8, a.value.?.*)) val = 1;
                        if (b.string.?.*.len == 0 and 0 == a.value.?.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else if (b.value != null) {
                        var val: u64 = 0;
                        if (a.value.?.* == b.value.?.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Less => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.string != null) {
                    if (b.string != null) {
                        return error.InvalidOp;
                    } else if (b.value != null) {
                        return error.InvalidOp;
                    } else return error.InvalidOp;
                } else if (a.value != null) {
                    if (b.string != null) {
                        return error.InvalidOp;
                    } else if (b.value != null) {
                        var val: u64 = 0;
                        if (a.value.?.* > b.value.?.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Greater => {
                var a = try self.popStack();
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a.string != null) {
                    return error.ValueMissing;
                } else if (a.value != null) {
                    if (b.string != null) {
                        return error.ValueMissing;
                    } else if (b.value != null) {
                        var val: u64 = 0;
                        if (a.value.?.* < b.value.?.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Getb => {
                var a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a.string != null) {
                    if (a.string.?.len == 0) {
                        try self.pushStackI(0);
                    } else {
                        var val = @intCast(u64, a.string.?.*[0]);
                        try self.pushStackI(val);
                    }
                    return;
                } else if (a.value != null) {
                    try self.pushStackS(std.mem.asBytes(a.value.?)[0..1]);

                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Ret => {
                self.retRsp -= 1;
                self.pc = self.retStack[self.retRsp].location;
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
                self.pc = op.value.?;
                self.retRsp += 1;
                return;
            },
            Operation.Code.Cat => {
                var b = try self.popStack();
                var a = try self.popStack();

                defer self.free(&[_]StackEntry{ b, a });

                if (a.string != null) {
                    if (b.string != null) {
                        var appends = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ a.string.?.*, b.string.?.* });
                        defer self.allocator.free(appends);

                        try self.pushStackS(appends);

                        return;
                    } else if (b.value != null) {
                        var appends = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ a.string.?.*, std.mem.asBytes(b.value.?) });
                        defer self.allocator.free(appends);

                        try self.pushStackS(appends);

                        return;
                    } else return error.InvalidOp;
                } else if (b.string != null) {
                    return error.StringMissing;
                } else return error.InvalidOp;
            },
            Operation.Code.Create => {
                var b = try self.popStack();
                defer self.free(&[_]StackEntry{b});

                if (b.value) |length| {
                    var adds = try self.allocator.alloc(u8, length.*);
                    defer self.allocator.free(adds);
                    std.mem.set(u8, adds, 0);
                    try self.pushStackS(adds);

                    return;
                } else return error.ValueMissing;
            },
            _ => {
                return error.InvalidOp;
            },
        }
        return error.NotImplemented;
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
            var code: Operation.Code = @intToEnum(Operation.Code, conts[parsePtr]);
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

    pub fn runAll(self: *VM) !void {
        while (!(self.runStep() catch |err| {
            return err;
        })) {}
    }

    pub fn done(self: *VM) bool {
        return (self.pc >= self.code.?.len and self.inside_fn == null) or self.stopped;
    }

    pub fn getOp(self: *VM) ![]u8 {
        var oper: Operation = undefined;
        if (self.inside_fn) |inside| {
            if (self.functions.getPtr(inside)) |func| {
                oper = func.*.ops[self.pc - 1];
            } else {
                var result = try std.fmt.allocPrint(self.allocator, "In function '?' @ {}:\nOperation: {}", .{ self.pc, oper.code });

                return result;
            }
        } else {
            oper = self.code.?[self.pc - 1];
        }

        var result = try std.fmt.allocPrint(self.allocator, "In function '{?s}' @ {}:\nOperation: {}", .{ self.inside_fn, self.pc, oper.code });

        return result;
    }

    pub fn runStep(self: *VM) !bool {
        var oper: Operation = undefined;
        if (self.inside_fn) |inside| {
            if (self.functions.getPtr(inside)) |func| {
                oper = func.*.ops[self.pc];
            } else {
                //std.log.err("'{s}', {any}", .{inside, self.functions.get(inside)});
                return error.UnknownFunction;
            }
        } else {
            if (self.code.?.len <= self.pc) return self.done();
            oper = self.code.?[self.pc];
        }

        try self.runOp(oper);

        return self.done();
    }

    pub fn runTime(self: *VM, ns: u64) !bool {
        var timer = try std.time.Timer.start();

        timer.reset();

        while (timer.read() < ns and !self.yield) {
            if (self.runStep() catch |err| {
                return err;
            }) {
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
    var vm = try VM.init(std.testing.allocator, undefined, &[_]u8{});
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
