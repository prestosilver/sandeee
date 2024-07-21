const std = @import("std");
const streams = @import("stream.zig");
const files = @import("files.zig");
const telem = @import("telem.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const windowedState = @import("../states/windowed.zig");
const syscalls = @import("syscalls.zig");
const vmAlloc = @import("vmalloc.zig");

const vmManager = @import("vmmanager.zig");

const log = @import("../util/log.zig").log;

pub const MAIN_NAME = "_main";
pub const EXIT_NAME = "_quit";

// TODO: move stack stuff to settings?
const STACK_MAX = 2048;
const RET_STACK_MAX = 256;

pub var syslock = std.Thread.Mutex{};

pub const VM = struct {
    pub const VMError = error{
        BadFileName,
        FolderNotFound,

        OutOfMemory,
        StackUnderflow,
        StackOverflow,
        CallStackUnderflow,
        CallStackOverflow,
        HeapOutOfBounds,
        ValueMissing,
        StringMissing,
        FunctionMissing,

        DivZero,

        InvalidOp,
        InvalidSys,
        InvalidPassword,
        InvalidStream,
        InvalidAsm,

        NotImplemented,
        UnknownFunction,
        Todo,
    } || streams.StreamError;

    const StackEntryKind = enum {
        string,
        value,
    };

    pub const HeapEntry = union(StackEntryKind) {
        string: []const u8,
        value: u64,
    };

    pub const RetStackEntry = struct {
        function: ?[]const u8,
        location: usize,
    };

    pub const VMFunc = struct {
        string: []const u8,
        ops: []Operation,
    };

    allocator: std.mem.Allocator,
    stack: [STACK_MAX]vmAlloc.ObjectRef = undefined,
    rsp: usize = 0,

    functions: std.StringHashMap(VMFunc),
    inside_fn: ?[]const u8 = null,

    retStack: [RET_STACK_MAX]RetStackEntry = undefined,
    retRsp: u8 = 0,

    pc: usize = 0,
    code: ?[]const Operation = null,
    stopped: bool = false,
    yield: bool = false,
    miscData: std.StringHashMap([]const u8),
    input: std.ArrayList(u8),
    last_exec: usize = 0,

    streams: std.ArrayList(?*streams.FileStream),

    out: std.ArrayList(u8) = undefined,
    args: [][]const u8,
    root: *files.Folder,
    heap: []HeapEntry,

    name: []const u8,

    checker: bool = false,

    rnd: std.rand.DefaultPrng,

    pub fn init(alloc: std.mem.Allocator, root: *files.Folder, args: []const u8, comptime checker: bool) VMError!VM {
        var splitIter = std.mem.split(u8, args, " ");

        var tmpArgs = try alloc.alloc([]u8, std.mem.count(u8, args, " ") + 1);

        var idx: usize = 0;
        while (splitIter.next()) |item| : (idx += 1)
            tmpArgs[idx] = alloc.dupe(u8, item) catch return error.OutOfMemory;

        return VM{
            .allocator = alloc,
            .streams = std.ArrayList(?*streams.FileStream).init(alloc),
            .functions = std.StringHashMap(VMFunc).init(alloc),
            .miscData = std.StringHashMap([]const u8).init(alloc),
            .out = std.ArrayList(u8).init(alloc),
            .input = std.ArrayList(u8).init(alloc),
            .heap = alloc.alloc(HeapEntry, 0) catch return error.OutOfMemory,
            .args = tmpArgs,
            .root = root,
            .checker = checker,
            .name = alloc.dupe(u8, tmpArgs[0]) catch return error.OutOfMemory,
            .rnd = std.rand.DefaultPrng.init(0),
        };
    }

    pub inline fn pushStack(self: *VM, entry: vmAlloc.ObjectRef) VMError!void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        self.stack[self.rsp] = entry;
        self.rsp += 1;
    }

    pub inline fn pushStackI(self: *VM, value: u64) VMError!void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;

        self.stack[self.rsp] = try vmAlloc.new(.{ .value = value });
        self.rsp += 1;
    }

    pub inline fn pushStackS(self: *VM, string: []const u8) VMError!void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;

        self.stack[self.rsp] = try vmAlloc.new(.{ .string = try self.allocator.dupe(u8, string) });
        self.rsp += 1;
    }

    pub inline fn popStack(self: *VM) VMError!vmAlloc.ObjectRef {
        if (self.rsp == 0) return error.StackUnderflow;
        self.rsp -= 1;
        return self.stack[self.rsp];
    }

    pub inline fn findStack(self: *VM, idx: u64) VMError!vmAlloc.ObjectRef {
        if (self.rsp <= idx) return error.StackUnderflow;
        return self.stack[self.rsp - 1 - @as(usize, @intCast(idx))];
    }

    pub inline fn replaceStack(self: *VM, a: vmAlloc.ObjectRef, b: vmAlloc.ObjectRef) VMError!void {
        for (self.stack[0..self.rsp]) |*entry| {
            if (entry.*.id == a.id) {
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
            Random,
            Seed,
            Zero,

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

    pub fn getMetaUsage(self: *VM) !usize {
        var result = self.rsp;
        result += self.retRsp;
        result += self.heap.len;

        return result;
    }

    pub fn deinit(self: *VM) !void {
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

        for (self.args) |*item|
            self.allocator.free(item.*);

        for (self.heap) |item|
            switch (item) {
                .string => |v| self.allocator.free(v),
                else => {},
            };

        var miscIter = self.miscData.iterator();

        while (miscIter.next()) |entry|
            self.allocator.free(entry.value_ptr.*);

        self.allocator.free(self.name);
        self.allocator.free(self.args);
        self.allocator.free(self.heap);
        self.functions.deinit();
        self.miscData.deinit();
        self.streams.deinit();
        self.out.deinit();
    }

    pub inline fn runOp(self: *VM, op: Operation) VMError!void {
        telem.Telem.instance.instructionCalls += 1;

        //log.debug("{}", .{op});

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
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;

                if (b.data().* == .string) {
                    if (b.data().string.len < a.data().value) {
                        try self.pushStackS("");
                    } else {
                        try self.pushStackS(b.data().string[@as(usize, @intCast(a.data().value))..]);
                    }

                    return;
                }

                if (b.data().* == .value) {
                    try self.pushStackI(a.data().value +% b.data().value);

                    return;
                }
            },
            Operation.Code.Sub => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;

                if (b.data().* == .string) {
                    if (b.data().string.len < a.data().value) {
                        try self.pushStackS("");
                    } else {
                        try self.pushStackS(b.data().string[0 .. b.data().string.len - a.data().value]);
                    }
                    return;
                }

                if (b.data().* == .value) {
                    try self.pushStackI(b.data().value -% a.data().value);
                    return;
                }
            },
            Operation.Code.Size => {
                const a = try self.popStack();
                const b = try self.findStack(0);

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .string) return error.StringMissing;

                b.data().string = try self.allocator.realloc(b.data().string, a.data().value);

                return;
            },
            Operation.Code.Len => {
                const a = try self.popStack();

                if (a.data().* != .string) return error.StringMissing;

                try self.pushStackI(a.data().string.len);

                return;
            },
            Operation.Code.Copy => {
                if (op.value == null) return error.ValueMissing;

                const a = try self.findStack(op.value.?);
                try self.pushStack(a);
                return;
            },
            Operation.Code.Dup => {
                if (op.value == null) return error.ValueMissing;

                const a = try self.findStack(op.value.?);

                if (a.data().* == .string) {
                    try self.pushStackS(a.data().string);
                    return;
                }

                if (a.data().* == .value) {
                    try self.pushStackI(a.data().value);
                    return;
                }
            },
            Operation.Code.Jmp => {
                if (op.value == null) return error.ValueMissing;

                self.pc = @as(usize, @intCast(op.value.?));
                return;
            },
            Operation.Code.Jz => {
                const a = try self.popStack();

                if (a.data().* == .string) {
                    if (a.data().string.len == 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }

                if (a.data().* == .value) {
                    if (a.data().value == 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }
            },
            Operation.Code.Jnz => {
                const a = try self.popStack();

                if (a.data().* == .string) {
                    if (a.data().string.len != 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }

                if (a.data().* == .value) {
                    if (a.data().value != 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }
            },
            Operation.Code.Sys => {
                //syslock.lock();
                //defer syslock.unlock();

                if (op.value) |index| {
                    // log.debug("syscall {}", .{op});

                    syscalls.SysCall.run(self, index) catch |err| {
                        switch (err) {
                            error.InvalidSys => {
                                switch (op.value.?) {
                                    // panic
                                    128 => {
                                        if (@import("builtin").is_test)
                                            return error.InvalidSys;
                                        if (!windowedState.GSWindowed.globalSelf.debug_enabled)
                                            return error.InvalidSys;

                                        @panic("VM Crash Called");
                                    },
                                    // secret
                                    255 => {
                                        events.EventManager.instance.sendEvent(systemEvs.EventSys{
                                            .sysId = op.value.?,
                                        }) catch return error.InvalidSys;

                                        if (self.rsp == 0)
                                            return error.InvalidPassword;

                                        const pass = try self.popStack();

                                        if (pass.data().* != .string) return error.StringMissing;

                                        if (std.mem.eql(u8, pass.data().string, "Hi")) {
                                            try self.out.appendSlice("Hello World!\n");

                                            return;
                                        }

                                        const dbg_pass = try telem.Telem.getDebugPassword();
                                        defer self.allocator.free(dbg_pass);

                                        if (std.mem.eql(u8, pass.data().string, dbg_pass)) {
                                            try self.out.appendSlice("Debug Mode Enabled\n");

                                            events.EventManager.instance.sendEvent(systemEvs.EventDebugSet{
                                                .enabled = true,
                                            }) catch {
                                                return error.InvalidSys;
                                            };

                                            return;
                                        }

                                        log.debug("password dosent match {s}", .{dbg_pass});

                                        return error.InvalidPassword;
                                    },
                                    // misc
                                    else => {
                                        return error.InvalidSys;
                                    },
                                }
                            },
                            else => {
                                return err;
                            },
                        }
                    };
                    return;
                } else return error.ValueMissing;
            },
            Operation.Code.Jmpf => {
                if (op.value == null) return error.ValueMissing;
                self.pc += @as(usize, @intCast(op.value.?));
                return;
            },
            Operation.Code.Mul => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                try self.pushStackI(a.data().value *% b.data().value);

                return;
            },
            Operation.Code.Div => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                if (a.data().value == 0) return error.DivZero;

                try self.pushStackI(b.data().value / a.data().value);

                return;
            },
            Operation.Code.Mod => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                if (a.data().value == 0) return error.DivZero;

                try self.pushStackI(b.data().value % a.data().value);

                return;
            },
            Operation.Code.And => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                try self.pushStackI(a.data().value & b.data().value);

                return;
            },
            Operation.Code.Or => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                try self.pushStackI(a.data().value | b.data().value);

                return;
            },
            Operation.Code.Neg => {
                const a = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;

                try self.pushStackI(0 -% a.data().value);

                return;
            },
            Operation.Code.Xor => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                try self.pushStackI(a.data().value ^ b.data().value);

                return;
            },
            Operation.Code.Not => {
                const a = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;

                const val: u64 = if (a.data().value == 0) 1 else 0;

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Sin => {
                const a = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;

                const val: u64 = @as(u64, @intFromFloat((std.math.sin(@as(f32, @floatFromInt(a.data().value)) * (std.math.pi * 2) / 255) + 1.0) * 127.0));

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Cos => {
                const a = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;

                const val: u64 = @as(u64, @intFromFloat((std.math.cos(@as(f32, @floatFromInt(a.data().value)) * (std.math.pi * 2) / 255) + 1.0) * 127.0));

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Asign => {
                const a = try self.popStack();
                const b = try self.popStack();

                try self.pushStack(a);

                try self.replaceStack(b, a);

                return;
            },
            Operation.Code.Disc => {
                if (op.value == null) return error.ValueMissing;
                if (op.value.? > self.rsp) return error.StackUnderflow;

                switch (op.value.?) {
                    0 => {
                        _ = try self.popStack();
                    },
                    else => {
                        const items = self.stack[self.rsp - @as(usize, @intCast(op.value.?)) .. self.rsp];
                        self.rsp -= @as(u8, @intCast(op.value.?));
                        _ = try self.popStack();
                        std.mem.copyForwards(vmAlloc.ObjectRef, self.stack[self.rsp .. self.rsp + items.len], items);
                        self.rsp += items.len;
                    },
                }

                return;
            },
            Operation.Code.Eq => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* == .string) {
                    if (b.data().* == .string) {
                        const val: u64 = if (std.mem.eql(u8, a.data().string, b.data().string)) 1 else 0;
                        try self.pushStackI(val);
                        return;
                    }

                    if (b.data().* == .value) {
                        var val: u64 = 0;
                        if (a.data().string.len != 0 and a.data().string[0] == @as(u8, @intCast(@mod(b.data().value, 256)))) val = 1;
                        if (a.data().string.len == 0 and b.data().value == 0) val = 1;
                        try self.pushStackI(val);
                        return;
                    }
                }

                if (a.data().* == .value) {
                    if (b.data().* == .string) {
                        var val: u64 = 0;
                        if (b.data().string.len != 0 and b.data().string[0] == @as(u8, @intCast(@mod(a.data().value, 256)))) val = 1;
                        if (b.data().string.len == 0 and a.data().value == 0) val = 1;
                        try self.pushStackI(val);
                        return;
                    }

                    if (b.data().* == .value) {
                        const val: u64 = if (a.data().value == b.data().value) 1 else 0;
                        try self.pushStackI(val);
                        return;
                    }
                }
            },
            Operation.Code.Less => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                const val: u64 = if (a.data().value > b.data().value) 1 else 0;
                try self.pushStackI(val);
                return;
            },
            Operation.Code.Greater => {
                const a = try self.popStack();
                const b = try self.popStack();

                if (a.data().* != .value) return error.ValueMissing;
                if (b.data().* != .value) return error.ValueMissing;

                const val: u64 = if (a.data().value < b.data().value) 1 else 0;
                try self.pushStackI(val);
                return;
            },
            Operation.Code.Getb => {
                const a = try self.popStack();

                if (a.data().* == .string) {
                    if (a.data().string.len == 0) {
                        try self.pushStackI(0);
                    } else {
                        const val = @as(u64, @intCast(a.data().string[0]));
                        try self.pushStackI(val);
                    }
                    return;
                }

                if (a.data().* == .value) {
                    try self.pushStackS(std.mem.asBytes(&a.data().value)[0..1]);

                    return;
                }
            },
            Operation.Code.Ret => {
                if (self.retRsp == 0) return error.CallStackUnderflow;

                self.retRsp -= 1;
                self.pc = @as(usize, @intCast(self.retStack[self.retRsp].location));
                self.inside_fn = self.retStack[self.retRsp].function;
                return;
            },
            Operation.Code.Call => {
                if (self.retRsp >= self.retStack.len - 1) return error.CallStackOverflow;

                if (op.string != null) {
                    self.retStack[self.retRsp].location = self.pc;
                    self.retStack[self.retRsp].function = self.inside_fn;
                    self.pc = 0;
                    self.inside_fn = op.string;
                    self.retRsp += 1;

                    return;
                }

                if (op.value != null) {
                    self.retStack[self.retRsp].location = self.pc;
                    self.retStack[self.retRsp].function = self.inside_fn;
                    self.pc = @as(usize, @intCast(op.value.?));
                    self.retRsp += 1;

                    return;
                }

                const name = try self.popStack();

                if (name.data().* != .string) return error.StringMissing;

                self.retStack[self.retRsp].location = self.pc;
                self.retStack[self.retRsp].function = self.inside_fn;
                self.pc = 0;
                if (self.functions.getEntry(name.data().string)) |entry| {
                    self.inside_fn = entry.key_ptr.*;
                } else {
                    return error.FunctionMissing;
                }

                self.retRsp += 1;

                return;
            },
            .Cat => {
                const b = try self.popStack();
                const a = try self.popStack();

                if (a.data().* != .string) return error.StringMissing;

                if (b.data().* == .string) {
                    const appends = try std.mem.concat(self.allocator, u8, &.{ a.data().string, b.data().string });
                    defer self.allocator.free(appends);

                    try self.pushStackS(appends);

                    return;
                }

                if (b.data().* == .value) {
                    const appends = try std.mem.concat(self.allocator, u8, &.{ a.data().string, std.mem.asBytes(&b.data().value) });
                    defer self.allocator.free(appends);

                    try self.pushStackS(appends);

                    return;
                }
            },
            .Create => {
                const b = try self.popStack();

                if (b.data().* != .value) return error.ValueMissing;

                const adds = try self.allocator.alloc(u8, b.data().value);
                defer self.allocator.free(adds);

                try self.pushStackS(adds);

                return;
            },
            .Random => {
                const val: u64 = self.rnd.random().int(u64);

                try self.pushStackI(val);

                return;
            },
            .Seed => {
                const seed = try self.popStack();

                if (seed.data().* != .value) return error.ValueMissing;

                self.rnd.seed(seed.data().value);

                return;
            },
            .Zero => {
                const b = try self.findStack(0);

                if (b.data().* != .string) return error.ValueMissing;

                @memset(b.data().string, 0);

                return;
            },
            else => return error.InvalidOp,
        }
    }

    pub fn loadList(self: *VM, ops: []Operation) !void {
        const list = try self.allocator.alloc(Operation, ops.len);

        for (ops, 0..) |_, idx| {
            list[idx] = ops[idx];

            if (ops[idx].string != null) {
                const str = try self.allocator.alloc(u8, ops[idx].string.?.len);

                for (ops[idx].string.?, 0..) |_, jdx| {
                    str[jdx] = ops[idx].string.?[jdx];
                }

                list[idx].string = str;
            }
        }
        self.code = list;
    }

    pub fn stringToOps(self: *VM, conts: []const u8) VMError!std.ArrayList(Operation) {
        var ops = std.ArrayList(Operation).init(self.allocator);
        errdefer ops.deinit();

        var parsePtr: usize = 0;
        while (parsePtr < conts.len) {
            if (parsePtr >= conts.len) {
                return error.InvalidAsm;
            }
            const code: Operation.Code = std.meta.intToEnum(Operation.Code, conts[parsePtr]) catch {
                return error.InvalidAsm;
            };
            parsePtr += 1;
            if (parsePtr >= conts.len) {
                return error.InvalidAsm;
            }
            const kind = conts[parsePtr];
            parsePtr += 1;

            if (kind == 1) {
                if (parsePtr + 7 >= conts.len) {
                    return error.InvalidAsm;
                }
                const value = @as(u64, @bitCast(conts[parsePtr..][0..8].*));

                parsePtr += 8;

                try ops.append(VM.Operation{ .code = code, .value = value });
            } else if (kind == 2) {
                var buffPtr: usize = 0;
                while (parsePtr + buffPtr < conts.len and conts[parsePtr + buffPtr] != 0) {
                    buffPtr += 1;
                    if (buffPtr + parsePtr >= conts.len) {
                        return error.InvalidAsm;
                    }
                }
                try ops.append(VM.Operation{ .code = code, .string = conts[parsePtr .. parsePtr + buffPtr] });
                parsePtr += buffPtr + 1;
            } else if (kind == 3) {
                if (parsePtr >= conts.len) {
                    return error.InvalidAsm;
                }
                const value = conts[parsePtr];
                parsePtr += 1;

                try ops.append(VM.Operation{ .code = code, .value = @as(u64, @intCast(value)) });
            } else if (kind == 0) {
                try ops.append(VM.Operation{ .code = code });
            } else {
                return error.InvalidAsm;
            }
        }

        return ops;
    }

    pub fn loadString(self: *VM, conts: []const u8) !void {
        const ops = try self.stringToOps(conts);
        defer ops.deinit();

        try self.loadList(ops.items);
    }

    pub fn done(self: *VM) bool {
        return self.stopped or (self.pc >= self.code.?.len and self.inside_fn == null);
    }

    pub fn backtrace(self: *VM, i: u8) ![]const u8 {
        if (i == 0)
            return try std.fmt.allocPrint(self.allocator, "{}: {s} {}", .{ i, self.inside_fn orelse MAIN_NAME, self.pc });

        const bt = try self.backtrace(i - 1);
        defer self.allocator.free(bt);

        return try std.fmt.allocPrint(self.allocator, "{}: {s} {}\n{s}", .{ i, self.retStack[i - 1].function orelse MAIN_NAME, self.retStack[i - 1].location, bt });
    }

    pub fn getOp(self: *VM) ![]u8 {
        var oper: Operation = undefined;
        const bt = try self.backtrace(self.retRsp);

        defer self.allocator.free(bt);

        if (self.inside_fn) |inside| {
            if (self.functions.getPtr(inside)) |func| {
                oper = func.*.ops[self.pc - 1];
            } else {
                if (@intFromEnum(oper.code) < @intFromEnum(Operation.Code.Last)) {
                    return try std.fmt.allocPrint(self.allocator, "In function '{s}?' @ {}:\n  Operation: {}\n\n{s}", .{ self.inside_fn orelse MAIN_NAME, self.pc, oper, bt });
                } else {
                    return try std.fmt.allocPrint(self.allocator, "In function '{s}?' @ {}:\n  Operation: ?\n\n{s}", .{ self.inside_fn orelse MAIN_NAME, self.pc, bt });
                }
            }
        } else {
            oper = if (self.pc == 0)
                .{ .code = .Nop }
            else
                self.code.?[self.pc - 1];
        }

        return try std.fmt.allocPrint(self.allocator, "In function '{s}' @ {}:\n  Operation: {}\n{s}", .{ self.inside_fn orelse MAIN_NAME, self.pc, oper, bt });
    }

    pub fn getOper(self: *VM) !?Operation {
        if (self.inside_fn) |inside| {
            if (self.functions.getPtr(inside)) |func| {
                if (func.*.ops.len <= self.pc) return .{
                    .code = .Ret,
                };

                return func.*.ops[self.pc];
            }
            log.err("'{s}', {any}", .{ inside, self.functions.get(inside) });
            return error.UnknownFunction;
        } else {
            if (self.code.?.len <= self.pc) return null;
            return self.code.?[self.pc];
        }

        return null;
    }

    pub fn runStep(self: *VM) !bool {
        const oper = try self.getOper() orelse return true;

        try self.runOp(oper);

        std.Thread.yield() catch {};

        return self.done();
    }

    pub fn runAll(self: *VM) !void {
        while (!try self.runStep()) {}
    }

    pub fn runTime(self: *VM, ns: u64, comptime _: bool) !bool {
        if (self.code == null) return error.InvalidASM;
        if (self.code.?.len == 0) {
            self.stopped = true;
            return true;
        }

        var timer = try std.time.Timer.start();

        timer.reset();

        var exec: usize = 0;

        while (timer.read() < ns and !self.done() and !self.yield) {
            if (try self.runStep()) {
                self.stopped = true;
                return true;
            }

            exec += 1;
        }

        self.last_exec = exec;
        self.yield = false;

        return self.done();
    }

    pub fn runNum(self: *VM, num: u64) !bool {
        for (0..num) |_| {
            if (self.runStep() catch |err| {
                return err;
            }) {
                return true;
            }
        }

        return self.done();
    }

    pub fn markData(self: *VM) !void {
        for (self.stack[0..self.rsp]) |entry| {
            try entry.mark();
        }
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
