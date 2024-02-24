const std = @import("std");
const vm = @import("vm.zig");
const files = @import("files.zig");
const streams = @import("stream.zig");
const vmManager = @import("vmmanager.zig");

const VMError = vm.VM.VMError;
const StackEntry = vm.VM.StackEntry;
const Operation = vm.VM.Operation;

pub const SysCall = struct {
    const Self = @This();

    const SYS_CALLS = [_]Self{
        // System ops
        .{ .runFn = sysPrint },
        .{ .runFn = sysQuit },

        // File ops
        .{ .runFn = sysCreate },
        .{ .runFn = sysOpen },
        .{ .runFn = sysRead },
        .{ .runFn = sysWrite },
        .{ .runFn = sysFlush },
        .{ .runFn = sysClose },

        // more system ops
        .{ .runFn = sysArg },
        .{ .runFn = sysTime },

        // function ops
        .{ .runFn = sysCheckFunc },
        .{ .runFn = sysGetFunc },
        .{ .runFn = sysRegFunc },
        .{ .runFn = sysClearFunc },

        // heap ops
        .{ .runFn = sysResizeHeap },
        .{ .runFn = sysReadHeap },
        .{ .runFn = sysWriteHeap },

        // more system ops
        .{ .runFn = sysYield },
        .{ .runFn = sysError },

        // more file ops
        .{ .runFn = sysSize },

        // more system ops
        .{ .runFn = sysRSP },
        .{ .runFn = sysSpawn },
        .{ .runFn = sysStatus },
    };

    runFn: *const fn (*vm.VM) VMError!void,

    pub fn run(self: *vm.VM, index: u64) VMError!void {
        if (index < SYS_CALLS.len) {
            return SYS_CALLS[index].runFn(self);
        }

        return error.InvalidSys;
    }
};

fn sysPrint(self: *vm.VM) VMError!void {
    const a = try self.popStack();
    defer self.free(&[_]StackEntry{a});

    if (a == .string) {
        try self.out.appendSlice(a.string.items);
    } else if (a == .value) {
        const str = try std.fmt.allocPrint(self.allocator, "{}", .{a.value.*});
        defer self.allocator.free(str);

        try self.out.appendSlice(str);
    }
}

fn sysQuit(self: *vm.VM) VMError!void {
    if (self.functions.contains(vm.EXIT_NAME)) {
        if (self.inside_fn) |func| {
            if (std.mem.eql(u8, func, vm.EXIT_NAME)) {
                self.stopped = true;
                return;
            }
        }
        self.retStack[self.retRsp].location = self.pc;
        self.retStack[self.retRsp].function = self.inside_fn;
        self.pc = 0;
        self.inside_fn = vm.EXIT_NAME;
        self.retRsp += 1;

        return;
    }

    self.stopped = true;
}

fn sysCreate(self: *vm.VM) VMError!void {
    const path = try self.popStack();
    defer self.free(&[_]StackEntry{path});

    if (path != .string) return error.StringMissing;

    if (path.string.items.len > 0 and path.string.items[0] == '/') {
        _ = try files.root.newFile(path.string.items);
    } else {
        _ = try self.root.newFile(path.string.items);
    }
}

fn sysOpen(self: *vm.VM) VMError!void {
    const path = try self.popStack();
    defer self.free(&[_]StackEntry{path});

    if (path != .string) return error.StringMissing;

    const stream = try streams.FileStream.Open(self.root, path.string.items, self);

    try self.streams.append(stream);
    try self.pushStackI(self.streams.items.len - 1);
}

fn sysRead(self: *vm.VM) VMError!void {
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
}

fn sysWrite(self: *vm.VM) VMError!void {
    if (self.checker) return;
    const str = try self.popStack();
    const idx = try self.popStack();
    defer self.free(&[_]StackEntry{ str, idx });

    if (str != .string) return error.StringMissing;
    if (idx != .value) return error.ValueMissing;

    if (idx.value.* >= self.streams.items.len) return error.InvalidStream;

    const fs = self.streams.items[@as(usize, @intCast(idx.value.*))];
    if (fs == null) return error.InvalidStream;

    try fs.?.Write(str.string.items);
}

fn sysFlush(self: *vm.VM) VMError!void {
    if (self.checker) return;
    const idx = try self.popStack();
    defer self.free(&[_]StackEntry{idx});

    if (idx != .value) return error.ValueMissing;

    if (idx.value.* >= self.streams.items.len) return error.InvalidStream;
    const fs = self.streams.items[@as(usize, @intCast(idx.value.*))];
    if (fs == null) return error.InvalidStream;

    try fs.?.Flush();
}

fn sysClose(self: *vm.VM) VMError!void {
    const idx = try self.popStack();
    defer self.free(&[_]StackEntry{idx});

    if (idx != .value) return error.ValueMissing;

    if (idx.value.* >= self.streams.items.len) return error.InvalidStream;
    const fs = self.streams.items[@as(usize, @intCast(idx.value.*))];
    if (fs == null) return error.InvalidStream;

    try fs.?.Close();
    self.streams.items[@as(usize, @intCast(idx.value.*))] = null;
}

fn sysArg(self: *vm.VM) VMError!void {
    const idx = try self.popStack();
    defer self.free(&[_]StackEntry{idx});

    if (idx != .value) return error.ValueMissing;

    if (idx.value.* >= self.args.len) {
        try self.pushStackS("");
        return;
    }

    try self.pushStackS(self.args[@as(usize, @intCast(idx.value.*))]);
}

fn sysTime(self: *vm.VM) VMError!void {
    try self.pushStackI(@as(u64, @intCast(std.time.milliTimestamp())));
}

fn sysCheckFunc(self: *vm.VM) VMError!void {
    const name = try self.popStack();
    defer self.free(&[_]StackEntry{name});

    if (name != .string) return error.StringMissing;

    const val: u64 = if (self.functions.contains(name.string.items)) 1 else 0;

    try self.pushStackI(val);
}

fn sysGetFunc(self: *vm.VM) VMError!void {
    const name = try self.popStack();
    defer self.free(&[_]StackEntry{name});

    if (name != .string) return error.StringMissing;

    var val: []const u8 = "";

    if (self.functions.get(name.string.items)) |newVal| val = newVal.string;

    try self.pushStackS(val);
}

fn sysRegFunc(self: *vm.VM) VMError!void {
    const name = try self.popStack();
    const func = try self.popStack();
    defer self.free(&[_]StackEntry{ name, func });

    if (func != .string) return error.StringMissing;
    if (name != .string) return error.StringMissing;

    const dup = try self.allocator.dupe(u8, func.string.items);

    const ops = try self.stringToOps(dup);
    defer ops.deinit();

    const finalOps = try self.allocator.dupe(Operation, ops.items);
    const finalName = try self.allocator.dupe(u8, name.string.items);

    if (self.functions.fetchRemove(finalName)) |entry| {
        self.allocator.free(entry.key);
        self.allocator.free(entry.value.ops);
        self.allocator.free(entry.value.string);
    }

    try self.functions.put(finalName, .{
        .string = dup,
        .ops = finalOps,
    });
}

fn sysClearFunc(self: *vm.VM) VMError!void {
    const name = try self.popStack();
    defer self.free(&[_]StackEntry{name});

    if (name != .string) return error.StringMissing;

    if (self.functions.fetchRemove(name.string.items)) |entry| {
        self.allocator.free(entry.key);
        self.allocator.free(entry.value.ops);
        self.allocator.free(entry.value.string);
        return;
    }

    return error.FunctionMissing;
}

fn sysResizeHeap(self: *vm.VM) VMError!void {
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
}

fn sysReadHeap(self: *vm.VM) VMError!void {
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
}

fn sysWriteHeap(self: *vm.VM) VMError!void {
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
                .string = try self.allocator.dupe(u8, data.string.items),
            };
        },
    }

    try self.pushStack(data);
}

fn sysYield(self: *vm.VM) VMError!void {
    self.yield = true;
}

fn sysError(self: *vm.VM) VMError!void {
    const msg = try self.popStack();
    defer self.free(&[_]StackEntry{msg});

    if (msg != .string) return error.StringMissing;

    const msgString = try self.getOp();
    defer self.allocator.free(msgString);

    try self.out.appendSlice("Error: ");
    try self.out.appendSlice(msg.string.items);
    try self.out.appendSlice("\n");
    try self.out.appendSlice(msgString);

    self.stopped = true;
}

fn sysSize(self: *vm.VM) VMError!void {
    const path = try self.popStack();
    defer self.free(&[_]StackEntry{path});

    if (path != .string) return error.StringMissing;

    if (path.string.items.len == 0) return error.FileMissing;

    if (path.string.items[0] == '/') {
        const file = try files.root.getFile(path.string.items);

        try self.pushStackI(file.size());

        return;
    }

    const file = try self.root.getFile(path.string.items);

    try self.pushStackI(file.size());
}

fn sysRSP(self: *vm.VM) VMError!void {
    const num = try self.popStack();
    defer self.free(&[_]StackEntry{num});

    if (num != .value) return error.ValueMissing;
    if (self.rsp < num.value.*) return error.InvalidSys;

    const oldRsp = self.rsp;

    self.rsp = num.value.*;

    self.free(self.stack[self.rsp..oldRsp]);
}

fn sysSpawn(self: *vm.VM) VMError!void {
    const exec = try self.popStack();
    defer self.free(&[_]StackEntry{exec});

    if (exec != .string) return error.StringMissing;

    const file = try self.root.getFile(exec.string.items);
    const conts = try file.read(null);

    const handle = try vmManager.VMManager.instance.spawn(self.root, exec.string.items, conts[4..]);

    try self.pushStackI(handle.id);
}

fn sysStatus(self: *vm.VM) VMError!void {
    const handle = try self.popStack();
    defer self.free(&[_]StackEntry{handle});

    if (handle != .value) return error.ValueMissing;

    return error.Todo;
}
