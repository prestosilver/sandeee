const std = @import("std");
const options = @import("options");
const builtin = @import("builtin");
const steam = @import("steam");
const zigimg = @import("zigimg");

const system = @import("../system.zig");
const util = @import("../util.zig");
const windows = @import("../windows.zig");

const log = util.log;
const Font = util.Font;

const Stream = system.Stream;
const Vm = system.Vm;
const files = system.files;
const headless = system.headless;

const VmError = Vm.VmError;
const StackEntry = Vm.StackEntry;
const Operation = Vm.Operation;

const Rope = util.Rope;

const SyscallId = enum(u64) {
    print = 0,
    quit = 1,
    create = 2,
    open = 3,
    read = 4,
    write = 5,
    flush = 6,
    close = 7,
    arg = 8,
    time = 9,
    check_func = 10,
    get_func = 11,
    reg_func = 12,
    clear_func = 13,
    resize_heap = 14,
    read_heap = 15,
    write_heap = 16,
    yield = 17,
    error = 18,
    size = 19,
    rsp = 20,
    spawn = 21,
    status = 22,
    delete_file = 23,
    steam = 24,
    last = 25,
};

pub var main_font: *Font = undefined;

pub const SysCall = struct {
    const Self = @This();

    const SYS_CALLS = std.EnumArray(SyscallId, Self).init(
        .{
            // System ops
            .print = .{ .run_fn = sysPrint },
            .quit = .{ .run_fn = sysQuit },

            // File ops
            .create = .{ .run_fn = sysCreate },
            .open = .{ .run_fn = sysOpen },
            .read = .{ .run_fn = sysRead },
            .write = .{ .run_fn = sysWrite },
            .flush = .{ .run_fn = sysFlush },
            .close = .{ .run_fn = sysClose },

            // more system ops
            .arg = .{ .run_fn = sysArg },
            .time = .{ .run_fn = sysTime },

            // function ops
            .check_func = .{ .run_fn = sysCheckFunc },
            .get_func = .{ .run_fn = sysGetFunc },
            .reg_func = .{ .run_fn = sysRegFunc },
            .clear_func = .{ .run_fn = sysClearFunc },

            // heap ops
            .resize_heap = .{ .run_fn = sysResizeHeap },
            .read_heap = .{ .run_fn = sysReadHeap },
            .write_heap = .{ .run_fn = sysWriteHeap },

            // more system ops
            .yield = .{ .run_fn = sysYield },
            .error = .{ .run_fn = sysError },

            // more file ops
            .size = .{ .run_fn = sysSize },

            // more system ops
            .rsp = .{ .run_fn = sysRSP },
            .spawn = .{ .run_fn = sysSpawn },
            .status = .{ .run_fn = sysStatus },
            .delete_file = .{ .run_fn = sysDelete },
            .steam = .{ .run_fn = sysSteam },
            .last = .{ .run_fn = lastErr },
        },
    );

    run_fn: *const fn (*Vm) VmError!void,

    var sys_mutex: std.Io.Mutex = .init;

    pub fn run(self: *Vm, index: u64) VmError!void {
        sys_mutex.lock(util.io) catch unreachable;
        defer sys_mutex.unlock(util.io);

        if (index < @intFromEnum(SyscallId.last)) {
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
        try self.out.appendSlice(a.data().string.data);

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

    const path_str = try std.fmt.allocPrint(self.allocator, "{f}", .{path.data().string});
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

    const path_str = try std.fmt.allocPrint(self.allocator, "{f}", .{path.data().string});
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
        try stream.write(str.data().string.data);
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
    } else return error.InvalidStream;
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
    try self.pushStackI(@as(u64, @intCast(std.Io.Clock.now(.real, util.io).toMilliseconds())));
}

fn sysCheckFunc(self: *Vm) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    const name_str = try std.fmt.allocPrint(self.allocator, "{f}", .{name.data().string});
    defer self.allocator.free(name_str);

    const val: u64 = if (self.functions.contains(name_str)) 1 else 0;

    try self.pushStackI(val);
}

fn sysGetFunc(self: *Vm) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    var val: []const u8 = "";

    const name_str = try std.fmt.allocPrint(self.allocator, "{f}", .{name.data().string});
    defer self.allocator.free(name_str);

    if (self.functions.get(name_str)) |newVal| val = newVal.string;

    try self.pushStackS(try .init(val));
}

fn sysRegFunc(self: *Vm) VmError!void {
    const name = try self.popStack();
    const func = try self.popStack();

    if (func.data().* != .string) return error.StringMissing;
    if (name.data().* != .string) return error.StringMissing;

    const dup = try std.fmt.allocPrint(self.allocator, "{f}", .{func.data().string});

    const ops = try self.stringToOps(dup);

    // TODO: this should free children too
    errdefer self.allocator.free(ops);

    const final_name = try std.fmt.allocPrint(self.allocator, "{f}", .{name.data().string});

    if (self.functions.fetchRemove(final_name)) |entry| {
        self.allocator.free(entry.key);
        self.allocator.free(entry.value.ops);
        self.allocator.free(entry.value.string);
    }

    try self.functions.put(final_name, .{
        .string = dup,
        .ops = ops,
    });
}

fn sysClearFunc(self: *Vm) VmError!void {
    const name = try self.popStack();

    if (name.data().* != .string) return error.StringMissing;

    const name_str = try std.fmt.allocPrint(self.allocator, "{f}", .{name.data().string});
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
            self.heap[idx] = null;
        }
    }
}

fn sysReadHeap(self: *Vm) VmError!void {
    const item = try self.popStack();

    if (item.data().* != .value) return error.ValueMissing;
    if (item.data().value >= self.heap.len) return error.HeapOutOfBounds;

    const adds = self.heap[@as(usize, @intCast(item.data().value))];
    if (adds) |a|
        try self.pushStack(a)
    else
        return error.NullHeapAccess;
}

fn sysWriteHeap(self: *Vm) VmError!void {
    const data = try self.popStack();
    const item = try self.popStack();

    if (item.data().* != .value) return error.ValueMissing;

    if (item.data().value >= self.heap.len) return error.HeapOutOfBounds;

    const idx: usize = @intCast(item.data().value);

    self.heap[idx] = data;

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

    try self.out.appendSlice(msg.data().string.data);

    try self.out.appendSlice("\n");
    try self.out.appendSlice(msg_string);

    self.stopped = true;
    self.errored = true;
}

fn sysSize(self: *Vm) VmError!void {
    const path = try self.popStack();

    if (path.data().* != .string) return error.StringMissing;

    const path_str = try std.fmt.allocPrint(self.allocator, "{f}", .{path.data().string});
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

    if (self.rsp < @as(u64, @intCast(num.data().value))) return error.InvalidSys;

    self.rsp = @intCast(num.data().value);
}

fn sysSpawn(self: *Vm) VmError!void {
    const exec = try self.popStack();

    if (exec.data().* != .string) return error.StringMissing;

    const path = try std.fmt.allocPrint(self.allocator, "{f}", .{exec.data().string});
    defer self.allocator.free(path);

    const root = try self.root.resolve();
    const file = try root.getFile(path);
    const conts = try file.read(null);

    const handle = try Vm.Manager.instance.spawn(self.root, path, conts[4..]);

    try self.pushStackI(@intFromEnum(handle));
}

fn sysStatus(self: *Vm) VmError!void {
    const handle = try self.popStack();

    if (handle.data().* != .value) return error.ValueMissing;

    return error.Todo;
}

fn sysDelete(self: *Vm) VmError!void {
    const file = try self.popStack();

    if (file.data().* != .string) return error.StringMissing;

    const path = try std.fmt.allocPrint(self.allocator, "{f}", .{file.data().string});
    defer self.allocator.free(path);

    const root = try self.root.resolve();
    try root.removeFile(path);
}

const SteamYieldCreate = struct {
    handle: steam.APIHandle,

    pub fn check(self: *SteamYieldCreate, vm_instance: *Vm) VmError!bool {
        if (!self.handle.isComplete()) return false;
        const result = try self.handle.getResult(steam.callback.CreateItem);
        try vm_instance.pushStackI(@intFromEnum(result.file_id));

        return true;
    }
};

const SteamYieldUpdate = struct {
    handle: steam.APIHandle,
    folder: ?std.Io.Dir = null,

    pub fn check(self: *SteamYieldUpdate, vm_instance: *Vm) VmError!bool {
        if (!self.handle.isComplete()) return false;
        const result = try self.handle.getResult(steam.callback.UpdateItem);
        try result.result.check();

        try vm_instance.pushStackI(0);

        return true;
    }
};

fn sysSteam(self: *Vm) VmError!void {
    if (!options.is_steam)
        return error.InvalidSys;

    const file = try self.popStack();

    if (file.data().* != .string) return error.StringMissing;

    const data = try std.fmt.allocPrint(self.allocator, "{f}", .{file.data().string});
    defer self.allocator.free(data);

    if (data.len == 0) {
        const handle = steam.UGC.createItem(.community, .this_app);

        return self.yieldUntil(SteamYieldCreate, .{ .handle = handle });
    } else if (data[0] == 'm' and data.len > 1) {
        var split = std.mem.splitScalar(u8, data[1..], ':');

        set_data: {
            const item_str = split.next() orelse break :set_data;
            const prop = split.next() orelse break :set_data;
            const value = split.next() orelse break :set_data;

            if (split.next() != null) break :set_data;

            const item: steam.UGC.PublishedFile = @enumFromInt(std.fmt.parseInt(usize, item_str, 10) catch {
                log.warn("Bad steam metadata id {s} in set", .{data[1..]});

                return error.UnknownError;
            });

            if (std.mem.eql(u8, prop, "title")) {
                const title = try self.allocator.dupeZ(u8, value);
                defer self.allocator.free(title);

                const update = try item.startUpdate(.this_app);
                try update.setTitle(title);

                const handle = try update.submit("Update title");

                return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle });
            }

            if (std.mem.eql(u8, prop, "description")) {
                const desc = try self.allocator.dupeZ(u8, value);
                defer self.allocator.free(desc);

                const update = try item.startUpdate(.this_app);
                try update.setDescription(desc);

                const handle = try update.submit("Update description");

                return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle });
            }

            if (std.mem.eql(u8, prop, "visibility")) {
                const parsed: steam.WorkshopItemVisibility = if (std.mem.eql(u8, value, "public"))
                    .public
                else if (std.mem.eql(u8, value, "friends"))
                    .friends_only
                else if (std.mem.eql(u8, value, "private"))
                    .private
                else if (std.mem.eql(u8, value, "unlisted"))
                    .unlisted
                else {
                    std.log.scoped(.Steam).err("Invalid steam item visibility {s}", .{value});

                    return error.UnknownError;
                };

                const update = try item.startUpdate(.this_app);
                try update.setVisibility(parsed);

                const handle = try update.submit("Update visibility");

                return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle });
            }
        }

        log.warn("Bad steam metadata id {s} in set", .{data[1..]});

        return error.UnknownError;
    } else if (data[0] == 'f' and data.len > 1) {
        var split = std.mem.splitScalar(u8, data[1..], ':');

        upload_data: {
            const item_str = split.next() orelse break :upload_data;
            const path = split.next() orelse break :upload_data;
            if (split.next() != null) break :upload_data;

            std.Io.Dir.cwd().deleteTree(util.io, ".steam_upload") catch {
                // ignored as this is not a mandatory delete
            };

            inline for (.{
                ".steam_upload",
                ".steam_upload/content",
                ".steam_upload/meta",
            }) |dir_path|
                std.Io.Dir.cwd().createDir(util.io, dir_path, .default_dir) catch |err|
                    switch (err) {
                        error.PathAlreadyExists => {},
                        else => {
                            log.warn("Failed to make directory {}", .{err});
                            return error.UnknownError;
                        },
                    };

            var temp_folder = std.Io.Dir.cwd().openDir(util.io, ".steam_upload", .{}) catch |err| {
                log.warn("Failed to open directory {}", .{err});
                return error.UnknownError;
            };
            defer temp_folder.close(util.io);
            var content_folder = temp_folder.openDir(util.io, "content", .{}) catch |err| {
                log.warn("Failed to open directory {}", .{err});
                return error.UnknownError;
            };
            defer content_folder.close(util.io);
            var meta_folder = temp_folder.openDir(util.io, "meta", .{}) catch |err| {
                log.warn("Failed to open directory {}", .{err});
                return error.UnknownError;
            };
            defer meta_folder.close(util.io);

            const root = try self.root.resolve();
            const folder = try root.getFolder(path);

            {
                var folder_list: std.array_list.Managed(*const files.Folder) = .init(self.allocator);
                defer folder_list.deinit();

                try folder.getFoldersRec(&folder_list, true);
                for (folder_list.items) |item| {
                    if (item.name.len <= folder.name.len) continue;
                    if (std.mem.eql(u8, item.name[folder.name.len..], "/")) continue;

                    log.debug("Creating Steam upload temp folder '{s}'", .{item.name[folder.name.len..]});

                    content_folder.createDirPath(util.io, item.name[folder.name.len..]) catch |err|
                        switch (err) {
                            error.PathAlreadyExists => {},
                            else => {
                                log.warn("Failed to make directory '{s}' {}", .{ item.name[folder.name.len..], err });
                                return error.UnknownError;
                            },
                        };
                }
            }

            {
                var file_list: std.array_list.Managed(*files.File) = .init(self.allocator);
                defer file_list.deinit();

                try folder.getFilesRec(&file_list, true);
                for (file_list.items) |item| {
                    if (item.name.len <= folder.name.len) continue;

                    log.debug("Creating Steam upload temp file {s}", .{item.name[folder.name.len..]});

                    content_folder.writeFile(util.io, .{
                        .sub_path = item.name[folder.name.len..],
                        .data = try item.read(self),
                    }) catch |err| {
                        log.warn("Failed to make file '{s}' {}", .{ item.name[folder.name.len..], err });
                        return error.UnknownError;
                    };
                }
            }

            const item: steam.UGC.PublishedFile = @enumFromInt(std.fmt.parseInt(usize, item_str, 10) catch {
                log.warn("Bad steam upload files id {s}", .{data[1..]});

                return error.UnknownError;
            });

            const window_path = try std.mem.concat(self.allocator, u8, &.{ "//:", folder.name, "index.edf" });
            defer self.allocator.free(window_path);

            var window_frame = try windows.web.renderFrame(window_path, system.Shell.shader, system.Shell.font_shader, main_font);

            var image = zigimg.Image.fromRawPixelsOwned(640, 480, @ptrCast(&window_frame), .rgba32) catch |err| {
                log.warn("failed to create image {}", .{err});

                return error.UnknownError;
            };

            image.flipVertically(self.allocator) catch |err| {
                log.warn("failed to flip image {}", .{err});

                return error.UnknownError;
            };

            var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
            image.writeToFilePath(self.allocator, util.io, ".steam_upload/meta/preview.png", write_buffer[0..], .{ .png = .{} }) catch |err| {
                log.warn("failed to write image {}", .{err});

                return error.UnknownError;
            };

            const update = try item.startUpdate(.this_app);
            try update.setContent(util.io, content_folder);

            var path_buffer: [256]u8 = undefined;
            if (meta_folder.realPathFile(util.io, "preview.png", &path_buffer)) |preview_path| {
                const preview_file = try self.allocator.dupeZ(u8, path_buffer[0..preview_path]);
                defer self.allocator.free(preview_file);

                try update.setPreview(preview_file);
            } else |_| {}

            const handle = try update.submit("Upload files");

            return self.yieldUntil(SteamYieldUpdate, .{ .handle = handle, .folder = temp_folder });
        }

        log.warn("Bad steam upload files id {s}", .{data[1..]});

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

        log.warn("bad steam download files id {s}", .{data[1..]});

        return error.UnknownError;
    }

    return error.UnknownError;
}
