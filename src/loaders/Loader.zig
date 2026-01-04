const std = @import("std");

const util = @import("../util.zig");

const allocator = util.allocator;
const graphics = util.graphics;
const c = @import("../c.zig");

const log = util.log;

const Self = @This();

const Vtable = struct {
    load: *const fn (*const anyopaque) anyerror!void,
    unload: *const fn (*const anyopaque) void,
};

ptr: *const anyopaque,
vtable: *const Vtable,
loaded: bool = false,
deps: std.array_list.Managed(*Self) = .init(allocator),
name: []const u8,

pub fn init(data: anytype) !Self {
    const Ptr = @TypeOf(data);
    const ptr_info = @typeInfo(*Ptr);

    const ptr = try allocator.create(Ptr);
    ptr.* = data;

    const gen = struct {
        fn loadImpl(pointer: *const anyopaque) !void {
            const self: *const Ptr = @ptrCast(@alignCast(pointer));

            return @call(.always_inline, ptr_info.pointer.child.load, .{self});
        }

        fn unloadImpl(pointer: *const anyopaque) void {
            const self: *const Ptr = @ptrCast(@alignCast(pointer));

            @call(.always_inline, ptr_info.pointer.child.unload, .{self});

            allocator.destroy(self);
        }

        const vtable = Vtable{
            .load = loadImpl,
            .unload = unloadImpl,
        };
    };

    return Self{
        .ptr = ptr,
        .vtable = &gen.vtable,
        .name = @typeName(Ptr),
    };
}

pub fn require(self: *Self, other: *Self) !void {
    try self.deps.append(other);
}

pub fn load(self: *Self, prog: *f32, start: f32, total: f32) !Unloader {
    var result = Unloader{
        .vtable = self.vtable,
        .ptr = self.ptr,
        .name = self.name,
    };

    if (self.deps.items.len > 0) {
        const prog_step = (total - start) / @as(f32, @floatFromInt(self.deps.items.len + 1));

        for (self.deps.items, 0..) |dep, i| {
            const item_prog = prog_step * @as(f32, @floatFromInt(i));

            if (!dep.loaded)
                try result.add(try dep.load(prog, start + item_prog, start + item_prog + prog_step));
        }
    }

    try self.vtable.load(self.ptr);
    self.loaded = true;

    log.debug("loaded {s} ({}%)", .{ self.name, @as(usize, @intFromFloat(total * 100)) });

    prog.* = total;

    self.deps.clearAndFree();

    return result;
}

pub const Unloader = struct {
    deps: std.array_list.Managed(Unloader) = .init(allocator),
    vtable: *const Vtable,
    ptr: *const anyopaque,
    name: []const u8,

    pub fn add(self: *Unloader, other: Unloader) !void {
        try self.deps.append(other);
    }

    pub fn run(self: *Unloader) void {
        self.vtable.unload(self.ptr);

        log.debug("unloaded {s}", .{self.name});

        var iter = std.mem.reverseIterator(self.deps.items);

        while (iter.nextPtr()) |dep|
            dep.run();

        self.deps.clearAndFree();
    }
};
