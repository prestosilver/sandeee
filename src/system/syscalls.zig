const std = @import("std");
const options = @import("options");
const steam = @import("steam");

const system = @import("mod.zig");
const util = @import("../util/mod.zig");

const log = util.log;

const VmManager = system.VmManager;
const Stream = system.Stream;
const Vm = system.Vm;
const files = system.files;
const headless = system.headless;

const VmError = Vm.VmError;
const StackEntry = Vm.StackEntry;
const Operation = Vm.Operation;

const Rope = util.Rope;

const SyscallId = enum(u64) {
    Print = 0,
    Quit = 1,
    Create = 2,
    Open = 3,
    Read = 4,
    Write = 5,
    Flush = 6,
    Close = 7,
    Arg = 8,
    Time = 9,
    CheckFunc = 10,
    GetFunc = 11,
    RegFunc = 12,
    ClearFunc = 13,
    ResizeHeap = 14,
    ReadHeap = 15,
    WriteHeap = 16,
    Yield = 17,
    Error = 18,
    Size = 19,
    RSP = 20,
    Spawn = 21,
    Status = 22,
    DeleteFile = 23,
    Steam = 24,
    Last = 25,
};

pub const SysCall = struct {
    const Self = @This();

    const SYS_CALLS = std.EnumArray(SyscallId, Self).init(
        .{
            // System ops
            .Print = .{ .run_fn = sysPrint },
            .Quit = .{ .run_fn = sysQuit },

            // File ops
            .Create = .{ .run_fn = sysCreate },
            .Open = .{ .run_fn = sysOpen },
            .Read = .{ .run_fn = sysRead },
            .Write = .{ .run_fn = sysWrite },
            .Flush = .{ .run_fn = sysFlush },
            .Close = .{ .run_fn = sysClose },

            // more system ops
            .Arg = .{ .run_fn = sysArg },
            .Time = .{ .run_fn = sysTime },

            // function ops
            .CheckFunc = .{ .run_fn = sysCheckFunc },
            .GetFunc = .{ .run_fn = sysGetFunc },
            .RegFunc = .{ .run_fn = sysRegFunc },
            .ClearFunc = .{ .run_fn = sysClearFunc },

            // heap ops
            .ResizeHeap = .{ .run_fn = sysResizeHeap },
            .ReadHeap = .{ .run_fn = sysReadHeap },
            .WriteHeap = .{ .run_fn = sysWriteHeap },

            // more system ops
            .Yield = .{ .run_fn = sysYield },
            .Error = .{ .run_fn = sysError },

            // more file ops
            .Size = .{ .run_fn = sysSize },

            // more system ops
            .RSP = .{ .run_fn = sysRSP },
            .Spawn = .{ .run_fn = sysSpawn },
            .Status = .{ .run_fn = sysStatus },
            .DeleteFile = .{ .run_fn = sysDelete },
            .Steam = .{ .run_fn = sysSteam },
            .Last = .{ .run_fn = lastErr },
        },
    );

    run_fn: *const fn (*Vm) VmError!void,

    pub fn run(self: *Vm, index: u64) VmError!void {
        if (index < @intFromEnum(SyscallId.Last)) {
            return SYS_CALLS.get(@enumFromInt(index)).run_fn(self);
        }

        return error.InvalidSys;
    }

    fn lastErr(_: *Vm) VmError!void {
        return error.InvalidSys;
    }
};

fn sysPrint(self: *Vm) VmError!void {
    const a = try self.popStack();

    if (a.data().* == .string) {
        var rope: ?*Rope = a.data().string;
        while (rope) |node| : (rope = node.next)
            switch (node.data) {
                .string => |str| try self.out.appendSlice(str),
                .ref => |ref| {
                    // TODO: make actual iterator

                    const tmp = try std.fmt.allocPrint(self.allocator, "{s}", .{ref});
                    defer self.allocator.free(tmp);
                    try self.out.appendSlice(tmp);
                },
            };

        if (headless.is_headless)
            self.yield = true;
    } else if (a.data().* == .value) {
        const str = try std.fmt.allocPrint(self.allocator, "{}", .{a.data().value});
        defer self.allocator.free(str);

        try self.out.appendSlice(str);

        if (headless.is_headless)
            self.yield = true;
    }
}

fn sysQuit(self: *Vm) VmError!void {
    if (self.functions.contains(Vm.EXIT_NAME)) {
        if (self.inside_fn) |func| {
            if (std.mem.eql(u8, func, Vm.EXIT_NAME)) {
                self.stopped = true;
                return;
            }
        }
        self.return_stack[self.return_rsp].location = self.pc;
        self.return_stack[self.return_rsp].function = self.inside_fn;
        self.pc = 0;
        self.inside_fn = Vm.EXIT_NAME;
        self.return_rsp += 1;

        return;
    }

    self.stopped = true;
}

fn sysCreate(self: *Vm) VmError!void {
    const path = try self.popStack();

    if (path.data().* != .string) return error.StringMissing;

    const path_str = try std.fmt.allocPrint(self.allocator, "{}", .{path.data().string});
    defer self.allocator.free(path_str);

    if (path_str.len > 0 and path_str[0] == '/') {
        const root = try files.FolderLink.resolve(.root);
        try root.newFile(path_str);
    } else {
        const root = try self.root.resolve();
        try root.newFile(path_str);
    }
}

fn sysOpen(self: *Vm) VmError!void {
    const path = try self.popStack();

    if (path.data().* != .string) return error.StringMissing;

    const path_str = try std.fmt.allocPrint(self.allocator, "{}", .{path.data().string});
    defer self.allocator.free(path_str);

    const root = try self.root.resolve();
    const stream = try Stream.open(root, path_str, self);

    try self.streams.append(stream);
    try self.pushStackI(self.streams.items.len - 1);
}

fn sysRead(self: *Vm) VmError!void {
    const len = try self.popStack();
    const idx = try self.popStack();

    if (len.data().* != .value) return error.ValueMissing;
    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.streams.items.len) return error.InvalidStream;

    const fs = self.streams.items[@as(usize, @intCast(idx.data().value))];
    if (fs) |stream| {
        const cont = try stream.read(@as(u32, @intCast(len.data().value)));
        defer self.allocator.free(cont);

        try self.pushStackS(try .init(cont));
    } else {
        return error.InvalidStream;
    }
}

fn sysWrite(self: *Vm) VmError!void {
    if (self.checker) return;

    const str = try self.popStack();
    const idx = try self.popStack();

    if (str.data().* != .string) return error.StringMissing;
    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.streams.items.len) return error.InvalidStream;

    const fs = self.streams.items[@as(usize, @intCast(idx.data().value))];
    if (fs) |stream| {
        var rope: ?*Rope = str.data().string;
        while (rope) |node| : (rope = node.next)
            switch (node.data) {
                .string => |string| try stream.write(string),
                .ref => |ref| {
                    // TODO: make actual iterator

                    const tmp = try std.fmt.allocPrint(self.allocator, "{s}", .{ref});
                    defer self.allocator.free(tmp);
                    try stream.write(tmp);
                },
            };
    } else {
        return error.InvalidStream;
    }
}

fn sysFlush(self: *Vm) VmError!void {
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

fn sysClose(self: *Vm) VmError!void {
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

fn sysArg(self: *Vm) VmError!void {
    const idx = try self.popStack();

    if (idx.data().* != .value) return error.ValueMissing;

    if (idx.data().value >= self.args.len) {
        try self.pushStackS(try .init(""));
        return;
    }

    try self.pushStackS(try .init(self.args[@as(usize, @intCast(idx.data().value))]));
}

fn sysTime(self: *Vm) VmError!void {
    try self.pushStackI(@as(u64, @intCast(std.time.milliTimestamp())));
}

fn sysCheckFunc(self: *Vm) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    const name_str = try std.fmt.allocPrint(self.allocator, "{}", .{name.data().string});
    defer self.allocator.free(name_str);

    const val: u64 = if (self.functions.contains(name_str)) 1 else 0;

    try self.pushStackI(val);
}

fn sysGetFunc(self: *Vm) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    var val: []const u8 = "";

    const name_str = try std.fmt.allocPrint(self.allocator, "{}", .{name.data().string});
    defer self.allocator.free(name_str);

    if (self.functions.get(name_str)) |newVal| val = newVal.string;

    try self.pushStackS(try .init(val));
}

fn sysRegFunc(self: *Vm) VmError!void {
    const name = try self.popStack();
    const func = try self.popStack();

    if (func.data().* != .string) return error.StringMissing;
    if (name.data().* != .string) return error.StringMissing;

    const dup = try std.fmt.allocPrint(self.allocator, "{}", .{func.data().string});

    const ops = try self.stringToOps(dup);
    defer ops.deinit();

    const final_ops = try self.allocator.dupe(Operation, ops.items);
    const final_name = try std.fmt.allocPrint(self.allocator, "{}", .{name.data().string});

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

fn sysClearFunc(self: *Vm) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    const name_str = try std.fmt.allocPrint(self.allocator, "{}", .{name.data().string});
    defer self.allocator.free(name_str);

    if (self.functions.fetchRemove(name_str)) |entry| {
        self.allocator.free(entry.key);
        self.allocator.free(entry.value.ops);
        self.allocator.free(entry.value.string);
        return;
    }

    return error.FunctionMissing;
}

fn sysResizeHeap(self: *Vm) VmError!void {
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

fn sysReadHeap(self: *Vm) VmError!void {
    const item = try self.popStack();

    if (item.data().* != .value) return error.ValueMissing;
    if (item.data().value >= self.heap.len) return error.HeapOutOfBounds;

    const adds = self.heap[@as(usize, @intCast(item.data().value))];

    switch (adds) {
        .value => {
            try self.pushStackI(adds.value);
        },
        .string => {
            adds.string.refs += 1;
            try self.pushStackS(adds.string);
        },
    }
}

fn sysWriteHeap(self: *Vm) VmError!void {
    const data = try self.popStack();
    const item = try self.popStack();

    if (item.data().* != .value) return error.ValueMissing;

    if (item.data().value >= self.heap.len) return error.HeapOutOfBounds;

    const idx: usize = @intCast(item.data().value);

    if (self.heap[idx] == .string)
        self.heap[idx].string.deinit();

    switch (data.data().*) {
        .free => return error.HeapOutOfBounds,
        .value => {
            self.heap[idx] = .{
                .value = data.data().value,
            };
        },
        .string => {
            data.data().string.refs += 1;

            self.heap[idx] = .{
                .string = data.data().string,
            };
        },
    }

    try self.pushStack(data);
}

fn sysYield(self: *Vm) VmError!void {
    self.yield = true;
}

fn sysError(self: *Vm) VmError!void {
    const msg = try self.popStack();

    if (msg.data().* != .string) return error.StringMissing;

    const msg_string = try self.getOp();
    defer self.allocator.free(msg_string);

    try self.out.appendSlice("Error: ");

    var rope: ?*Rope = msg.data().string;
    while (rope) |node| : (rope = node.next)
        switch (node.data) {
            .string => |str| try self.out.appendSlice(str),
            .ref => |ref| {
                // TODO: make actual iterator

                const tmp = try std.fmt.allocPrint(self.allocator, "{s}", .{ref});
                defer self.allocator.free(tmp);
                try self.out.appendSlice(tmp);
            },
        };

    try self.out.appendSlice("\n");
    try self.out.appendSlice(msg_string);

    self.stopped = true;
}

fn sysSize(self: *Vm) VmError!void {
    const path = try self.popStack();

    if (path.data().* != .string) return error.StringMissing;

    const path_str = try std.fmt.allocPrint(self.allocator, "{}", .{path.data().string});
    defer self.allocator.free(path_str);

    if (path_str.len == 0) return error.FileMissing;

    if (path_str[0] == '/') {
        const root = try files.FolderLink.resolve(.root);
        const file = try root.getFile(path_str);

        try self.pushStackI(try file.size());

        return;
    }

    const root = try self.root.resolve();
    const file = try root.getFile(path_str);

    try self.pushStackI(try file.size());
}

fn sysRSP(self: *Vm) VmError!void {
    const num = try self.popStack();

    if (num.data().* != .value) return error.ValueMissing;

    if (self.rsp < num.data().value) return error.InvalidSys;

    self.rsp = num.data().value;
}

fn sysSpawn(self: *Vm) VmError!void {
    const exec = try self.popStack();

    if (exec.data().* != .string) return error.StringMissing;

    const path = try std.fmt.allocPrint(self.allocator, "{}", .{exec.data().string});
    defer self.allocator.free(path);

    const root = try self.root.resolve();
    const file = try root.getFile(path);
    const conts = try file.read(null);

    const handle = try VmManager.instance.spawn(self.root, path, conts[4..]);

    try self.pushStackI(handle.id);
}

fn sysStatus(self: *Vm) VmError!void {
    const handle = try self.popStack();

    if (handle.data().* != .value) return error.ValueMissing;

    return error.Todo;
}

fn sysDelete(self: *Vm) VmError!void {
    const file = try self.popStack();

    if (file.data().* != .string) return error.StringMissing;

    const path = try std.fmt.allocPrint(self.allocator, "{}", .{file.data().string});
    defer self.allocator.free(path);

    const root = try self.root.resolve();
    try root.removeFile(path);
}

const SteamYieldCreate = struct {
    handle: steam.APIHandle,

    pub fn check(self: *SteamYieldCreate, vm_instance: *Vm) VmError!bool {
        const utils = steam.getSteamUtils();

        var failed: bool = false;

        if (!utils.isCallComplete(self.handle, &failed))
            return false;

        if (failed)
            return error.UnknownError;
        failed = false;

        var result: steam.callback.CreateItem = undefined;
        if (!utils.getCallResult(
            steam.callback.CreateItem,
            self.handle,
            &result,
            &failed,
        ))
            return error.UnknownError;

        try vm_instance.pushStackI(@byteSwap(result.file_id.id));

        return true;
    }
};

const SteamYieldUpdate = struct {
    handle: steam.APIHandle,
    folder: ?std.fs.Dir = null,

    pub fn check(self: *SteamYieldUpdate, vm_instance: *Vm) VmError!bool {
        const utils = steam.getSteamUtils();

        var failed: bool = false;

        if (!utils.isCallComplete(self.handle, &failed))
            return false;

        if (failed)
            return error.UnknownError;

        failed = false;

        var result: steam.callback.UpdateItem = undefined;

        if (!utils.getCallResult(
            steam.callback.UpdateItem,
            self.handle,
            &result,
            &failed,
        ))
            return error.UnknownError;

        try vm_instance.pushStackI(0);

        return true;
    }
};

fn sysSteam(self: *Vm) VmError!void {
    if (!options.IsSteam)
        return error.InvalidSys;

    const file = try self.popStack();

    if (file.data().* != .string) return error.StringMissing;

    const data = try std.fmt.allocPrint(self.allocator, "{}", .{file.data().string});
    defer self.allocator.free(data);

    const ugc = steam.getSteamUGC();

    if (data.len == 0) {
        const handle = ugc.createItem(steam.STEAM_APP_ID, .Community);

        return self.yieldUntil(SteamYieldCreate, .{ .handle = handle });
    } else if (data[0] == 'm' and data.len > 1) {
        var split = std.mem.splitScalar(u8, data[1..], ':');

        set_data: {
            const item_str = split.next() orelse break :set_data;
            const prop = split.next() orelse break :set_data;
            const value = split.next() orelse break :set_data;

            if (split.next() != null) break :set_data;

            const item_id = std.fmt.parseInt(usize, item_str, 10) catch {
                log.warn("bad steam metadata id set: '{s}'", .{data[1..]});

                return error.UnknownError;
            };

            if (std.mem.eql(u8, prop, "title")) {
                const update = ugc.startUpdate(steam.STEAM_APP_ID, .{ .id = item_id });

                if (!update.setTitle(ugc, value))
                    return error.UnknownError;

                const handle = update.submit(ugc, "Update Title");

                return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle });
            }

            if (std.mem.eql(u8, prop, "description")) {
                const update = ugc.startUpdate(steam.STEAM_APP_ID, .{ .id = item_id });

                if (!update.setDescription(ugc, value))
                    return error.UnknownError;

                const handle = update.submit(ugc, "Update Desc");

                return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle });
            }

            if (std.mem.eql(u8, prop, "visibility")) {
                const parsed: steam.WorkshopItemVisibility = if (std.mem.eql(u8, value, "public"))
                    .Public
                else if (std.mem.eql(u8, value, "friends"))
                    .FriendsOnly
                else if (std.mem.eql(u8, value, "private"))
                    .Private
                else if (std.mem.eql(u8, value, "unlisted"))
                    .Unlisted
                else {
                    std.log.scoped(.Steam).err("Invalid steam item visibility {s}", .{value});

                    return error.UnknownError;
                };

                const update = ugc.startUpdate(steam.STEAM_APP_ID, .{ .id = item_id });

                if (!update.setVisibility(ugc, parsed))
                    return error.UnknownError;

                const handle = update.submit(ugc, "Update Desc");

                return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle });
            }
        }

        log.warn("bad steam metadata set: '{s}'", .{data[1..]});

        return error.UnknownError;
    } else if (data[0] == 'f' and data.len > 1) {
        var split = std.mem.splitScalar(u8, data[1..], ':');

        upload_data: {
            const item_str = split.next() orelse break :upload_data;
            const path = split.next() orelse break :upload_data;
            if (split.next() != null) break :upload_data;

            std.fs.cwd().deleteTree(".steam_upload") catch {};

            std.fs.cwd().makeDir(".steam_upload") catch |err|
                if (err != error.PathAlreadyExists)
                    return error.UnknownError;
            var upload = std.fs.cwd().openDir(".steam_upload", .{}) catch return error.UnknownError;
            defer upload.close();

            const root = try self.root.resolve();
            const folder = try root.getFolder(path);

            {
                var folder_list: std.ArrayList(*const files.Folder) = .init(self.allocator);
                defer folder_list.deinit();

                try folder.getFoldersRec(&folder_list);
                for (folder_list.items) |item| {
                    if (item.name.len < folder.name.len) continue;

                    log.debug("creating Steam folder {s}", .{item.name[folder.name.len..]});

                    upload.makePath(item.name[folder.name.len..]) catch |err|
                        if (err != error.PathAlreadyExists)
                            return error.UnknownError;
                }
            }

            {
                var file_list: std.ArrayList(*files.File) = .init(self.allocator);
                defer file_list.deinit();

                try folder.getFilesRec(&file_list);
                for (file_list.items) |item| {
                    if (item.name.len < folder.name.len) continue;

                    log.debug("creating Steam file {s}", .{item.name[folder.name.len..]});

                    upload.writeFile(.{
                        .sub_path = item.name[folder.name.len..],
                        .data = try item.read(self),
                    }) catch return error.UnknownError;
                }
            }

            const item_id = std.fmt.parseInt(usize, item_str, 10) catch {
                log.warn("bad steam upload files id: '{s}'", .{data[1..]});

                return error.UnknownError;
            };

            const update = ugc.startUpdate(steam.STEAM_APP_ID, .{ .id = item_id });

            if (!update.setContent(ugc, upload))
                return error.UnknownError;

            const handle = update.submit(ugc, "Update files");

            return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle, .folder = upload });
        }

        log.warn("bad steam upload files: '{s}'", .{data[1..]});

        return error.UnknownError;
    } else if (data[0] == 'g' and data.len > 1) {
        var split = std.mem.splitScalar(u8, data[1..], ':');

        download_data: {
            const item_str = split.next() orelse break :download_data;
            const path = split.next() orelse break :download_data;
            if (split.next() != null) break :download_data;

            _ = item_str;
            _ = path;
        }

        log.warn("bad steam download files: '{s}'", .{data[1..]});

        return error.UnknownError;
    }

    return error.UnknownError;
}
