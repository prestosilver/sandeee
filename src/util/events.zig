const std = @import("std");
const allocator = @import("allocator.zig");

pub const EventManager = struct {
    pub var instance: EventManager = undefined;

    subs: std.StringHashMap([]Listener(*void)),

    pub fn init() void {
        var subs = std.StringHashMap([]Listener(*void)).init(allocator.alloc);

        instance = EventManager{
            .subs = subs,
        };
    }

    pub fn deinit() void {
        var iter = instance.subs.iterator();
        while (iter.next()) |item| {
            allocator.alloc.free(item.value_ptr.*);
        }

        instance.subs.deinit();
    }

    fn Listener(comptime T: type) type {
        return struct {
            calls: *const fn (T) bool,
        };
    }

    pub fn registerListener(self: *EventManager, comptime T: type, callee: *const fn (T) bool) !void {
        const call = @as(*const fn (*void) bool, @ptrCast(callee));

        if (self.subs.getPtr(@typeName(T))) |list| {
            for (list.*) |*item| {
                if (@intFromPtr(item.calls) == @intFromPtr(callee)) {
                    return;
                }
            }

            var listener = Listener(*void){
                .calls = call,
            };

            list.* = try allocator.alloc.realloc(list.*, list.len + 1);
            list.*[list.len - 1] = listener;
        } else {
            var list = try allocator.alloc.alloc(Listener(*void), 1);
            list[0] = Listener(*void){
                .calls = call,
            };

            try self.subs.put(@typeName(T), list);
        }
    }

    pub inline fn sendEvent(self: *EventManager, data: anytype) void {
        const T = @TypeOf(data);
        const name: []const u8 = @typeName(T);

        for (self.subs.get(name) orelse return) |sub| {
            const call = @as(*const fn (T) bool, @ptrCast(sub.calls));
            if (call(data)) {
                break;
            }
        }
    }
};
