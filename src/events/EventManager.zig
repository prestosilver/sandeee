const std = @import("std");

const util = @import("../util.zig");

const allocator = util.allocator;

const Manager = @This();

pub var instance: Manager = .{};

subs: std.StringHashMap(std.array_list.Managed(Listener(*void))) = .init(allocator),

// TODO: really this should be a linked list and stored by event

pub fn deinit() void {
    var iter = instance.subs.iterator();
    while (iter.next()) |item|
        item.value_ptr.deinit();
    instance.subs.deinit();
}

fn Listener(comptime T: type) type {
    return struct {
        calls: *const fn (T) anyerror!void,
    };
}

pub fn registerListener(self: *Manager, comptime T: type, callee: *const fn (T) anyerror!void) !void {
    const call = @as(*const fn (*void) anyerror!void, @ptrCast(callee));

    if (self.subs.getPtr(@typeName(T))) |list| {
        for (list.*.items) |*item| {
            if (@intFromPtr(item.calls) == @intFromPtr(callee)) {
                // Ignore a reregistered event

                return;
            }
        }

        try list.append(.{ .calls = call });
    } else {
        var new_list: std.array_list.Managed(Listener(*void)) = .init(allocator);

        try new_list.append(.{ .calls = call });

        try self.subs.put(@typeName(T), new_list);
    }
}

pub inline fn sendEvent(self: *Manager, data: anytype) !void {
    const T = @TypeOf(data);
    const name: []const u8 = @typeName(T);

    for ((self.subs.get(name) orelse return).items) |sub| {
        const call = @as(*const fn (T) anyerror!void, @ptrCast(sub.calls));
        try call(data);
    }
}
