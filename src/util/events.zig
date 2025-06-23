const std = @import("std");
const allocator = @import("allocator.zig");

const log = @import("../util/log.zig").log;

pub const EventManager = struct {
    pub var instance: EventManager = .{};

    subs: std.StringHashMap([]Listener(*void)) = std.StringHashMap([]Listener(*void)).init(allocator.alloc),

    pub fn deinit() void {
        var iter = instance.subs.iterator();
        while (iter.next()) |item| {
            allocator.alloc.free(@as([]Listener(*void), item.value_ptr.*));
        }

        instance.subs.deinit();
    }

    fn Listener(comptime T: type) type {
        return struct {
            calls: *const fn (T) anyerror!void,
        };
    }

    pub fn registerListener(self: *EventManager, comptime T: type, callee: *const fn (T) anyerror!void) !void {
        const call = @as(*const fn (*void) anyerror!void, @ptrCast(callee));

        if (self.subs.getPtr(@typeName(T))) |list| {
            for (list.*) |*item| {
                if (@intFromPtr(item.calls) == @intFromPtr(callee)) {
                    return;
                }
            }

            const listener = Listener(*void){
                .calls = call,
            };

            list.* = try allocator.alloc.realloc(list.*, list.len + 1);
            list.*[list.len - 1] = listener;
        } else {
            const list = try allocator.alloc.alloc(Listener(*void), 1);
            list[0] = Listener(*void){
                .calls = call,
            };

            try self.subs.put(@typeName(T), list);
        }
    }

    pub inline fn sendEvent(self: *EventManager, data: anytype) !void {
        const T = @TypeOf(data);
        const name: []const u8 = @typeName(T);

        for (self.subs.get(name) orelse return) |sub| {
            const call = @as(*const fn (T) anyerror!void, @ptrCast(sub.calls));
            try call(data);
        }
    }
};
