const std = @import("std");

pub const VM = struct {
    const VMError = error{
        StackUnderflow,
        ValueMissing,
        StringMissing,
        InvalidOp,
        NotImplemented,
    };

    pub const StackEntry = struct {
        string: ?[]const u8 = null,
        value: ?u64 = null,
    };

    allocator: std.mem.Allocator,
    stack: [512]StackEntry,
    rsp: u8 = 0,
    pc: u64 = 0,

    fn pushStack(self: *VM, entry: StackEntry) void {
        self.stack[self.rsp] = entry;
        self.rsp += 1;
    }

    fn pushStackI(self: *VM, value: u64) void {
        self.stack[self.rsp] = StackEntry{ .value = value };
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

    pub const Operation = struct {
        pub const Code = enum(u8) {
            Pushi,
            Pushs,
            Add,
            Copy,
            Swap,
            Jmp,
            Jmpz,
        };

        code: Code,
        string: ?[]const u8 = null,
        value: ?u64 = null,
    };

    pub fn destroy(self: *VM) void {
        for (self.stack[0..self.rsp]) |entry| {
            if (entry.string != null) {
                self.allocator.free(entry.string.?);
            }
        }
    }

    pub fn runOp(self: *VM, op: Operation) !void {
        self.pc += 1;

        switch (op.code) {
            Operation.Code.Pushs => {
                if (op.string == null) return error.ValueMissing;
                self.pushStackS(op.string.?) catch {};
                return;
            },
            Operation.Code.Pushi => {
                if (op.value == null) return error.ValueMissing;
                self.pushStackI(op.value.?);
                return;
            },
            Operation.Code.Add => {
                var a = try self.popStack();
                var b = try self.popStack();

                if (a.string != null) {
                    if (b.string != null) {
                        var comb = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ b.string.?, a.string.? });
                        self.allocator.free(a.string.?);
                        self.allocator.free(b.string.?);
                        try self.pushStackS(comb);
                        self.allocator.free(comb);
                        return;
                    } else if (b.value != null) {
                        return error.InvalidOp;
                    } else return error.InvalidOp;
                } else if (a.value != null) {
                    if (b.string != null) {
                        try self.pushStackS(b.string.?[a.value.?..]);

                        self.allocator.free(b.string.?);

                        return;
                    } else if (b.value != null) {
                        self.pushStackI(a.value.? + b.value.?);
                        return;
                    } else return error.InvalidOp;
                } else return error.InvalidOp;
            },
            Operation.Code.Copy => {
                var a = try self.popStack();
                if (a.string != null) {
                    try self.pushStackS(a.string.?);
                    try self.pushStackS(a.string.?);
                    self.allocator.free(a.string.?);
                    return;
                } else if (a.value != null) {
                    self.pushStackI(a.value.?);
                    self.pushStackI(a.value.?);
                    return;
                } else return error.InvalidOp;
            },
            Operation.Code.Swap => {
                var a = try self.popStack();
                var b = try self.popStack();
                self.pushStack(a);
                self.pushStack(b);
                return;
            },
            Operation.Code.Jmp => {
                if (op.value == null) return error.ValueMissing;
                self.pc = op.value.?;
                return;
            },
            Operation.Code.Jmpz => {
                var a = try self.popStack();
                if (a.string != null) {
                    return error.InvalidOp;
                } else if (a.value != null and a.value.? == 0) {
                    self.pc = op.value.?;
                    return;
                } else return error.InvalidOp;
            },
        }
        return error.NotImplemented;
    }

    pub fn run(self: *VM, ops: []Operation) !void {
        while (self.pc < ops.len) {
            var oper = ops[self.pc];

            try self.runOp(oper);
        }
    }
};

test "vm pushi" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 10 },
    };

    try vm.run(&ops);

    try std.testing.expectEqual(vm.stack[0].value.?, 10);
}

test "vm pushs" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushs, .string = "Hello World!" },
    };

    try vm.run(&ops);

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "Hello World!");
}

test "vm add int int" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 34 },
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 35 },
        VM.Operation{ .code = VM.Operation.Code.Add },
    };

    try vm.run(&ops);

    try std.testing.expectEqual(vm.stack[0].value.?, 69);
}

test "vm add str str" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushs, .string = "Hello " },
        VM.Operation{ .code = VM.Operation.Code.Pushs, .string = "World!" },
        VM.Operation{ .code = VM.Operation.Code.Add },
    };

    try vm.run(&ops);

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "Hello World!");

    vm.destroy();
}

test "vm add str int" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushs, .string = "Hello" },
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 2 },
        VM.Operation{ .code = VM.Operation.Code.Add },
    };

    try vm.run(&ops);

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "llo");
}

test "vm copy str" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushs, .string = "foo" },
        VM.Operation{ .code = VM.Operation.Code.Copy },
    };

    try vm.run(&ops);

    try std.testing.expectEqualStrings(vm.stack[0].string.?, "foo");
    try std.testing.expectEqualStrings(vm.stack[1].string.?, "foo");

    try std.testing.expect(&vm.stack[0].string.? != &vm.stack[1].string.?);
}

test "vm swap" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 34 },
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 35 },
        VM.Operation{ .code = VM.Operation.Code.Swap },
    };

    try vm.run(&ops);

    try std.testing.expectEqual(vm.stack[1].value.?, 34);
    try std.testing.expectEqual(vm.stack[0].value.?, 35);
}

test "vm jnz" {
    var vm = VM{ .stack = undefined, .allocator = std.testing.allocator };
    defer vm.destroy();

    var ops = [_]VM.Operation{
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 34 },
        VM.Operation{ .code = VM.Operation.Code.Pushi, .value = 35 },
        VM.Operation{ .code = VM.Operation.Code.Swap },
    };

    try vm.run(&ops);

    try std.testing.expectEqual(vm.stack[1].value.?, 34);
    try std.testing.expectEqual(vm.stack[0].value.?, 35);
}
