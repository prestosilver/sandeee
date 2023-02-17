const std = @import("std");
const streams = @import("stream.zig");
const files = @import("files.zig");

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
    };

    pub const StackEntry = struct {
        string: ?[]const u8 = null,
        value: ?*u64 = null,
    };

    allocator: std.mem.Allocator,
    stack: [STACK_MAX]StackEntry,
    rsp: u64 = 0,

    retStack: [512]u64 = undefined,
    retRsp: u8 = 0,

    pc: u64 = 0,
    code: []const Operation = undefined,
    stopped: bool = false,

    streams: std.ArrayList(?*streams.FileStream),

    out: std.ArrayList(u8) = undefined,
    args: [][]u8,

    pub fn init(alloc: std.mem.Allocator, args: []const u8) !VM {
        var splitIter = std.mem.split(u8, args, " ");

        var tmpArgs = try alloc.alloc([]u8, std.mem.count(u8, args, " ") + 1);

        var idx: usize = 0;
        while (splitIter.next()) |item| {
            tmpArgs[idx] = try alloc.alloc(u8, item.len);
            std.mem.copy(u8, tmpArgs[idx], item);
            std.log.info("{s}", .{item});
            idx += 1;
        }

        return VM{
            .stack = undefined,
            .allocator = alloc,
            .streams = std.ArrayList(?*streams.FileStream).init(alloc),
            .args = tmpArgs,
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

        for (string) |char, idx| {
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
        };

        code: Code,
        string: ?[]const u8 = null,
        value: ?u64 = null,
    };

    pub fn destroy(self: *VM) void {
        while (self.rsp >= 1) {
            self.rsp -= 1;
            self.free(self.stack[self.rsp]);
        }

        for (self.code) |entry| {
            if (entry.string != null) {
                self.allocator.free(entry.string.?);
            }
        }

        for (self.streams.items) |stream| {
            if (stream != null)
                stream.?.Close() catch |err| {
                    std.log.err("{}", .{err});
                };
        }

        for (self.args) |_, idx| {
            self.allocator.free(self.args[idx]);
        }

        self.allocator.free(self.code);
        self.allocator.free(self.args);
        self.streams.deinit();
        self.out.deinit();
    }

    pub fn freeValue(self: *VM, val: *u64) void {
        for (self.stack[0..self.rsp]) |entry| {
            if (entry.value != null and entry.value.? == val) {
                return;
            }
        }
        self.allocator.destroy(val);
    }

    pub fn freeString(self: *VM, val: []const u8) void {
        for (self.stack[0..self.rsp]) |entry| {
            if (entry.string != null and @ptrToInt(&entry.string.?) == @ptrToInt(&val)) {
                return;
            }
        }
        self.allocator.free(val);
    }

    pub fn free(self: *VM, val: StackEntry) void {
        if (val.value != null) self.freeValue(val.value.?);
        if (val.string != null) self.freeString(val.string.?);
    }

    pub fn runOp(self: *VM, op: Operation) !void {
        self.pc += 1;

        switch (op.code) {
            Operation.Code.Nop => {
                return;
            },
            Operation.Code.Push => {
                if (op.string != null) {
                    self.pushStackS(op.string.?) catch {};
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
                    if (b.string != null) {
                        var comb = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ b.string.?, a.string.? });
                        try self.pushStackS(comb);
                        self.allocator.free(comb);
                        return;
                    } else if (b.value != null) {
                        if (a.string.?.len <= b.value.?.*) {
                            try (self.pushStackS(""));
                        } else {
                            try self.pushStackS(a.string.?[b.value.?.*..]);
                        }
                        return;
                    } else return error.InvalidOp;
                } else if (a.value != null) {
                    if (b.string != null) {
                        if (b.string.?.len <= a.value.?.*) {
                            try (self.pushStackS(""));
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
                        return error.InvalidOp;
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
                                self.out.appendSlice(a.string.?) catch {};

                                //std.log.debug("{any}", .{a.string.?});

                                return;
                            } else if (a.value != null) {
                                var str = std.fmt.allocPrint(self.allocator, "{}", .{a.value.?.*}) catch "";
                                defer self.allocator.free(str);

                                self.out.appendSlice(str) catch {};

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
                                _ = files.newFile(path.string.?);

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
                                try self.streams.append(try streams.FileStream.Open(path.string.?));
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
                        try self.pushStackI(a.value.?.* * b.value.?.*);

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
                        try self.pushStackI(a.value.?.* / b.value.?.*);

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
                var b = try self.findStack(0);

                if (a.value != null) {
                    if (b.value != null) {
                        b.value.?.* = a.value.?.*;
                        self.free(a);

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
                        return error.InvalidOp;
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
                    var val = @intCast(u64, a.string.?[0]);
                    self.allocator.free(a.string.?);
                    try self.pushStackI(val);
                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Ret => {
                self.retRsp -= 1;
                self.pc = self.retStack[self.retRsp];
                return;
            },
            Operation.Code.Call => {
                if (op.value == null) return error.ValueMissing;

                self.retStack[self.retRsp] = self.pc;
                self.pc = op.value.?;
                self.retRsp += 1;
                return;
            },
        }
        return error.NotImplemented;
    }

    pub fn loadList(self: *VM, ops: []Operation) void {
        var list = self.allocator.alloc(Operation, ops.len) catch null;

        self.out = std.ArrayList(u8).init(self.allocator);

        for (ops) |_, idx| {
            list.?[idx] = ops[idx];

            if (ops[idx].string != null) {
                var str = self.allocator.alloc(u8, ops[idx].string.?.len) catch null;

                for (ops[idx].string.?) |_, jdx| {
                    str.?[jdx] = ops[idx].string.?[jdx];
                }

                list.?[idx].string = str.?;
            }
        }
        self.code = list.?;
    }

    pub fn loadString(self: *VM, conts: []const u8) void {
        var ops = std.ArrayList(Operation).init(self.allocator);
        defer ops.deinit();

        var parsePtr: usize = 0;
        while (parsePtr < conts.len) {
            var code: Operation.Code = @intToEnum(Operation.Code, conts[parsePtr]);
            parsePtr += 1;
            var kind = conts[parsePtr];
            parsePtr += 1;

            if (kind == 1) {
                var value = @bitCast(u64, conts[parsePtr..][0..8].*);

                parsePtr += 8;

                ops.append(VM.Operation{ .code = code, .value = value }) catch {};
            } else if (kind == 2) {
                var buffPtr: usize = 0;
                while (conts[parsePtr + buffPtr] != 0) {
                    buffPtr += 1;
                }
                ops.append(VM.Operation{ .code = code, .string = conts[parsePtr .. parsePtr + buffPtr] }) catch {};
                parsePtr += buffPtr + 1;
            } else if (kind == 3) {
                var value = conts[parsePtr];
                parsePtr += 1;

                ops.append(VM.Operation{ .code = code, .value = @intCast(u64, value) }) catch {};
            } else if (kind == 0) {
                ops.append(VM.Operation{ .code = code }) catch {};
            }
        }

        self.loadList(ops.items);
    }

    pub fn runAll(self: *VM) !void {
        while (!(self.runStep() catch |err| {
            return err;
        })) {}
    }

    pub fn done(self: *VM) bool {
        return self.pc >= self.code.len or self.stopped;
    }

    pub fn runStep(self: *VM) !bool {
        var oper = self.code[self.pc];

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

test "vm pushi" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Push, .value = 10 },
    };

    vm.loadList(&ops);
    try vm.runAll();

    try std.testing.expectEqual(vm.stack[0].value.?.*, 10);
}

test "vm pushs" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Push, .string = "Hello World!" },
    };

    vm.loadList(&ops);
    try vm.runAll();

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "Hello World!");
}

test "vm add int int" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Push, .value = 34 },
        VM.Operation{ .code = VM.Operation.Code.Push, .value = 35 },
        VM.Operation{ .code = VM.Operation.Code.Add },
    };

    vm.loadList(&ops);
    try vm.runAll();

    try std.testing.expectEqual(vm.stack[0].value.?.*, 69);
}

test "vm add str str" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Push, .string = "Hello " },
        VM.Operation{ .code = VM.Operation.Code.Push, .string = "World!" },
        VM.Operation{ .code = VM.Operation.Code.Add },
    };

    vm.loadList(&ops);
    try vm.runAll();

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "Hello World!");

    vm.destroy();
}

test "vm add str int" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Push, .string = "Hello" },
        VM.Operation{ .code = VM.Operation.Code.Push, .value = 2 },
        VM.Operation{ .code = VM.Operation.Code.Add },
    };

    vm.loadList(&ops);
    try vm.runAll();

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "llo");
}

test "vm copy str" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Push, .string = "foo" },
        VM.Operation{ .code = VM.Operation.Code.Dup, .value = 0 },
    };

    vm.loadList(&ops);
    try vm.runAll();

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "foo");
    try std.testing.expectEqualStrings(vm.stack[1].string.?, "foo");

    try std.testing.expect(&vm.stack[0].string.? != &vm.stack[1].string.?);
}

test "vm jnz" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Push, .value = 34 },
        VM.Operation{ .code = VM.Operation.Code.Push, .value = 1 },
        VM.Operation{ .code = VM.Operation.Code.Sub },
        VM.Operation{ .code = VM.Operation.Code.Copy, .value = 0 },
        VM.Operation{ .code = VM.Operation.Code.Sys, .value = 0 },
        VM.Operation{ .code = VM.Operation.Code.Push, .string = "\n" },
        VM.Operation{ .code = VM.Operation.Code.Sys, .value = 0 },
        VM.Operation{ .code = VM.Operation.Code.Copy, .value = 0 },
        VM.Operation{ .code = VM.Operation.Code.Jz, .value = 11 },
        VM.Operation{ .code = VM.Operation.Code.Jmp, .value = 1 },
        VM.Operation{ .code = VM.Operation.Code.Sys, .value = 1 },
    };

    vm.loadList(&ops);
    try vm.runAll();

    try std.testing.expectEqual(vm.stack[0].value.?.*, 0);
}

test "vm loadstr" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops =
        "\x02\x02Hello\x00" ++
        "\x01\x03\x00";

    vm.loadString(ops);
    try vm.runAll();

    try std.testing.expectEqualStrings(vm.out.items, "Hello");
}
