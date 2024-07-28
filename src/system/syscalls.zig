const std = @import("std");
const vm = @import("vm.zig");
const files = @import("files.zig");
const streams = @import("stream.zig");
const vm_manager = @import("vmmanager.zig");
const log = @import("../util/log.zig").log;

const VmError = vm.VM.VMError;
const StackEntry = vm.VM.StackEntry;
const Operation = vm.VM.Operation;

pub const SysCall = struct {
    const Self = @This();

    const SYS_CALLS = [_]Self{
        // System ops
        .{ .run_fn = sysPrint },
        .{ .run_fn = sysQuit },

        // File ops
        .{ .run_fn = sysCreate },
        .{ .run_fn = sysOpen },
        .{ .run_fn = sysRead },
        .{ .run_fn = sysWrite },
        .{ .run_fn = sysFlush },
        .{ .run_fn = sysClose },

        // more system ops
        .{ .run_fn = sysArg },
        .{ .run_fn = sysTime },

        // function ops
        .{ .run_fn = sysCheckFunc },
        .{ .run_fn = sysGetFunc },
        .{ .run_fn = sysRegFunc },
        .{ .run_fn = sysClearFunc },

        // heap ops
        .{ .run_fn = sysResizeHeap },
        .{ .run_fn = sysReadHeap },
        .{ .run_fn = sysWriteHeap },

        // more system ops
        .{ .run_fn = sysYield },
        .{ .run_fn = sysError },

        // more file ops
        .{ .run_fn = sysSize },

        // more system ops
        .{ .run_fn = sysRSP },
        .{ .run_fn = sysSpawn },
        .{ .run_fn = sysStatus },
    };

    run_fn: *const fn (*vm.VM) VmError!void,

    pub fn run(self: *vm.VM, index: u64) VmError!void {
        if (index < SYS_CALLS.len) {
            return SYS_CALLS[index].run_fn(self);
        }

        return error.InvalidSys;
    }
};

fn sysPrint(self: *vm.VM) VmError!void {
    const a = try self.popStack();

    if (a.data().* == .string) {
        try self.out.appendSlice(a.data().string);
    } else if (a.data().* == .value) {
        const str = try std.fmt.allocPrint(self.allocator, "{}", .{a.data().value});
        defer self.allocator.free(str);

        try self.out.appendSlice(str);
    }
}

fn sysQuit(self: *vm.VM) VmError!void {
    if (self.functions.contains(vm.EXIT_NAME)) {
        if (self.inside_fn) |func| {
            if (std.mem.eql(u8, func, vm.EXIT_NAME)) {
                self.stopped = true;
                return;
            }
        }
        self.return_stack[self.return_rsp].location = self.pc;
        self.return_stack[self.return_rsp].function = self.inside_fn;
        self.pc = 0;
        self.inside_fn = vm.EXIT_NAME;
        self.return_rsp += 1;

        return;
    }

    self.stopped = true;
}

fn sysCreate(self: *vm.VM) VmError!void {
    const path = try self.popStack();

    if (path.data().* != .string) return error.StringMissing;

    if (path.data().string.len > 0 and path.data().string[0] == '/') {
        _ = try files.root.newFile(path.data().string);
    } else {
        _ = try self.root.newFile(path.data().string);
    }
}

fn sysOpen(self: *vm.VM) VmError!void {
    const path = try self.popStack();

    if (path.data().* != .string) return error.StringMissing;

    const stream = try streams.FileStream.open(self.root, path.data().string, self);

    try self.streams.append(stream);
    try self.pushStackI(self.streams.items.len - 1);
}

fn sysRead(self: *vm.VM) VmError!void {
    const len = try self.popStack();
    const idx = try self.popStack();

    if (len.data().* != .value) return error.ValueMissing;
    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.streams.items.len) return error.InvalidStream;

    // std.log.info("fdsa {}", .{idx.data()});

    const fs = self.streams.items[@as(usize, @intCast(idx.data().value))];
    if (fs) |stream| {
        const cont = try stream.read(@as(u32, @intCast(len.data().value)));
        defer self.allocator.free(cont);

        try self.pushStackS(cont);
    } else {
        return error.InvalidStream;
    }
}

fn sysWrite(self: *vm.VM) VmError!void {
    if (self.checker) return;

    const str = try self.popStack();
    const idx = try self.popStack();

    if (str.data().* != .string) return error.StringMissing;
    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.streams.items.len) return error.InvalidStream;

    const fs = self.streams.items[@as(usize, @intCast(idx.data().value))];
    if (fs) |stream| {
        try stream.write(str.data().string);
    } else {
        return error.InvalidStream;
    }
}

fn sysFlush(self: *vm.VM) VmError!void {
    if (self.checker) return;

    const idx = try self.popStack();

    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.streams.items.len) return error.InvalidStream;
    const fs = self.streams.items[@as(usize, @intCast(idx.data().value))];
    if (fs) |stream| {
        try stream.flush();
    } else {
        return error.InvalidStream;
    }
}

fn sysClose(self: *vm.VM) VmError!void {
    const idx = try self.popStack();

    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.streams.items.len) return error.InvalidStream;
    const fs = self.streams.items[@as(usize, @intCast(idx.data().value))];

    if (fs) |stream| {
        try stream.close();
        self.streams.items[@as(usize, @intCast(idx.data().value))] = null;
    } else {
        return error.InvalidStream;
    }
}

fn sysArg(self: *vm.VM) VmError!void {
    const idx = try self.popStack();

    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.args.len) {
        try self.pushStackS("");
        return;
    }

    try self.pushStackS(self.args[@as(usize, @intCast(idx.data().value))]);
}

fn sysTime(self: *vm.VM) VmError!void {
    try self.pushStackI(@as(u64, @intCast(std.time.milliTimestamp())));
}

fn sysCheckFunc(self: *vm.VM) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    const val: u64 = if (self.functions.contains(name.data().string)) 1 else 0;

    try self.pushStackI(val);
}

fn sysGetFunc(self: *vm.VM) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    var val: []const u8 = "";

    if (self.functions.get(name.data().string)) |newVal| val = newVal.string;

    try self.pushStackS(val);
}

fn sysRegFunc(self: *vm.VM) VmError!void {
    const name = try self.popStack();
    const func = try self.popStack();

    if (func.data().* != .string) return error.StringMissing;
    if (name.data().* != .string) return error.StringMissing;

    const dup = try self.allocator.dupe(u8, func.data().string);

    const ops = try self.stringToOps(dup);
    defer ops.deinit();

    const final_ops = try self.allocator.dupe(Operation, ops.items);
    const final_name = try self.allocator.dupe(u8, name.data().string);

    if (self.functions.fetchRemove(final_name)) |entry| {
        self.allocator.free(entry.key);
        self.allocator.free(entry.value.ops);
        self.allocator.free(entry.value.string);
    }

    try self.functions.put(final_name, .{
        .string = dup,
        .ops = final_ops,
    });
}

fn sysClearFunc(self: *vm.VM) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    if (self.functions.fetchRemove(name.data().string)) |entry| {
        self.allocator.free(entry.key);
        self.allocator.free(entry.value.ops);
        self.allocator.free(entry.value.string);
        return;
    }

    return error.FunctionMissing;
}

fn sysResizeHeap(self: *vm.VM) VmError!void {
    const size = try self.popStack();

    if (size.data().* != .value) return error.ValueMissing;

    const start = self.heap.len;
    self.heap = try self.allocator.realloc(self.heap, @intCast(size.data().value));

    if (start < self.heap.len) {
        for (start..self.heap.len) |idx| {
            self.heap[idx] = .{ .value = 0 };
        }
    }
}

fn sysReadHeap(self: *vm.VM) VmError!void {
    const item = try self.popStack();

    if (item.data().* != .value) return error.ValueMissing;
    if (item.data().value >= self.heap.len) return error.HeapOutOfBounds;

    const adds = self.heap[@as(usize, @intCast(item.data().value))];

    switch (adds) {
        .value => {
            try self.pushStackI(adds.value);
        },
        .string => {
            try self.pushStackS(adds.string);
        },
    }
}

fn sysWriteHeap(self: *vm.VM) VmError!void {
    const data = try self.popStack();
    const item = try self.popStack();

    if (item.data().* != .value) return error.ValueMissing;

    if (item.data().value >= self.heap.len) return error.HeapOutOfBounds;

    const idx: usize = @intCast(item.data().value);

    if (self.heap[idx] == .string)
        self.allocator.free(self.heap[idx].string);

    switch (data.data().*) {
        .free => unreachable,
        .value => {
            self.heap[idx] = .{
                .value = data.data().value,
            };
        },
        .string => {
            self.heap[idx] = .{
                .string = try self.allocator.dupe(u8, data.data().string),
            };
        },
    }

    try self.pushStack(data);
}

fn sysYield(self: *vm.VM) VmError!void {
    self.yield = true;
}

fn sysError(self: *vm.VM) VmError!void {
    const msg = try self.popStack();

    if (msg.data().* != .string) return error.StringMissing;

    const msg_string = try self.getOp();
    defer self.allocator.free(msg_string);

    try self.out.appendSlice("Error: ");
    try self.out.appendSlice(msg.data().string);
    try self.out.appendSlice("\n");
    try self.out.appendSlice(msg_string);

    self.stopped = true;
}

fn sysSize(self: *vm.VM) VmError!void {
    const path = try self.popStack();

    if (path.data().* != .string) return error.StringMissing;

    if (path.data().string.len == 0) return error.FileMissing;

    if (path.data().string[0] == '/') {
        const file = try files.root.getFile(path.data().string);

        try self.pushStackI(file.size());

        return;
    }

    const file = try self.root.getFile(path.data().string);

    try self.pushStackI(file.size());
}

fn sysRSP(self: *vm.VM) VmError!void {
    const num = try self.popStack();

    if (num.data().* != .value) return error.ValueMissing;
    log.info("rsp {}", .{num.data()});

    if (self.rsp < num.data().value) return error.InvalidSys;

    self.rsp = num.data().value;
}

fn sysSpawn(self: *vm.VM) VmError!void {
    const exec = try self.popStack();

    if (exec.data().* != .string) return error.StringMissing;

    const file = try self.root.getFile(exec.data().string);
    const conts = try file.read(null);

    const handle = try vm_manager.VMManager.instance.spawn(self.root, exec.data().string, conts[4..]);

    try self.pushStackI(handle.id);
}

fn sysStatus(self: *vm.VM) VmError!void {
    const handle = try self.popStack();

    if (handle.data().* != .value) return error.ValueMissing;

    return error.Todo;
}
