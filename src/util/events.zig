const std = @import("std");
const allocator = @import("allocator.zig");

pub var em: EventManager = undefined;

pub fn init() void {
    em = EventManager.init();
}

pub fn deinit() void {
    em.deinit();
}

pub const EventManager = struct {
    fn Listener(comptime T: type) type {
        return struct {
            name: []const u8,
            calls: *const fn (T) bool,
        };
    }

    subs: std.ArrayList(Listener(*void)),

    pub fn init() EventManager {
        var subs = std.ArrayList(Listener(*void)).init(allocator.alloc);

        return EventManager{
            .subs = subs,
        };
    }

    pub fn deinit(self: *EventManager) void {
        self.subs.deinit();
    }

    pub fn registerListener(self: *EventManager, comptime T: type, callee: *const fn (T) bool) void {
        for (self.subs.items) |*item| {
            if (@ptrToInt(item.calls) == @ptrToInt(callee)) {
                return;
            }
        }

        var call = @ptrCast(*const fn (*void) bool, callee);
        var listener = Listener(*void){
            .name = @typeName(T),
            .calls = call,
        };

        self.subs.append(listener) catch {};
    }

    pub fn sendEvent(self: *EventManager, data: anytype) void {
        const T = @TypeOf(data);

        const name: []const u8 = @typeName(T);
        for (self.subs.items) |sub| {
            var call = @ptrCast(*const fn (T) bool, sub.calls);
            if (std.mem.eql(u8, sub.name, name) and call(data)) {
                break;
            }
        }
    }
};
