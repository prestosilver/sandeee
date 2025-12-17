const std = @import("std");
const allocator = @import("../util/allocator.zig");
const log = @import("../util/log.zig").log;
const Rope = @import("../util/rope.zig");

pub const ObjectType = enum {
    free,
    value,
    string,
};

pub const ObjectData = union(ObjectType) {
    free: ?ObjectRef,
    value: u64,
    string: *Rope,
};

pub const Object = struct {
    marked: bool,
    data: ObjectData,
};

pub const ObjectRef = struct {
    id: usize,

    pub inline fn data(self: ObjectRef) *ObjectData {
        const result = &objects.items[self.id].data;

        if (result.* == .free) {
            const msg = std.fmt.allocPrint(allocator.alloc, "bad data {}", .{self.id}) catch "bad data ?";
            @panic(msg);
        }

        return result;
    }

    pub inline fn mark(self: ObjectRef) !void {
        objects.items[self.id].marked = true;
    }

    pub fn deinit(self: ObjectRef) void {
        free_lock.lock();
        defer free_lock.unlock();

        if (objects.items[self.id].data == .free) {
            log.err("Double Free", .{});
            return;
        }

        switch (self.data().*) {
            .free => {},
            .value => {},
            .string => |*str| {
                str.deinit();
            },
        }

        self.data().* = .{
            .free = free_ref,
        };

        free_ref = self;
    }
};

var objects = std.ArrayList(Object).init(allocator.alloc);
var free_ref: ?ObjectRef = null;
var free_lock = std.Thread.Mutex{};

pub fn find(addr: usize) ?ObjectRef {
    if (addr >= objects.items.len) return null;
    if (objects.items[addr].data == .free) return null;

    return .{
        .id = addr,
    };
}

pub fn new(data: ObjectData) !ObjectRef {
    free_lock.lock();
    defer free_lock.unlock();

    if (free_ref) |result| {
        free_ref = objects.items[result.id].data.free;
        objects.items[result.id].data = data;

        return result;
    }

    try objects.append(.{
        .marked = true,
        .data = data,
    });

    return .{
        .id = objects.items.len - 1,
    };
}

pub fn clean() !void {
    var rev = std.mem.reverseIterator(objects.items);

    var new_size = objects.items.len;

    while (rev.next()) |entry| {
        if (entry.data == .free) {
            new_size -= 1;
        } else {
            break;
        }
    }

    objects.shrinkAndFree(new_size);

    var prev_ref = &free_ref;

    for (objects.items, 0..) |*entry, id| {
        if (entry.data == .free) {
            prev_ref.* = .{
                .id = id,
            };

            prev_ref = &entry.data.free;
        }
    }

    prev_ref.* = null;
}

pub fn collect() !void {
    var free_count: usize = 0;

    for (objects.items, 0..) |*object, id| {
        if (object.data == .free) continue;

        if (!object.marked) {
            (ObjectRef{ .id = id }).deinit();

            free_count += 1;
        }

        object.marked = false;
    }

    if (free_count != 0) {
        const total = objects.items.len;
        var free_total: usize = 0;

        for (objects.items) |object| {
            if (object.data == .free)
                free_total += 1;
        }

        const pc =
            @as(f64, @floatFromInt(free_total)) / @as(f64, @floatFromInt(total));

        log.debug("free pc: {:0.2} ({}/{})", .{
            pc,
            free_total,
            total,
        });

        if (pc > 0.50) {
            try clean();

            log.debug("cleaned pool to length {}", .{objects.items.len});
        }

        log.debug("freed: {}", .{free_count});
    }
}

pub fn deinit() void {
    for (objects.items) |object| {
        if (object.data == .string)
            object.data.string.deinit();
    }

    objects.deinit();
}
