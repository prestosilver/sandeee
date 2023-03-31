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
        string: ?[]u8 = null,
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

    functions: std.StringArrayHashMap(VMFunc),
    inside_fn: ?[]const u8 = null,

    retStack: [512]RetStackEntry = undefined,
    retRsp: u8 = 0,

    pc: u64 = 0,
    code: ?[]const Operation = null,
    stopped: bool = false,

    streams: std.ArrayList(?*streams.FileStream),

    out: std.ArrayList(u8) = undefined,
    args: [][]u8,
    root: *files.Folder,

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
            .functions = std.StringArrayHashMap(VMFunc).init(alloc),
            .out = std.ArrayList(u8).init(alloc),
            .args = tmpArgs,
            .root = root,
        };
    }

    fn pushStack(self: *VM, entry: StackEntry) void {
        self.stack[self.rsp] = entry;
        self.rsp += 1;
    }

    fn pushStackI(self: *VM, value: u64) !void {
        var val = try self.allocator.create(u64);
        val.* = value;

        self.stack[self.rsp] = StackEntry{ .value = val };
        self.rsp += 1;
    }

    fn pushStackS(self: *VM, string: []const u8) !void {
        var appendString = try self.allocator.alloc(u8, string.len);

        for (string, 0..) |char, idx| {
            appendString[idx] = char;
        }

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
            _,
        };

        code: Code,
        string: ?[]const u8 = null,
        value: ?u64 = null,
    };

    pub fn deinit(self: *VM) !void {
        while (self.rsp > 0) {
            self.rsp -= 1;
            self.free(self.stack[self.rsp]);
        }

        if (self.code) |code| {
            for (code) |entry| {
                if (entry.string != null) {
                    self.allocator.free(entry.string.?);
                }
            }
            self.allocator.free(code);
        }

        var iter = self.functions.iterator();

        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*.ops);
            self.allocator.free(entry.value_ptr.*.string);
        }

        for (self.streams.items) |stream| {
            if (stream != null)
                try stream.?.Close();
        }

        for (self.args, 0..) |_, idx| {
            self.allocator.free(self.args[idx]);
        }

        self.allocator.free(self.args);
        self.functions.deinit();
        self.streams.deinit();
        self.out.deinit();
    }

    pub fn freeValue(self: *VM, val: *u64) void {
        for (self.stack[0..self.rsp]) |entry| {
            if (entry.value != null and @ptrToInt(entry.value.?) == @ptrToInt(val)) {
                return;
            }
        }
        self.allocator.destroy(val);
    }

    pub fn freeString(self: *VM, val: []const u8) void {
        for (self.stack[0..self.rsp]) |entry| {
            if (entry.string != null and @ptrToInt(entry.string.?.ptr) == @ptrToInt(val.ptr)) {
                return;
            }
        }
        self.allocator.free(val);
    }

    pub fn resizeString(self: *VM, val: []u8, size: u64) ![]u8 {
        var new = try self.allocator.realloc(val, size);

        for (self.stack[0 .. self.rsp + 1], 0..) |entry, idx| {
            if (entry.string != null and @ptrToInt(entry.string.?.ptr) == @ptrToInt(val.ptr)) {
                self.stack[idx].string = new;
            }
        }
        return new;
    }

    pub fn free(self: *VM, val: StackEntry) void {
        if (val.value != null) self.freeValue(val.value.?);
        if (val.string != null) self.freeString(val.string.?);
    }

    pub fn runOp(self: *VM, op: Operation) !void {
        //std.log.debug("{?s}, {}", .{self.inside_fn, op});

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
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.string != null) {
                    return error.MissingValue;
                } else if (a.value != null) {
                    if (b.string != null) {
                        if (b.string.?.len < a.value.?.*) {
                            try self.pushStackS("");
                        } else {
                            try self.pushStackS(b.string.?[a.value.?.*..]);
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
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.string != null) {
                    return error.InvalidOp;
                } else if (a.value != null) {
                    if (b.string != null) {
                        if (b.string.?.len < a.value.?.*) {
                            try self.pushStackS("");
                        } else {
                            try self.pushStackS(b.string.?[0 .. b.string.?.len - a.value.?.*]);
                        }
                        return;
                    } else if (b.value != null) {
                        try self.pushStackI(b.value.?.* -% a.value.?.*);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Copy => {
                if (op.value == null) return error.ValueMissing;

                var a = try self.findStack(op.value.?);
                self.pushStack(a);
                return;
            },
            Operation.Code.Dup => {
                if (op.value == null) return error.ValueMissing;

                var a = try self.findStack(op.value.?);
                if (a.string != null) {
                    try self.pushStackS(a.string.?);
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
                defer self.free(a);

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
                defer self.free(a);

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
                            defer self.free(a);
                            if (a.string != null) {
                                try self.out.appendSlice(a.string.?);

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
                            defer self.free(path);
                            if (path.value != null) {
                                return error.StringMissing;
                            } else if (path.string != null) {
                                if (path.string.?[0] == '/') {
                                    _ = try files.root.newFile(path.string.?);
                                } else {
                                    _ = try self.root.newFile(path.string.?);
                                }

                                return;
                            } else return error.InvalidOp;
                        },
                        // open file
                        3 => {
                            var path = try self.popStack();
                            defer self.free(path);
                            if (path.value != null) {
                                return error.StringMissing;
                            } else if (path.string != null) {
                                try self.streams.append(try streams.FileStream.Open(self.root, path.string.?));
                                try self.pushStackI(self.streams.items.len - 1);

                                return;
                            } else return error.InvalidOp;
                        },
                        // read
                        4 => {
                            var len = try self.popStack();
                            defer self.free(len);
                            var idx = try self.popStack();
                            defer self.free(idx);
                            if (idx.value != null) {
                                if (idx.value.?.* >= self.streams.items.len) return error.InvalidOp;
                                var fs = self.streams.items[idx.value.?.*];
                                if (fs == null) return error.InvalidOp;
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
                            defer self.free(str);
                            var idx = try self.popStack();
                            defer self.free(idx);
                            if (idx.value != null) {
                                if (idx.value.?.* >= self.streams.items.len) return error.InvalidOp;
                                var fs = self.streams.items[idx.value.?.*];
                                if (fs == null) return error.InvalidOp;
                                if (str.string != null) {
                                    try fs.?.Write(str.string.?);

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
                            defer self.free(idx);

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
                            defer self.free(idx);

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
                            defer self.free(idx);

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
                            defer self.free(name);

                            if (name.string) |nameStr| {
                                var val: u64 = 0;

                                if (self.functions.contains(nameStr)) val = 1;

                                try self.pushStackI(val);

                                return;
                            } else {
                                return error.StringMissing;
                            }
                        },
                        // execcmd
                        11 => {
                            //var cmd = try self.popStack();
                            //defer self.free(cmd);

                            //if (cmd.string) |command| {
                            //    var shl = shell.Shell{
                            //        .root = self.root,
                            //    };

                            //    _ = try shl.runLine(command);

                            //    return;
                            //} else {
                            //    return error.StringMissing;
                            //}
                        },
                        // regfn
                        12 => {
                            var name = try self.popStack();
                            defer self.free(name);
                            var func = try self.popStack();
                            defer self.free(func);
                            if (func.string == null) return error.StringMissing;
                            if (name.string == null) return error.StringMissing;

                            //std.log.info("reg: {s}", .{name.string.?});

                            var dup = try self.allocator.alloc(u8, func.string.?.len);
                            std.mem.copy(u8, dup, func.string.?);

                            var ops = try self.stringToOps(dup);
                            defer ops.deinit();

                            var finalOps = try self.allocator.alloc(Operation, ops.items.len);
                            std.mem.copy(Operation, finalOps, ops.items);

                            var nameStr = try self.allocator.alloc(u8, name.string.?.len);
                            std.mem.copy(u8, nameStr, name.string.?);

                            try self.functions.put(nameStr, .{
                                .string = dup,
                                .ops = finalOps,
                            });

                            return;
                        },
                        // clear function
                        13 => {
                            var name = try self.popStack();
                            defer self.free(name);

                            if (name.string) |nameStr| {
                                _ = self.functions.orderedRemove(nameStr);

                                return;
                            } else {
                                return error.StringMissing;
                            }
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
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* *% b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Div => {
                var a = try self.popStack();
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.value != null) {
                    if (b.value != null) {
                        if (a.value.?.* == 0) return error.DivZero;

                        try self.pushStackI(b.value.?.* / a.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Mod => {
                var a = try self.popStack();
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

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
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* & b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Or => {
                var a = try self.popStack();
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* | b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Neg => {
                var a = try self.popStack();
                defer self.free(a);

                if (a.value != null) {
                    try self.pushStackI(0 -% a.value.?.*);

                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Xor => {
                var a = try self.popStack();
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.value != null) {
                    if (b.value != null) {
                        try self.pushStackI(a.value.?.* ^ b.value.?.*);

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Not => {
                var a = try self.popStack();
                defer self.free(a);

                if (a.value != null) {
                    var val: u64 = 0;
                    if (a.value.?.* == 0) val = 1;

                    try self.pushStackI(val);

                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Asign => {
                var a = try self.popStack();
                defer self.free(a);
                var b = try self.findStack(0);

                if (a.value != null) {
                    if (b.value != null) {
                        b.value.?.* = a.value.?.*;

                        return;
                    } else return error.InvalidOp;
                } else if (a.string != null) {
                    if (b.string != null) {
                        b.string.? = a.string.?;

                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Disc => {
                if (op.value == null) return error.ValueMissing;

                var items = self.stack[self.rsp - op.value.? .. self.rsp];
                self.rsp -= @intCast(u8, op.value.?);
                var disc = try self.popStack();
                defer self.free(disc);

                for (items) |item| {
                    self.pushStack(item);
                }

                return;
            },
            Operation.Code.Eq => {
                var a = try self.popStack();
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

                if (a.string != null) {
                    if (b.string != null) {
                        var val: u64 = 0;
                        if (std.mem.eql(u8, a.string.?, b.string.?)) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else if (b.value != null) {
                        var val: u64 = 0;
                        if (a.string.?.len != 0 and a.string.?[0] == @intCast(u8, b.value.?.*)) val = 1;
                        if (a.string.?.len == 0 and 0 == b.value.?.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else return error.InvalidOp;
                } else if (a.value != null) {
                    if (b.string != null) {
                        var val: u64 = 0;
                        if (b.string.?.len != 0 and b.string.?[0] == @intCast(u8, a.value.?.*)) val = 1;
                        if (b.string.?.len == 0 and 0 == a.value.?.*) val = 1;
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
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

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
                defer self.free(a);
                var b = try self.popStack();
                defer self.free(b);

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
                        if (a.value.?.* < b.value.?.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Getb => {
                var a = try self.popStack();
                defer self.free(a);

                if (a.string != null) {
                    if (a.string.?.len == 0) {
                        try self.pushStackI(0);
                    } else {
                        var val = @intCast(u64, a.string.?[0]);
                        try self.pushStackI(val);
                    }
                    return;
                } else if (a.value != null) {
                    try self.pushStackS(std.mem.toBytes(a.value.?.*)[0..1]);

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
                defer self.free(b);
                var a = try self.findStack(0);

                if (a.string != null) {
                    if (b.string != null) {
                        const start = a.string.?.len;
                        const total = a.string.?.len + b.string.?.len;

                        a.string.? = try self.resizeString(a.string.?, total);
                        std.mem.copy(u8, a.string.?[start..], b.string.?);

                        return;
                    } else if (b.value != null) {
                        const start = a.string.?.len;
                        const total = a.string.?.len + 8;

                        a.string.? = try self.resizeString(a.string.?, total);
                        std.mem.copy(u8, a.string.?[start..], &std.mem.toBytes(b.value.?.*));

                        return;
                    } else return error.InvalidOp;
                } else if (b.string != null) {
                    return error.StringMissing;
                } else return error.InvalidOp;
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
                var value = @bitCast(u64, conts[parsePtr..][0..8].*);

                parsePtr += 8;

                try ops.append(VM.Operation{ .code = code, .value = value });
            } else if (kind == 2) {
                var buffPtr: usize = 0;
                while (conts[parsePtr + buffPtr] != 0) {
                    buffPtr += 1;
                }
                try ops.append(VM.Operation{ .code = code, .string = conts[parsePtr .. parsePtr + buffPtr] });
                parsePtr += buffPtr + 1;
            } else if (kind == 3) {
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
                oper = func.*.ops[self.pc];
            } else {
                var result = try std.fmt.allocPrint(self.allocator, "In function '?' @ {}:\nOperation: {}", .{ self.pc, oper.code });

                return result;
            }
        } else {
            oper = self.code.?[self.pc];
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
            oper = self.code.?[self.pc];
        }

        try self.runOp(oper);

        return self.done();
    }

    pub fn runTime(self: *VM, ns: u64) !bool {
        var timer = try std.time.Timer.start();

        timer.reset();

        while (timer.read() < ns) {
            if (self.runStep() catch |err| {
                return err;
            }) {
                return true;
            }
        }

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
