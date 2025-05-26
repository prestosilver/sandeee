const std = @import("std");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../util/graphics.zig");
const c = @import("../c.zig");

pub const Font = @import("font.zig");
pub const Group = @import("group.zig");
pub const Delay = @import("delay.zig");
pub const Shader = @import("shader.zig");
pub const Files = @import("files.zig");
pub const Settings = @import("settings.zig");
pub const Texture = @import("texture.zig");
pub const Sound = @import("sound.zig");

const log = @import("../util/log.zig").log;

const Self = @This();

const Vtable = struct {
    load: *const fn (*const anyopaque) anyerror!void,
};

ptr: *const anyopaque,
vtable: *const Vtable,
loaded: bool = false,
deps: std.ArrayList(*Self) = std.ArrayList(*Self).init(allocator.alloc),
name: []const u8,

pub fn init(data: anytype) !Self {
    const Ptr = @TypeOf(data);
    const ptr_info = @typeInfo(*Ptr);

    const ptr = try allocator.alloc.create(Ptr);
    ptr.* = data;

    const gen = struct {
        fn loadImpl(pointer: *const anyopaque) !void {
            const self: *const Ptr = @ptrCast(@alignCast(pointer));

            return @call(.always_inline, ptr_info.pointer.child.load, .{self});
        }

        const vtable = Vtable{
            .load = loadImpl,
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

pub fn load(self: *Self, prog: *f32, start: f32, total: f32) !void {
    if (self.deps.items.len > 0) {
        const prog_step = (total - start) / @as(f32, @floatFromInt(self.deps.items.len + 1));

        for (self.deps.items, 0..) |dep, i| {
            const item_prog = prog_step * @as(f32, @floatFromInt(i));

            if (!dep.loaded)
                try dep.load(prog, start + item_prog, start + item_prog + prog_step);
        }
    }

    try self.vtable.load(self.ptr);
    self.loaded = true;

    log.debug("loaded {s}, {}", .{ self.name, total });

    prog.* = total;
}
