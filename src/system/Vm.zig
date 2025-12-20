const std = @import("std");
const builtin = @import("builtin");
const c = @import("../c.zig");

const system = @import("../system.zig");
const windows = @import("../windows.zig");
const states = @import("../states.zig");
const events = @import("../events.zig");
const util = @import("../util.zig");

const Stream = system.Stream;
const syscalls = system.syscalls;
const telem = system.telem;
const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;
const system_events = events.system;

const Windowed = states.Windowed;

const Rope = util.Rope;
const log = util.log;

pub const Operation = @import("Vm/Operation.zig");
pub const Manager = @import("Vm/Manager.zig");
pub const Pool = @import("Vm/Pool.zig");

pub const MAIN_NAME = "_main";
pub const EXIT_NAME = "_quit";

// TODO: move stack stuff to settings?
const STACK_MAX = 2048;
const RET_STACK_MAX = 256;

pub const VmError = error{
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
    InvalidAddr,

    NotImplemented,
    UnknownFunction,
    Todo,
} || Stream.StreamError;

const StackEntryKind = enum {
    string,
    value,
};

pub const HeapEntry = union(StackEntryKind) {
    string: Rope,
    value: u64,
};

pub const RetStackEntry = struct {
    function: ?[]const u8,
    location: usize,
};

pub const VmFunc = struct {
    string: []const u8,
    ops: []Operation,
};

const Vm = @This();

allocator: std.mem.Allocator,
stack: [STACK_MAX]Pool.ObjectRef = undefined,
return_stack: [RET_STACK_MAX]RetStackEntry = undefined,

rsp: usize = 0,
return_rsp: u8 = 0,

functions: std.StringHashMap(VmFunc),
inside_fn: ?[]const u8 = null,

yield_data: ?struct {
    check: *const fn (yield_self: *anyopaque, vm: *Vm) VmError!bool,
    deinit: *const fn (yield_self: *anyopaque, vm: *Vm) void,
    data: *anyopaque,
} = null,

pc: usize = 0,
code: ?[]const Operation = null,
stopped: bool = false,
yield: bool = false,
misc_data: std.StringHashMap([]const u8),
input: std.array_list.Managed(u8),
last_exec: usize = 0,

streams: std.array_list.Managed(?*Stream),

out: std.array_list.Managed(u8),
args: [][]const u8,
root: files.FolderLink,
heap: []HeapEntry,

name: []const u8,

checker: bool = false,

rnd: std.Random.DefaultPrng,

pub fn init(alloc: std.mem.Allocator, root: files.FolderLink, args: [][]const u8, comptime checker: bool) Vm {
    return .{
        .allocator = alloc,
        .streams = .init(alloc),
        .functions = .init(alloc),
        .misc_data = .init(alloc),
        .out = .init(alloc),
        .input = .init(alloc),
        .heap = &.{},
        .args = args,
        .root = root,
        .checker = checker,
        .name = args[0],
        .rnd = std.Random.DefaultPrng.init(0),
    };
}

pub inline fn yieldUntil(self: *Vm, comptime T: type, child: T) !void {
    const data = try self.allocator.create(T);
    data.* = child;

    const generic_yielder = struct {
        fn checkImpl(pointer: *anyopaque, vm: *Vm) VmError!bool {
            const yield_self: *T = @ptrCast(@alignCast(pointer));

            return @call(.always_inline, T.check, .{ yield_self, vm });
        }

        fn deinitImpl(pointer: *anyopaque, vm: *Vm) void {
            const yield_self: *T = @ptrCast(@alignCast(pointer));

            vm.allocator.destroy(yield_self);
        }
    };

    self.yield_data = .{
        .check = &generic_yielder.checkImpl,
        .deinit = &generic_yielder.deinitImpl,
        .data = @ptrCast(data),
    };

    self.yield = true;
}

pub inline fn pushStack(self: *Vm, entry: Pool.ObjectRef) VmError!void {
    if (self.rsp == STACK_MAX) return error.StackOverflow;
    self.stack[self.rsp] = entry;
    self.rsp += 1;
}

pub inline fn pushStackI(self: *Vm, value: u64) VmError!void {
    if (self.rsp == STACK_MAX) return error.StackOverflow;

    self.stack[self.rsp] = try Pool.new(.{ .value = value });
    self.rsp += 1;
}

pub inline fn pushStackS(self: *Vm, string: Rope) VmError!void {
    if (self.rsp == STACK_MAX) return error.StackOverflow;

    self.stack[self.rsp] = try Pool.new(.{ .string = string });
    self.rsp += 1;
}

pub inline fn popStack(self: *Vm) VmError!Pool.ObjectRef {
    if (self.rsp == 0) return error.StackUnderflow;
    self.rsp -= 1;
    return self.stack[self.rsp];
}

pub inline fn findStack(self: *Vm, idx: u64) VmError!Pool.ObjectRef {
    if (self.rsp <= idx) return error.StackUnderflow;
    return self.stack[self.rsp - 1 - @as(usize, @intCast(idx))];
}

pub inline fn replaceStack(self: *Vm, a: Pool.ObjectRef, b: Pool.ObjectRef) VmError!void {
    for (self.stack[0..self.rsp]) |*entry| {
        if (entry.*.id == a.id) {
            entry.* = b;
        }
    }
}

pub fn getMetaUsage(self: *Vm) !usize {
    var result = self.rsp;
    result += self.return_rsp;
    result += self.heap.len;

    return result;
}

pub fn deinit(self: *Vm) void {
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
        if (stream) |strm|
            strm.deinit();
    }

    for (self.args) |*item|
        self.allocator.free(item.*);

    for (self.heap) |item|
        switch (item) {
            .string => |v| v.deinit(),
            else => {},
        };

    var misc_iter = self.misc_data.iterator();

    while (misc_iter.next()) |entry|
        self.allocator.free(entry.value_ptr.*);

    self.allocator.free(self.args);
    self.allocator.free(self.heap);
    self.functions.deinit();
    self.misc_data.deinit();
    self.streams.deinit();
    self.out.deinit();
}

pub inline fn runOp(self: *Vm, op: Operation) VmError!void {
    telem.Telem.instance.instruction_calls += 1;

    self.pc += 1;

    switch (op.code) {
        .Nop => {},
        .Push => {
            if (op.string) |string| {
                try self.pushStackS(try .init(string));
            } else if (op.value) |value| {
                try self.pushStackI(value);
            } else {
                return error.NotImplemented;
            }
        },
        .Add => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;

            if (b.data().* == .string) {
                try self.pushStackS(try b.data().string.subString(a.data().value, null));

                return;
            }

            if (b.data().* == .value) {
                try self.pushStackI(a.data().value +% b.data().value);

                return;
            }
        },
        .Sub => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;

            if (b.data().* == .string) {
                try self.pushStackS(try b.data().string.subString(0, a.data().value));
                // if (b.data().string.len < a.data().value) {
                //     try self.pushStackS("");
                // } else {
                //     try self.pushStackS(b.data().string[0 .. b.data().string.len - a.data().value]);
                // }

                return;
            }

            if (b.data().* == .value) {
                try self.pushStackI(b.data().value -% a.data().value);
                return;
            }
        },
        .Size => {
            const a = try self.popStack();
            const b = try self.findStack(0);

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .string) return error.StringMissing;

            const old_rope = b.data().string;
            const old = try std.fmt.allocPrint(self.allocator, "{f}", .{old_rope});
            defer self.allocator.free(old);

            const new = try self.allocator.alloc(u8, a.data().value);
            defer self.allocator.free(new);

            const len = @min(old.len, new.len);
            @memcpy(new[0..len], old[0..len]);

            b.data().string = try .init(new);

            return;
        },
        .Len => {
            const a = try self.popStack();

            if (a.data().* != .string) return error.StringMissing;

            try self.pushStackI(a.data().string.len());

            return;
        },
        .Copy => {
            if (op.value == null) return error.ValueMissing;

            const a = try self.findStack(op.value.?);

            try self.pushStack(a);
        },
        .Dup => {
            if (op.value == null) return error.ValueMissing;

            const a = try self.findStack(op.value.?);

            if (a.data().* == .string) {
                try self.pushStackS(try .initRef(a.data().string));
                return;
            }

            if (a.data().* == .value) {
                try self.pushStackI(a.data().value);
                return;
            }
        },
        .Jmp => {
            if (op.value == null) return error.ValueMissing;

            self.pc = @as(usize, @intCast(op.value.?));
            return;
        },
        .Jz => {
            const a = try self.popStack();

            if (a.data().* == .string) {
                if (a.data().string.len() == 0) {
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
        .Jnz => {
            const a = try self.popStack();

            if (a.data().* == .string) {
                if (a.data().string.len() != 0) {
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
        .Sys => {
            if (op.value) |index| {
                syscalls.SysCall.run(self, index) catch |err| {
                    switch (err) {
                        error.InvalidSys => {
                            switch (index) {
                                // panic
                                128 => {
                                    if (builtin.is_test)
                                        return error.InvalidSys
                                    else if (!Windowed.global_self.debug_enabled)
                                        return error.InvalidSys
                                    else
                                        @panic("Vm Crash Called");
                                },
                                // secret
                                255 => {
                                    events.EventManager.instance.sendEvent(system_events.EventSys{
                                        .sysId = index,
                                    }) catch return error.InvalidSys;

                                    if (self.rsp == 0)
                                        return error.InvalidPassword;

                                    const pass = try self.popStack();

                                    if (pass.data().* != .string) return error.StringMissing;

                                    const input = try std.fmt.allocPrint(self.allocator, "{f}", .{pass.data().string});
                                    defer self.allocator.free(input);

                                    if (std.mem.eql(u8, input, "Hi")) {
                                        try self.out.appendSlice("Hello World!\n");

                                        return;
                                    }

                                    const dbg_pass = try telem.Telem.getDebugPassword();
                                    defer self.allocator.free(dbg_pass);

                                    if (std.mem.eql(u8, input, dbg_pass)) {
                                        try self.out.appendSlice("Debug Mode Enabled\n");

                                        events.EventManager.instance.sendEvent(system_events.EventDebugSet{
                                            .enabled = true,
                                        }) catch {
                                            return error.InvalidSys;
                                        };

                                        return;
                                    }

                                    log.warn("password dosent match {s}", .{dbg_pass});

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
        .Jmpf => {
            if (op.value == null) return error.ValueMissing;

            self.pc += @as(usize, @intCast(op.value.?));

            return;
        },
        .Mul => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            try self.pushStackI(a.data().value *% b.data().value);

            return;
        },
        .Div => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            if (a.data().value == 0) return error.DivZero;

            try self.pushStackI(b.data().value / a.data().value);

            return;
        },
        .Mod => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            if (a.data().value == 0) return error.DivZero;

            try self.pushStackI(b.data().value % a.data().value);

            return;
        },
        .And => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            try self.pushStackI(a.data().value & b.data().value);

            return;
        },
        .Or => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            try self.pushStackI(a.data().value | b.data().value);

            return;
        },
        .Neg => {
            const a = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;

            try self.pushStackI(0 -% a.data().value);

            return;
        },
        .Xor => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            try self.pushStackI(a.data().value ^ b.data().value);

            return;
        },
        .Not => {
            const a = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;

            const val: u64 = if (a.data().value == 0) 1 else 0;

            try self.pushStackI(val);

            return;
        },
        .Sin => {
            const a = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;

            const val: u64 = @as(u64, @intFromFloat((std.math.sin(@as(f32, @floatFromInt(a.data().value)) * (std.math.pi * 2) / 255) + 1.0) * 127.0));

            try self.pushStackI(val);

            return;
        },
        .Cos => {
            const a = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;

            const val: u64 = @as(u64, @intFromFloat((std.math.cos(@as(f32, @floatFromInt(a.data().value)) * (std.math.pi * 2) / 255) + 1.0) * 127.0));

            try self.pushStackI(val);

            return;
        },
        .Asign => {
            const a = try self.popStack();
            const b = try self.popStack();

            try self.pushStack(a);

            try self.replaceStack(b, a);

            return;
        },
        .Disc => {
            if (op.value == null) return error.ValueMissing;
            if (op.value.? > self.rsp) return error.StackUnderflow;

            switch (op.value.?) {
                0 => {
                    self.rsp -= 1;
                },
                else => {
                    const items = self.stack[self.rsp - @as(usize, @intCast(op.value.?)) .. self.rsp];
                    self.rsp -= @as(u8, @intCast(op.value.?)) + 1;
                    std.mem.copyForwards(Pool.ObjectRef, self.stack[self.rsp .. self.rsp + items.len], items);
                    self.rsp += items.len;
                },
            }
        },
        .Eq => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* == .string) {
                if (b.data().* == .string) {
                    const val: u64 = if (a.data().string.eql(b.data().string)) 1 else 0;
                    try self.pushStackI(val);
                } else if (b.data().* == .value) {
                    var val: u64 = 0;
                    if (!a.data().string.empty() and a.data().string.index(0) == @as(u8, @intCast(@mod(b.data().value, 256)))) val = 1;
                    if (a.data().string.empty() and b.data().value == 0) val = 1;
                    try self.pushStackI(val);
                }
            }

            if (a.data().* == .value) {
                if (b.data().* == .string) {
                    var val: u64 = 0;
                    if (!b.data().string.empty() and b.data().string.index(0) == @as(u8, @intCast(@mod(a.data().value, 256)))) val = 1;
                    if (b.data().string.empty() and a.data().value == 0) val = 1;
                    try self.pushStackI(val);
                } else if (b.data().* == .value) {
                    const val: u64 = if (a.data().value == b.data().value) 1 else 0;
                    try self.pushStackI(val);
                }
            }
        },
        .Less => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            const val: u64 = if (a.data().value > b.data().value) 1 else 0;
            try self.pushStackI(val);
            return;
        },
        .Greater => {
            const a = try self.popStack();
            const b = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;
            if (b.data().* != .value) return error.ValueMissing;

            const val: u64 = if (a.data().value < b.data().value) 1 else 0;
            try self.pushStackI(val);
            return;
        },
        .Getb => {
            const a = try self.popStack();

            if (a.data().* == .string) {
                if (a.data().string.index(0)) |ch| {
                    const val = @as(u64, @intCast(ch));
                    try self.pushStackI(val);
                } else {
                    try self.pushStackI(0);
                }
                return;
            }

            if (a.data().* == .value) {
                try self.pushStackS(try .init(std.mem.asBytes(&a.data().value)[0..1]));

                return;
            }
        },
        .Ret => {
            if (self.return_rsp == 0) return error.CallStackUnderflow;

            self.return_rsp -= 1;
            self.pc = @as(usize, @intCast(self.return_stack[self.return_rsp].location));
            self.inside_fn = self.return_stack[self.return_rsp].function;
            return;
        },
        .Call => {
            if (self.return_rsp >= self.return_stack.len - 1) return error.CallStackOverflow;

            if (op.string) |string| {
                self.return_stack[self.return_rsp].location = self.pc;
                self.return_stack[self.return_rsp].function = self.inside_fn;
                self.pc = 0;
                self.inside_fn = string;
                self.return_rsp += 1;

                return;
            }

            if (op.value) |value| {
                self.return_stack[self.return_rsp].location = self.pc;
                self.return_stack[self.return_rsp].function = self.inside_fn;
                self.pc = @as(usize, @intCast(value));
                self.return_rsp += 1;

                return;
            }

            const name = try self.popStack();

            if (name.data().* != .string) return error.StringMissing;

            self.return_stack[self.return_rsp].location = self.pc;
            self.return_stack[self.return_rsp].function = self.inside_fn;
            self.pc = 0;

            const name_value = try std.fmt.allocPrint(self.allocator, "{f}", .{name.data().string});
            defer self.allocator.free(name_value);

            if (self.functions.getEntry(name_value)) |entry| {
                self.inside_fn = entry.key_ptr.*;
            } else return error.FunctionMissing;

            self.return_rsp += 1;
        },
        .Cat => {
            const b = try self.popStack();
            const a = try self.popStack();

            log.info("{any}", .{a});

            if (a.data().* != .string) return error.StringMissing;

            if (b.data().* == .string) {
                try self.pushStackS(try a.data().string.cat(b.data().string));
            } else if (b.data().* == .value) {
                const b_value = b.data();

                const b_item: Rope = try .init(std.mem.asBytes(&b_value.value));
                defer b_item.deinit();

                try self.pushStackS(try a.data().string.cat(b_item));
            }
        },
        .Create => {
            const b = try self.popStack();

            if (b.data().* != .value) return error.ValueMissing;

            const adds = try self.allocator.alloc(u8, b.data().value);
            defer self.allocator.free(adds);

            @memset(adds, 0);

            try self.pushStackS(try .init(adds));
        },
        .Random => {
            const val: u64 = self.rnd.random().int(u64);

            try self.pushStackI(val);
        },
        .Seed => {
            const seed = try self.popStack();

            if (seed.data().* != .value) return error.ValueMissing;

            self.rnd.seed(seed.data().value);
        },
        .Zero => {
            const b = try self.findStack(0);

            if (b.data().* != .string) return error.ValueMissing;

            const adds = try self.allocator.alloc(u8, b.data().string.len());
            defer self.allocator.free(adds);

            @memset(adds, 0);

            try self.pushStackS(try .init(adds));
        },
        .Mem => {
            const a = try self.popStack();

            if (a.data().* != .value) return error.ValueMissing;

            if (Pool.find(a.data().value)) |obj| {
                try self.pushStack(obj);
            } else {
                return error.InvalidAddr;
            }
        },
        .DiscN => {
            if (op.value == null) return error.ValueMissing;
            if (op.value.? > self.rsp) return error.StackUnderflow;

            const start = try self.popStack();

            if (start.data().* != .value) return error.ValueMissing;

            const start_v: usize = @intCast(start.data().value);
            if (op.value.? + start_v > self.rsp) return error.StackUnderflow;

            const items = self.stack[self.rsp - start_v .. self.rsp];
            self.rsp -= start_v;
            self.rsp -= op.value.?;

            std.mem.copyForwards(Pool.ObjectRef, self.stack[self.rsp .. self.rsp + items.len], items);
            self.rsp += items.len;
        },
        .Last => return error.InvalidOp,
        _ => return error.InvalidOp,
    }
}

pub fn loadList(self: *Vm, ops: []Operation) !void {
    const list = try self.allocator.alloc(Operation, ops.len);

    for (ops, 0..) |_, idx| {
        list[idx] = ops[idx];

        if (ops[idx].string) |string| {
            const str = try self.allocator.alloc(u8, string.len);

            for (string, 0..) |_, jdx| {
                str[jdx] = string[jdx];
            }

            list[idx].string = str;
        }
    }
    self.code = list;
}

pub fn stringToOps(self: *Vm, conts: []const u8) VmError!std.array_list.Managed(Operation) {
    var ops: std.array_list.Managed(Operation) = .init(self.allocator);
    errdefer {
        var tmp: std.array_list.Managed(u8) = .init(self.allocator);
        defer tmp.deinit();
        tmp.print("{{", .{}) catch unreachable;
        for (ops.items, 0..) |item, idx| {
            if (idx != 0)
                tmp.print(", ", .{}) catch unreachable;

            tmp.print("{f}", .{item}) catch unreachable;
        }
        tmp.print("}}", .{}) catch unreachable;

        log.warn("Vm ops failed at {s}", .{tmp.items});
        ops.deinit();
    }

    var parse_ptr: usize = 0;
    while (parse_ptr < conts.len) {
        if (parse_ptr >= conts.len) {
            return error.InvalidAsm;
        }
        const code: Operation.Code = std.meta.intToEnum(Operation.Code, conts[parse_ptr]) catch {
            std.log.warn("couldnt grab code", .{});
            return error.InvalidAsm;
        };
        parse_ptr += 1;
        if (parse_ptr >= conts.len) {
            std.log.warn("Half made op", .{});
            return error.InvalidAsm;
        }
        const kind = conts[parse_ptr];
        parse_ptr += 1;

        if (kind == 1) {
            if (parse_ptr + 7 >= conts.len) {
                return error.InvalidAsm;
            }
            const value = @as(u64, @bitCast(conts[parse_ptr..][0..8].*));

            parse_ptr += 8;

            try ops.append(Vm.Operation{ .code = code, .value = value });
        } else if (kind == 2) {
            var buff_ptr: usize = 0;
            while (parse_ptr + buff_ptr < conts.len and conts[parse_ptr + buff_ptr] != 0) {
                buff_ptr += 1;
                if (buff_ptr + parse_ptr >= conts.len) {
                    return error.InvalidAsm;
                }
            }
            try ops.append(Vm.Operation{ .code = code, .string = conts[parse_ptr .. parse_ptr + buff_ptr] });
            parse_ptr += buff_ptr + 1;
        } else if (kind == 3) {
            if (parse_ptr >= conts.len) {
                return error.InvalidAsm;
            }
            const value = conts[parse_ptr];
            parse_ptr += 1;

            try ops.append(Vm.Operation{ .code = code, .value = @as(u64, @intCast(value)) });
        } else if (kind == 0) {
            try ops.append(Vm.Operation{ .code = code });
        } else {
            std.log.warn("Invalid op kind", .{});
            return error.InvalidAsm;
        }
    }

    return ops;
}

pub fn loadString(self: *Vm, conts: []const u8) !void {
    const ops = try self.stringToOps(conts);
    defer ops.deinit();

    try self.loadList(ops.items);
}

pub fn done(self: *Vm) bool {
    return self.code == null or self.stopped or (self.pc >= self.code.?.len and self.inside_fn == null);
}

pub fn backtrace(self: *Vm, i: u8) ![]const u8 {
    if (i == 0)
        return try std.fmt.allocPrint(self.allocator, "{}: {s} {}", .{ i, self.inside_fn orelse MAIN_NAME, self.pc });

    const bt = try self.backtrace(i - 1);
    defer self.allocator.free(bt);

    return try std.fmt.allocPrint(self.allocator, "{}: {s} {}\n{s}", .{ i, self.return_stack[i - 1].function orelse MAIN_NAME, self.return_stack[i - 1].location, bt });
}

pub fn getOp(self: *Vm) ![]u8 {
    const bt = try self.backtrace(self.return_rsp);
    defer self.allocator.free(bt);

    const oper = if (self.inside_fn) |inside|
        if (self.functions.getPtr(inside)) |func|
            func.*.ops[self.pc - 1]
        else {
            return try std.fmt.allocPrint(
                self.allocator,
                "In function '{s}?' @ {}:\n  Operation: ?\n\n{s}",
                .{ self.inside_fn orelse MAIN_NAME, self.pc, bt },
            );
        }
    else if (self.code) |code|
        if (self.pc != 0)
            code[self.pc - 1]
        else
            Operation{ .code = .Nop }
    else
        Operation{ .code = .Nop };

    return try std.fmt.allocPrint(
        self.allocator,
        "In function '{s}' @ {}:\n  Operation: {f}\n{s}",
        .{ self.inside_fn orelse MAIN_NAME, self.pc, oper, bt },
    );
}

pub fn getOper(self: *Vm) !?Operation {
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
        return if (self.code) |code|
            if (code.len <= self.pc)
                null
            else
                code[self.pc]
        else
            null;
    }

    return null;
}

pub fn runStep(self: *Vm) !bool {
    const oper = try self.getOper() orelse return true;

    try self.runOp(oper);

    std.Thread.yield() catch {};

    return self.done();
}

pub fn runAll(self: *Vm) !void {
    while (!try self.runStep()) {}
}

pub fn runTime(self: *Vm, ns: u64, comptime _: bool) !bool {
    if (self.code == null) return error.InvalidASM;

    if (self.code.?.len == 0) {
        self.stopped = true;
        return true;
    }

    if (self.yield_data) |yield_data| {
        if (try yield_data.check(yield_data.data, self)) {
            yield_data.deinit(yield_data.data, self);

            self.yield_data = null;
        } else return self.done();
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

pub fn runNum(self: *Vm, num: u64) !bool {
    for (0..num) |_| {
        if (self.runStep() catch |err| {
            return err;
        }) {
            return true;
        }
    }

    return self.done();
}

pub fn markData(self: *Vm) !void {
    for (self.stack[0..self.rsp]) |entry| {
        try entry.mark();
    }
}

test "Vm Compile bad returns error" {
    const cmd_args = try std.testing.allocator.dupe(u8, "test");
    const vm_args = try std.testing.allocator.dupe([]const u8, &.{cmd_args});

    var vm = Vm.init(std.testing.allocator, .root, vm_args, false);
    defer vm.deinit();

    try std.testing.expectError(error.InvalidAsm, vm.stringToOps("\x00"));
    try std.testing.expectError(error.InvalidAsm, vm.stringToOps("\x00\x02\x01"));
    try std.testing.expectError(error.InvalidAsm, vm.stringToOps("\x00\x01\x01"));
    try std.testing.expectError(error.InvalidAsm, vm.stringToOps("\x00\x03"));
}

test "Vm input fuzzing" {
    const Context = struct {
        vm: *Vm,

        fn testStringToOps(context: @This(), input: []const u8) anyerror!void {
            (context.vm.stringToOps(input) catch |err| switch (err) {
                error.InvalidAsm => return,
                else => |e| return e,
            }).deinit();
        }
    };

    const cmd_args = try std.testing.allocator.dupe(u8, "test");
    const vm_args = try std.testing.allocator.dupe([]const u8, &.{cmd_args});

    var vm = Vm.init(std.testing.allocator, .root, vm_args, false);
    defer vm.deinit();

    try std.testing.fuzz(Context{ .vm = &vm }, Context.testStringToOps, .{});
}
