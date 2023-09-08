const std = @import("std");
const vm = @import("vm.zig");
const files = @import("files.zig");
const allocator = @import("../util/allocator.zig");

pub const VMManager = struct {
    const Self = @This();

    pub var vm_time: f64 = 0.5;
    pub var instance: Self = undefined;

    threads: std.ArrayList(std.Thread),
    vms: std.AutoHashMap(usize, vm.VM),
    results: std.AutoHashMap(usize, VMResult),
    vm_index: usize = 0,
    last_frame_time: f64 = 1.0 / 60.0,

    pub const VMResult = struct {
        data: []u8,
        done: bool,

        pub fn deinit(self: VMResult) void {
            allocator.alloc.free(self.data);
        }
    };

    pub const VMHandle = struct {
        id: usize,
    };

    pub fn init() void {
        instance = .{
            .vms = std.AutoHashMap(usize, vm.VM).init(allocator.alloc),
            .results = std.AutoHashMap(usize, VMResult).init(allocator.alloc),
            .threads = std.ArrayList(std.Thread).init(allocator.alloc),
        };
    }

    pub fn logout() !void {
        var iter = instance.vms.iterator();

        while (iter.next()) |entry| {
            try entry.value_ptr.*.deinit();
            _ = instance.vms.remove(entry.key_ptr.*);
        }
    }

    pub fn deinit() void {
        instance.vms.deinit();
        instance.results.deinit();
        instance.threads.deinit();
    }

    pub const VMStats = struct {
        id: usize,
        name: []const u8,
        metaUsage: usize,
    };

    pub fn getStats(self: *Self) ![]VMStats {
        const results = try allocator.alloc.alloc(VMStats, self.vms.count());

        var iter = self.vms.iterator();
        var idx: usize = 0;

        while (iter.next()) |entry| : (idx += 1) {
            const vm_instance = entry.value_ptr;
            results[idx] = .{
                .id = entry.key_ptr.*,
                .name = try allocator.alloc.dupe(u8, vm_instance.name),
                .metaUsage = try vm_instance.getMetaUsage(),
            };
        }

        return results;
    }

    pub fn spawn(self: *Self, root: *files.Folder, params: []const u8, code: []const u8) !VMHandle {
        const id = self.vm_index;

        self.vm_index = self.vm_index +% 1;

        var vm_instance = try vm.VM.init(allocator.alloc, root, params, false);

        vm_instance.loadString(code) catch |err| {
            try vm_instance.deinit();

            return err;
        };

        try self.vms.put(id, vm_instance);

        return .{
            .id = id,
        };
    }

    pub fn destroy(self: *Self, handle: VMHandle) !void {
        if (self.vms.getPtr(handle.id)) |entry| {
            try entry.deinit();
            _ = self.vms.remove(handle.id);
        }
    }

    pub fn updateVmThread(vm_instance: *vm.VM, frame_end: u64) !void {
        const time: u64 = @intCast(std.time.nanoTimestamp());

        if (frame_end < time) {
            return;
        }

        _ = vm_instance.runTime(frame_end - time, @import("builtin").mode == .Debug) catch |err| {
            vm_instance.stopped = true;

            const errString = try std.fmt.allocPrint(allocator.alloc, "Error: {s}\n", .{@errorName(err)});
            defer allocator.alloc.free(errString);

            try vm_instance.out.appendSlice(errString);

            const msgString = try vm_instance.getOp();
            defer allocator.alloc.free(msgString);

            try vm_instance.out.appendSlice(msgString);
        };
    }

    pub fn appendInputSlice(self: *Self, handle: VMHandle, data: []const u8) !void {
        if (self.vms.getPtr(handle.id)) |vm_instance| {
            try vm_instance.input.appendSlice(data);
        }
    }

    pub fn getOutput(self: *Self, handle: VMHandle) !VMResult {
        return if (self.results.fetchRemove(handle.id)) |item| item.value else .{
            .data = try allocator.alloc.alloc(u8, 0),
            .done = !self.vms.contains(handle.id),
        };
    }

    pub fn update(self: *Self) !void {
        const frame_end = @as(u64, @intCast(std.time.nanoTimestamp())) + @as(u64, @intFromFloat((self.last_frame_time) * std.time.ns_per_s * vm_time));

        var iter = self.vms.iterator();

        while (iter.next()) |entry| {
            const vm_id = entry.key_ptr.*;
            const vm_instance = entry.value_ptr;

            if (vm_instance.stopped) {
                var result: VMResult = VMResult{
                    .data = try allocator.alloc.dupe(u8, vm_instance.out.items),
                    .done = true,
                };

                try self.destroy(.{
                    .id = vm_id,
                });

                if (self.results.getPtr(vm_id)) |oldResult| {
                    defer result.deinit();

                    const start = oldResult.data.len;
                    oldResult.data = try allocator.alloc.realloc(oldResult.data, oldResult.data.len + result.data.len);
                    @memcpy(oldResult.data[start..], result.data);

                    oldResult.done = result.done;
                } else {
                    try self.results.put(vm_id, result);
                }

                continue;
            }

            var result: VMResult = VMResult{
                .data = try allocator.alloc.dupe(u8, vm_instance.out.items),
                .done = false,
            };

            vm_instance.out.clearAndFree();

            try self.threads.append(try std.Thread.spawn(.{}, updateVmThread, .{ vm_instance, frame_end }));

            if (self.results.getPtr(vm_id)) |oldResult| {
                defer result.deinit();

                const start = oldResult.data.len;
                oldResult.data = try allocator.alloc.realloc(oldResult.data, oldResult.data.len + result.data.len);
                @memcpy(oldResult.data[start..], result.data);

                oldResult.done = false;
            } else {
                try self.results.put(vm_id, result);
            }
        }

        for (self.threads.items) |thread| {
            thread.join();
        }

        self.threads.clearAndFree();
    }
};
