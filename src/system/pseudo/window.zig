const std = @import("std");
const c = @import("../../c.zig");

const system = @import("../../system.zig");
const drawers = @import("../../drawers.zig");
const windows = @import("../../windows.zig");
const events = @import("../../events.zig");
const states = @import("../../states.zig");
const math = @import("../../math.zig");
const util = @import("../../util.zig");

const files = system.files;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Color = math.Color;

const VmWindow = windows.vm;

const EventManager = events.EventManager;
const window_events = events.windows;

const Window = drawers.Window;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const allocator = util.allocator;
const log = util.log;

const Vm = system.Vm;

const Windowed = states.Windowed;

pub var wintex: *Texture = undefined;
pub var shader: *Shader = undefined;

pub const new = struct {
    pub fn read(vm_instance: ?*Vm) files.FileError![]const u8 {
        var result: std.array_list.Managed(u8) = try .initCapacity(allocator, 1);
        defer result.deinit();

        const window_data = try VmWindow.init(shader);
        const window: Window = .atlas("win", .{
            .source = Rect{ .w = 1, .h = 1 },
            .contents = window_data,
            .active = true,
        });

        events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window }) catch {
            return error.InvalidPsuedoData;
        };

        result.appendAssumeCapacity(
            @as(*VmWindow.VMData, @ptrCast(@alignCast(window_data.ptr))).id,
        );

        const window_id = try allocator.dupe(u8, result.items);
        try vm_instance.?.misc_data.put("window", window_id);

        return try result.toOwnedSlice();
    }
};

pub const open = struct {
    pub fn read(vm_instance: ?*Vm) files.FileError![]const u8 {
        const result = try allocator.alloc(u8, 1);
        @memset(result, 0);

        if (vm_instance == null) return result;

        if (vm_instance.?.misc_data.get("window")) |aid| {
            if (VmWindow.VMData.used_ids[@intCast(aid[0])] != null) {
                result[0] = 1;

                return result;
            }
        }

        return result;
    }
};

pub const destroy = struct {
    pub fn write(id: []const u8, vm_instance: ?*Vm) files.FileError!void {
        if (id.len != 1) return;
        const aid = id[0];

        if (vm_instance.?.misc_data.get("window")) |aaid| {
            if (aid != aaid[0]) return;

            if (VmWindow.VMData.used_ids[aid]) |self| {
                self.tags.should_close = true;

                return;
            }
        }
    }
};

pub const render = struct {
    pub fn write(data: []const u8, _: ?*Vm) files.FileError!void {
        if (data.len < 66) {
            log.warn("Data for window render too short {} less than 66", .{data.len});
            return;
        }

        if (TextureManager.instance.get(data[1..2]) == null) {
            log.warn("texture id {x} is missing", .{data[1..2]});
            return;
        }

        const aid = data[0];

        const dst = Rect{
            .x = @floatFromInt(std.mem.bytesToValue(u64, data[2..10])),
            .y = @floatFromInt(std.mem.bytesToValue(u64, data[10..18])),
            .w = @floatFromInt(std.mem.bytesToValue(u64, data[18..26])),
            .h = @floatFromInt(std.mem.bytesToValue(u64, data[26..34])),
        };

        const src = Rect{
            .x = @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[34..42]))) / 1024,
            .y = @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[42..50]))) / 1024,
            .w = @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[50..58]))) / 1024,
            .h = @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[58..66]))) / 1024,
        };

        if (VmWindow.VMData.used_ids[aid]) |self| {
            return self.addRect(data[1..2], src, dst);
        }

        return;
    }
};

pub const flip = struct {
    pub fn write(id: []const u8, _: ?*Vm) files.FileError!void {
        if (id.len != 1) return;
        const aid = id[0];

        if (VmWindow.VMData.used_ids[aid]) |self| {
            self.flip() catch
                return error.OutOfMemory;
            return;
        }

        return;
    }
};

pub const clear = struct {
    pub fn write(id: []const u8, _: ?*Vm) files.FileError!void {
        if (id.len != 1) return;
        const aid = id[0];

        if (VmWindow.VMData.used_ids[aid]) |self| {
            self.clear() catch return error.OutOfMemory;

            return;
        }

        return;
    }
};

pub const title = struct {
    pub fn read(vm_instance: ?*Vm) files.FileError![]const u8 {
        if (vm_instance == null) return &.{};

        if (vm_instance.?.misc_data.get("window")) |aid| {
            if (VmWindow.VMData.used_ids[aid[0]]) |self| {
                if (self.tags.title_ptr) |title_ptr|
                    return allocator.dupe(u8, title_ptr.*);
            }
        }

        return &.{};
    }

    pub fn write(id: []const u8, _: ?*Vm) files.FileError!void {
        if (id.len < 2) return;
        const aid = id[0];

        if (VmWindow.VMData.used_ids[aid]) |self| {
            self.tags.set_title = try allocator.dupe(u8, id[1..]);

            return;
        }

        return;
    }
};

pub const size = struct {
    pub fn read(vm_instance: ?*Vm) files.FileError![]const u8 {
        const result = try allocator.alloc(u8, 4);
        @memset(result, 0);

        if (vm_instance == null) return result;

        if (vm_instance.?.misc_data.get("window")) |aid| {
            if (VmWindow.VMData.used_ids[aid[0]]) |self| {
                const x = std.mem.asBytes(&@as(u16, @intFromFloat(self.size.x)));
                const y = std.mem.asBytes(&@as(u16, @intFromFloat(self.size.y)));
                @memcpy(result[0..2], x);
                @memcpy(result[2..4], y);

                return result;
            }
        }

        return result;
    }

    pub fn write(data: []const u8, vm_instance: ?*Vm) files.FileError!void {
        if (vm_instance.?.misc_data.get("window")) |aid| {
            if (VmWindow.VMData.used_ids[aid[0]]) |self| {
                const x = @as(f32, @floatFromInt(@as(*const u16, @ptrCast(@alignCast(&data[0]))).*));
                const y = @as(f32, @floatFromInt(@as(*const u16, @ptrCast(@alignCast(&data[2]))).*));
                self.tags.size = .{ .x = x, .y = y };

                return;
            }
        }

        return;
    }
};

pub const rules = struct {
    pub fn write(data: []const u8, vm_instance: ?*Vm) files.FileError!void {
        if (vm_instance.?.misc_data.get("window")) |aid| {
            if (VmWindow.VMData.used_ids[aid[0]]) |self| {
                if (std.mem.eql(u8, data[0..3], "clr")) {
                    if (data[3..].len < 7 or data[3] != '#') {
                        return error.InvalidPsuedoData;
                    }
                    const color = Color.parseColor(data[3..][1..7].*) catch {
                        return error.InvalidPsuedoData;
                    };
                    self.tags.color = color;
                } else if (std.mem.eql(u8, data[0..3], "min")) {
                    if (data[3..].len < 4) {
                        return error.InvalidPsuedoData;
                    }
                    const x = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[3..5]).*));
                    const y = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[5..7]).*));
                    self.tags.min_size = .{ .x = x, .y = y };
                } else if (std.mem.eql(u8, data[0..3], "max")) {
                    if (data[3..].len < 4) {
                        return error.InvalidPsuedoData;
                    }
                    const x = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[3..5]).*));
                    const y = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[5..7]).*));
                    self.tags.max_size = .{ .x = x, .y = y };
                } else {
                    return error.InvalidPsuedoData;
                }

                return;
            }
        }
        return;
    }
};

pub const text = struct {
    pub fn write(data: []const u8, _: ?*Vm) files.FileError!void {
        if (data.len < 6) return;

        const aid = data[0];

        const dst = Vec2{
            .x = @as(f32, @floatFromInt(std.mem.bytesToValue(u16, data[1..3]))),
            .y = @as(f32, @floatFromInt(std.mem.bytesToValue(u16, data[3..5]))),
        };

        const to_write = data[5..];

        if (VmWindow.VMData.used_ids[aid]) |self| {
            return self.addText(dst, to_write);
        }

        return;
    }
};
