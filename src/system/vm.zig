const std = @import("std");
const streams = @import("stream.zig");
const files = @import("files.zig");
const telem = @import("telem.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const windowedState = @import("../states/windowed.zig");

// TODO: move stack stuff to settings?
const STACK_MAX = 2048;
const RET_STACK_MAX = 256;
const MAIN_NAME = "_main";
const EXIT_NAME = "_quit";

pub var syslock = std.Thread.Mutex{};

pub const VM = struct {
    const VMError = error{
        Memory,
        StackUnderflow,
        StackOverflow,
        CallStackUnderflow,
        CallStackOverflow,
        HeapOutOfBounds,
        ValueMissing,
        StringMissing,
        InvalidOp,
        InvalidSys,
        InvalidPassword,
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

    pub const HeapEntry = union(StackEntryKind) {
        string: []u8,
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
    stack: [STACK_MAX]StackEntry,
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

        var tmpArgs = alloc.alloc([]u8, std.mem.count(u8, args, " ") + 1) catch return error.Memory;

        var idx: usize = 0;
        while (splitIter.next()) |item| : (idx += 1)
            tmpArgs[idx] = alloc.dupe(u8, item) catch return error.Memory;

        return VM{
            .stack = undefined,
            .allocator = alloc,
            .streams = std.ArrayList(?*streams.FileStream).init(alloc),
            .functions = std.StringHashMap(VMFunc).init(alloc),
            .miscData = std.StringHashMap([]const u8).init(alloc),
            .out = std.ArrayList(u8).init(alloc),
            .input = std.ArrayList(u8).init(alloc),
            .heap = alloc.alloc(HeapEntry, 0) catch return error.Memory,
            .args = tmpArgs,
            .root = root,
            .checker = checker,
            .name = alloc.dupe(u8, tmpArgs[0]) catch return error.Memory,
            .rnd = std.rand.DefaultPrng.init(0),
        };
    }

    inline fn pushStack(self: *VM, entry: StackEntry) VMError!void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        self.stack[self.rsp] = entry;
        self.rsp += 1;
    }

    inline fn pushStackI(self: *VM, value: u64) VMError!void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        const val = self.allocator.create(u64) catch return error.Memory;
        val.* = value;

        self.stack[self.rsp] = StackEntry{ .value = val };
        self.rsp += 1;
    }

    inline fn pushStackS(self: *VM, string: []const u8) VMError!void {
        if (self.rsp == STACK_MAX) return error.StackOverflow;
        const appendString = self.allocator.create([]u8) catch return error.Memory;

        appendString.* = self.allocator.dupe(u8, string) catch return error.Memory;

        self.stack[self.rsp] = StackEntry{ .string = appendString };
        self.rsp += 1;
    }

    pub inline fn popStack(self: *VM) VMError!StackEntry {
        if (self.rsp == 0) return error.StackUnderflow;
        self.rsp -= 1;
        return self.stack[self.rsp];
    }

    inline fn findStack(self: *VM, idx: u64) VMError!StackEntry {
        if (self.rsp <= idx) return error.StackUnderflow;
        return self.stack[self.rsp - 1 - @as(usize, @intCast(idx))];
    }

    inline fn replaceStack(self: *VM, a: StackEntry, b: StackEntry) VMError!void {
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
            Random,
            Seed,

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
        const oldrsp = self.rsp;
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

    pub inline fn freeValue(self: *VM, val: *u64) void {
        if (self.rsp != 0) {
            for (self.stack[0..self.rsp]) |entry| {
                if (entry == .value and entry.value == val) {
                    return;
                }
            }
        }
        self.allocator.destroy(val);
    }

    pub inline fn freeString(self: *VM, val: *[]const u8) void {
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

    pub fn free(self: *VM, vals: []const StackEntry) void {
        switch (vals.len) {
            0 => return,
            1 => {
                switch (vals[0]) {
                    .value => self.freeValue(vals[0].value),
                    .string => self.freeString(vals[0].string),
                }
            },
            else => {
                const toFree = self.allocator.alloc(StackEntry, vals.len) catch return;
                defer self.allocator.free(toFree);

                var idx: usize = 0;

                for (vals) |val| {
                    for (0..idx) |index| {
                        if ((val == .string and toFree[index] == .string and toFree[index].string == val.string) or
                            (val == .value and toFree[index] == .value and toFree[index].value == val.value))
                        {
                            break;
                        }
                    } else {
                        toFree[idx] = val;
                        idx += 1;
                    }
                }

                for (toFree[0..idx]) |val| {
                    switch (val) {
                        .value => self.freeValue(val.value),
                        .string => self.freeString(val.string),
                    }
                }
            },
        }
    }

    pub inline fn runOp(self: *VM, op: Operation) !void {
        telem.Telem.instance.instructionCalls += 1;

        //std.log.info("{}", .{op});

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
                defer self.free(&[_]StackEntry{ b, a });

                if (a != .value) return error.ValueMissing;

                if (b == .string) {
                    if (b.string.len < a.value.*) {
                        try self.pushStackS("");
                    } else {
                        try self.pushStackS(b.string.*[@as(usize, @intCast(a.value.*))..]);
                    }
                    return;
                }

                if (b == .value) {
                    try self.pushStackI(a.value.* +% b.value.*);
                    return;
                }
            },
            Operation.Code.Sub => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a != .value) return error.ValueMissing;

                if (b == .string) {
                    if (b.string.len < a.value.*) {
                        try self.pushStackS("");
                    } else {
                        try self.pushStackS(b.string.*[0..@as(usize, @intCast(b.string.*.len - a.value.*))]);
                    }
                    return;
                }

                if (b == .value) {
                    try self.pushStackI(b.value.* -% a.value.*);
                    return;
                }
            },
            Operation.Code.Size => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ b, a });

                if (a != .value) return error.ValueMissing;
                if (b != .string) return error.StringMissing;

                if (b.string.len < a.value.*) {
                    try self.pushStackS(b.string.*);
                } else {
                    try self.pushStackS(b.string.*[0..@as(usize, @intCast(a.value.*))]);
                }
                return;
            },
            Operation.Code.Len => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .string) return error.StringMissing;

                try self.pushStackI(a.string.len);

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

                self.pc = @as(usize, @intCast(op.value.?));
                return;
            },
            Operation.Code.Jz => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a == .string) {
                    if (a.string.len == 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }

                if (a == .value) {
                    if (a.value.* == 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }
            },
            Operation.Code.Jnz => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a == .string) {
                    if (a.string.len != 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }

                if (a == .value) {
                    if (a.value.* != 0) {
                        self.pc = @as(usize, @intCast(op.value.?));
                    }
                    return;
                }
            },
            Operation.Code.Sys => {
                //syslock.lock();
                //defer syslock.unlock();

                if (op.value != null) {
                    try events.EventManager.instance.sendEvent(systemEvs.EventSys{
                        .sysId = op.value.?,
                    });
                    switch (op.value.?) {
                        // print
                        0 => {
                            const a = try self.popStack();
                            defer self.free(&[_]StackEntry{a});

                            if (a == .string) {
                                try self.out.appendSlice(a.string.*);

                                return;
                            }

                            if (a == .value) {
                                const str = try std.fmt.allocPrint(self.allocator, "{}", .{a.value.*});
                                defer self.allocator.free(str);

                                try self.out.appendSlice(str);

                                return;
                            }
                        },
                        // quit
                        1 => {
                            if (self.functions.contains(EXIT_NAME)) {
                                if (self.inside_fn) |func| {
                                    if (std.mem.eql(u8, func, EXIT_NAME)) {
                                        self.stopped = true;
                                        return;
                                    }
                                }
                                self.retStack[self.retRsp].location = self.pc;
                                self.retStack[self.retRsp].function = self.inside_fn;
                                self.pc = 0;
                                self.inside_fn = EXIT_NAME;
                                self.retRsp += 1;

                                return;
                            }

                            self.stopped = true;
                            return;
                        },
                        // create file
                        2 => {
                            const path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});

                            if (path != .string) return error.StringMissing;

                            if (path.string.len > 0 and path.string.*[0] == '/') {
                                _ = try files.root.newFile(path.string.*);
                            } else {
                                _ = try self.root.newFile(path.string.*);
                            }

                            return;
                        },
                        // open file
                        3 => {
                            const path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});

                            if (path != .string) return error.StringMissing;

                            try self.streams.append(try streams.FileStream.Open(self.root, path.string.*, self));
                            try self.pushStackI(self.streams.items.len - 1);

                            return;
                        },
                        // read
                        4 => {
                            const len = try self.popStack();
                            const idx = try self.popStack();
                            defer self.free(&[_]StackEntry{ len, idx });

                            if (len != .value) return error.ValueMissing;
                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;

                            const fs = self.streams.items[@as(usize, @intCast(idx.value.*))];
                            if (fs == null) return error.InvalidStream;

                            const cont = try fs.?.Read(@as(u32, @intCast(len.value.*)));
                            defer self.allocator.free(cont);

                            try self.pushStackS(cont);

                            return;
                        },
                        // write file
                        5 => {
                            if (self.checker) return;
                            const str = try self.popStack();
                            const idx = try self.popStack();
                            defer self.free(&[_]StackEntry{ str, idx });

                            if (str != .string) return error.StringMissing;
                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;

                            const fs = self.streams.items[@as(usize, @intCast(idx.value.*))];
                            if (fs == null) return error.InvalidStream;

                            try fs.?.Write(str.string.*);

                            return;
                        },
                        // flush file
                        6 => {
                            if (self.checker) return;
                            const idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;
                            const fs = self.streams.items[@as(usize, @intCast(idx.value.*))];
                            if (fs == null) return error.InvalidStream;

                            try fs.?.Flush();

                            return;
                        },
                        // close file
                        7 => {
                            const idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.streams.items.len) return error.InvalidStream;
                            const fs = self.streams.items[@as(usize, @intCast(idx.value.*))];
                            if (fs == null) return error.InvalidStream;

                            try fs.?.Close();
                            self.streams.items[@as(usize, @intCast(idx.value.*))] = null;

                            return;
                        },
                        // arg
                        8 => {
                            const idx = try self.popStack();
                            defer self.free(&[_]StackEntry{idx});

                            if (idx != .value) return error.ValueMissing;

                            if (idx.value.* >= self.args.len) {
                                try self.pushStackS("");
                                return;
                            }

                            try self.pushStackS(self.args[@as(usize, @intCast(idx.value.*))]);

                            return;
                        },
                        // time
                        9 => {
                            try self.pushStackI(@as(u64, @intCast(std.time.milliTimestamp())));

                            return;
                        },
                        // checkfn
                        10 => {
                            const name = try self.popStack();
                            defer self.free(&[_]StackEntry{name});

                            if (name != .string) return error.StringMissing;

                            const val: u64 = if (self.functions.contains(name.string.*)) 1 else 0;

                            try self.pushStackI(val);

                            return;
                        },
                        // getfn
                        11 => {
                            const name = try self.popStack();
                            defer self.free(&[_]StackEntry{name});

                            if (name != .string) return error.StringMissing;

                            var val: []const u8 = "";

                            if (self.functions.get(name.string.*)) |newVal| val = newVal.string;

                            try self.pushStackS(val);

                            return;
                        },
                        // regfn
                        12 => {
                            const name = try self.popStack();
                            const func = try self.popStack();
                            defer self.free(&[_]StackEntry{ name, func });

                            if (func != .string) return error.StringMissing;
                            if (name != .string) return error.StringMissing;

                            const dup = try self.allocator.dupe(u8, func.string.*);

                            const ops = try self.stringToOps(dup);
                            defer ops.deinit();

                            const finalOps = try self.allocator.dupe(Operation, ops.items);
                            const finalName = try self.allocator.dupe(u8, name.string.*);

                            if (self.functions.fetchRemove(finalName)) |entry| {
                                self.allocator.free(entry.key);
                                self.allocator.free(entry.value.ops);
                                self.allocator.free(entry.value.string);
                            }

                            try self.functions.put(finalName, .{
                                .string = dup,
                                .ops = finalOps,
                            });

                            return;
                        },
                        // clear function
                        13 => {
                            const name = try self.popStack();
                            defer self.free(&[_]StackEntry{name});

                            if (name != .string) return error.StringMissing;

                            if (self.functions.fetchRemove(name.string.*)) |entry| {
                                self.allocator.free(entry.key);
                                self.allocator.free(entry.value.ops);
                                self.allocator.free(entry.value.string);
                                return;
                            }

                            return error.FunctionMissing;
                        },
                        // resize heap
                        14 => {
                            const size = try self.popStack();
                            defer self.free(&[_]StackEntry{size});

                            if (size != .value) return error.ValueMissing;

                            const start = self.heap.len;
                            self.heap = try self.allocator.realloc(self.heap, @intCast(size.value.*));

                            if (start < self.heap.len) {
                                for (start..self.heap.len) |idx| {
                                    self.heap[idx] = .{ .value = 0 };
                                }
                            }

                            return;
                        },
                        // read heap
                        15 => {
                            const item = try self.popStack();
                            defer self.free(&[_]StackEntry{item});

                            if (item != .value) return error.ValueMissing;
                            if (item.value.* >= self.heap.len) return error.HeapOutOfBounds;

                            const adds = self.heap[@as(usize, @intCast(item.value.*))];

                            switch (adds) {
                                .value => {
                                    try self.pushStackI(adds.value);
                                },
                                .string => {
                                    try self.pushStackS(adds.string);
                                },
                            }

                            return;
                        },
                        // write heap
                        16 => {
                            const data = try self.popStack();
                            const item = try self.popStack();
                            defer self.free(&[_]StackEntry{ data, item });

                            if (item != .value) return error.ValueMissing;

                            if (item.value.* >= self.heap.len) return error.HeapOutOfBounds;

                            const idx: usize = @intCast(item.value.*);

                            if (self.heap[idx] == .string)
                                self.allocator.free(self.heap[idx].string);

                            switch (data) {
                                .value => {
                                    self.heap[idx] = .{
                                        .value = data.value.*,
                                    };
                                },
                                .string => {
                                    self.heap[idx] = .{
                                        .string = self.allocator.dupe(u8, data.string.*) catch return error.Memory,
                                    };
                                },
                            }

                            try self.pushStack(data);

                            return;
                        },
                        // yield
                        17 => {
                            self.yield = true;
                            return;
                        },
                        // error
                        18 => {
                            const msg = try self.popStack();
                            defer self.free(&[_]StackEntry{msg});

                            if (msg != .string) return error.StringMissing;

                            const msgString = try self.getOp();
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
                            const path = try self.popStack();
                            defer self.free(&[_]StackEntry{path});

                            if (path != .string) return error.StringMissing;

                            if (path.string.len == 0) return error.FileMissing;

                            if (path.string.*[0] == '/') {
                                const file = try files.root.getFile(path.string.*);

                                try self.pushStackI(file.size());

                                return;
                            }

                            const file = try self.root.getFile(path.string.*);

                            try self.pushStackI(file.size());

                            return;
                        },
                        // setrsp
                        20 => {
                            const num = try self.popStack();
                            defer self.free(&[_]StackEntry{num});

                            if (num != .value) return error.ValueMissing;
                            if (self.rsp < num.value.*) return error.InvalidValue;

                            const oldRsp = self.rsp;

                            self.rsp = num.value.*;

                            self.free(self.stack[self.rsp..oldRsp]);

                            return;
                        },
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
                            if (self.rsp == 0)
                                return error.InvalidPassword;

                            const pass = try self.popStack();
                            defer self.free(&[_]StackEntry{pass});

                            if (pass != .string) return error.StringMissing;

                            if (std.mem.eql(u8, pass.string.*, "Hi")) {
                                try self.out.appendSlice("Hello World!\n");

                                return;
                            }

                            if (std.mem.eql(u8, pass.string.*, "Poopie")) {
                                try self.out.appendSlice("Debug Mode Enabled\n");

                                try events.EventManager.instance.sendEvent(systemEvs.EventDebugSet{
                                    .enabled = true,
                                });

                                return;
                            }

                            return error.InvalidPassword;
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
                self.pc += @as(usize, @intCast(op.value.?));
                return;
            },
            Operation.Code.Mul => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* *% b.value.*);

                return;
            },
            Operation.Code.Div => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                if (a.value.* == 0) return error.DivZero;

                try self.pushStackI(b.value.* / a.value.*);

                return;
            },
            Operation.Code.Mod => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                if (a.value.* == 0) return error.DivZero;

                try self.pushStackI(b.value.* % a.value.*);

                return;
            },
            Operation.Code.And => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* & b.value.*);

                return;
            },
            Operation.Code.Or => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* | b.value.*);

                return;
            },
            Operation.Code.Neg => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                try self.pushStackI(0 -% a.value.*);

                return;
            },
            Operation.Code.Xor => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                try self.pushStackI(a.value.* ^ b.value.*);

                return;
            },
            Operation.Code.Not => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                const val: u64 = if (a.value.* == 0) 1 else 0;

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Sin => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                const val: u64 = @as(u64, @intFromFloat((std.math.sin(@as(f32, @floatFromInt(a.value.*)) * (std.math.pi * 2) / 255) + 1.0) * 127.0));

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Cos => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a != .value) return error.ValueMissing;

                const val: u64 = @as(u64, @intFromFloat((std.math.cos(@as(f32, @floatFromInt(a.value.*)) * (std.math.pi * 2) / 255) + 1.0) * 127.0));

                try self.pushStackI(val);

                return;
            },
            Operation.Code.Asign => {
                const a = try self.popStack();
                const b = try self.popStack();

                defer self.free(&[_]StackEntry{ b, a });

                try self.pushStack(a);

                try self.replaceStack(b, a);

                return;
            },
            Operation.Code.Disc => {
                if (op.value == null) return error.ValueMissing;

                if (op.value.? > self.rsp) return error.StackUnderflow;

                switch (op.value.?) {
                    0 => {
                        const disc = try self.popStack();
                        defer self.free(&[_]StackEntry{disc});
                    },
                    else => {
                        const items = self.stack[self.rsp - @as(usize, @intCast(op.value.?)) .. self.rsp];
                        self.rsp -= @as(u8, @intCast(op.value.?));
                        const disc = try self.popStack();
                        defer self.free(&[_]StackEntry{disc});

                        std.mem.copyForwards(StackEntry, self.stack[self.rsp .. self.rsp + items.len], items);
                        self.rsp += items.len;
                    },
                }

                return;
            },
            Operation.Code.Eq => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a == .string) {
                    if (b == .string) {
                        const val: u64 = if (std.mem.eql(u8, a.string.*, b.string.*)) 1 else 0;
                        try self.pushStackI(val);
                        return;
                    }

                    if (b == .value) {
                        var val: u64 = 0;
                        if (a.string.*.len != 0 and a.string.*[0] == @as(u8, @intCast(b.value.*))) val = 1;
                        if (a.string.*.len == 0 and 0 == b.value.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    }
                }

                if (a == .value) {
                    if (b == .string) {
                        var val: u64 = 0;
                        if (b.string.*.len != 0 and b.string.*[0] == @as(u8, @intCast(a.value.*))) val = 1;
                        if (b.string.*.len == 0 and 0 == a.value.*) val = 1;
                        try self.pushStackI(val);
                        return;
                    }

                    if (b == .value) {
                        const val: u64 = if (a.value.* == b.value.*) 1 else 0;
                        try self.pushStackI(val);
                        return;
                    }
                }
            },
            Operation.Code.Less => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                const val: u64 = if (a.value.* > b.value.*) 1 else 0;
                try self.pushStackI(val);
                return;
            },
            Operation.Code.Greater => {
                const a = try self.popStack();
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{ a, b });

                if (a != .value) return error.ValueMissing;
                if (b != .value) return error.ValueMissing;

                const val: u64 = if (a.value.* < b.value.*) 1 else 0;
                try self.pushStackI(val);
                return;
            },
            Operation.Code.Getb => {
                const a = try self.popStack();
                defer self.free(&[_]StackEntry{a});

                if (a == .string) {
                    if (a.string.len == 0) {
                        try self.pushStackI(0);
                    } else {
                        const val = @as(u64, @intCast(a.string.*[0]));
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
                defer self.free(&[_]StackEntry{name});

                if (name != .string) return error.StringMissing;

                self.retStack[self.retRsp].location = self.pc;
                self.retStack[self.retRsp].function = self.inside_fn;
                self.pc = 0;
                if (self.functions.getEntry(name.string.*)) |entry| {
                    self.inside_fn = entry.key_ptr.*;
                } else {
                    return error.FunctionMissing;
                }

                self.retRsp += 1;

                return;
            },
            Operation.Code.Cat => {
                const b = try self.popStack();
                const a = try self.popStack();

                defer self.free(&[_]StackEntry{ b, a });

                if (a != .string) return error.StringMissing;

                if (b == .string) {
                    const appends = try std.mem.concat(self.allocator, u8, &.{ a.string.*, b.string.* });
                    defer self.allocator.free(appends);

                    try self.pushStackS(appends);

                    return;
                }

                if (b == .value) {
                    const appends = try std.mem.concat(self.allocator, u8, &.{ a.string.*, std.mem.asBytes(b.value) });
                    defer self.allocator.free(appends);

                    try self.pushStackS(appends);

                    return;
                }
            },
            .Create => {
                const b = try self.popStack();
                defer self.free(&[_]StackEntry{b});

                if (b != .value) return error.ValueMissing;

                const adds = try self.allocator.alloc(u8, @as(usize, @intCast(b.value.*)));
                defer self.allocator.free(adds);
                @memset(adds, 0);
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
                defer self.free(&[_]StackEntry{seed});

                if (seed != .value) return error.ValueMissing;

                self.rnd.seed(seed.value.*);

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

    pub fn stringToOps(self: *VM, conts: []const u8) !std.ArrayList(Operation) {
        var ops = std.ArrayList(Operation).init(self.allocator);

        var parsePtr: usize = 0;
        while (parsePtr < conts.len) {
            if (parsePtr >= conts.len) {
                ops.deinit();
                return error.InvalidAsm;
            }
            const code: Operation.Code = try std.meta.intToEnum(Operation.Code, conts[parsePtr]);
            parsePtr += 1;
            if (parsePtr >= conts.len) {
                ops.deinit();
                return error.InvalidAsm;
            }
            const kind = conts[parsePtr];
            parsePtr += 1;

            if (kind == 1) {
                if (parsePtr + 7 >= conts.len) {
                    ops.deinit();
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
                const value = conts[parsePtr];
                parsePtr += 1;

                try ops.append(VM.Operation{ .code = code, .value = @as(u64, @intCast(value)) });
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
            std.log.err("'{s}', {any}", .{ inside, self.functions.get(inside) });
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

        try events.EventManager.instance.sendEvent(systemEvs.EventTelemUpdate{});

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
