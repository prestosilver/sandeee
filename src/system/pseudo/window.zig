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
pub var windows_ptr: *std.array_list.Managed(*Window) = undefined;

pub var vm_idx: u8 = 0;

pub const new = struct {
    pub fn read(vm_instance: ?*Vm) files.FileError![]const u8 {
        const result = try allocator.alloc(u8, 1);
        const window_data = try VmWindow.init(vm_idx, shader);

        const window: Window = .atlas("win", .{
            .source = Rect{ .w = 1, .h = 1 },
            .contents = window_data,
            .active = true,
        });

        events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window }) catch {
            return error.InvalidPsuedoData;
        };

        result[0] = vm_idx;
        vm_idx = vm_idx +% 1;

        const window_id = try allocator.dupe(u8, result);
        try vm_instance.?.misc_data.put("window", window_id);

        return result;
    }
};

pub const open = struct {
    pub fn read(vm_instance: ?*Vm) files.FileError![]const u8 {
        const result = try allocator.alloc(u8, 1);
        @memset(result, 0);

        if (vm_instance == null) return result;

        if (vm_instance.?.misc_data.get("window")) |aid| {
            for (windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                    if (self.idx == aid[0]) {
                        result[0] = 1;
                        return result;
                    }
                }
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

            for (windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                    if (self.idx == aid) {
                        item.data.should_close = true;
                        return;
                    }
                }
            }
        }
    }
};

pub const render = struct {
    pub fn write(data: []const u8, _: ?*Vm) files.FileError!void {
        if (data.len < 66) {
            log.warn("data for write too short {} not 66", .{data.len});
            return;
        }

        if (TextureManager.instance.get(data[1..2]) == null) {
            log.warn("texture {any} is missing", .{data[1..2]});
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

        for (windows_ptr.*.items) |item| {
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid) {
                    return self.addRect(data[1..2], src, dst);
                }
            }
        }

        return;
    }
};

pub const flip = struct {
    pub fn write(id: []const u8, _: ?*Vm) files.FileError!void {
        if (id.len != 1) return;
        const aid = id[0];

        for (windows_ptr.*.items) |item| {
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid) {
                    self.flip() catch
                        return error.OutOfMemory;
                    return;
                }
            }
        }

        return;
    }
};

pub const clear = struct {
    pub fn write(id: []const u8, _: ?*Vm) files.FileError!void {
        if (id.len != 1) return;
        const aid = id[0];

        for (windows_ptr.*.items) |item| {
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid) {
                    self.clear() catch return error.OutOfMemory;

                    return;
                }
            }
        }

        return;
    }
};

pub const title = struct {
    pub fn read(vm_instance: ?*Vm) files.FileError![]const u8 {
        if (vm_instance == null) return &.{};

        if (vm_instance.?.misc_data.get("window")) |aaid| {
            for (windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                    if (self.idx == aaid[0]) {
                        return allocator.dupe(u8, item.data.contents.props.info.name);
                    }
                }
            }
        }

        return &.{};
    }

    pub fn write(id: []const u8, _: ?*Vm) files.FileError!void {
        if (id.len < 2) return;
        const aid = id[0];

        for (windows_ptr.*.items) |item| {
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid) {
                    try item.data.contents.props.setTitle(id[1..]);
                    return;
                }
            }
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
            for (windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                    if (self.idx == aid[0]) {
                        const x = std.mem.asBytes(&@as(u16, @intFromFloat(self.size.x)));
                        const y = std.mem.asBytes(&@as(u16, @intFromFloat(self.size.y)));
                        @memcpy(result[0..2], x);
                        @memcpy(result[2..4], y);

                        return result;
                    }
                }
            }
        }

        return result;
    }

    pub fn write(data: []const u8, vm_instance: ?*Vm) files.FileError!void {
        if (vm_instance.?.misc_data.get("window")) |aid| {
            for (windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                    if (self.idx == aid[0]) {
                        const x = @as(f32, @floatFromInt(@as(*const u16, @ptrCast(@alignCast(&data[0]))).*));
                        const y = @as(f32, @floatFromInt(@as(*const u16, @ptrCast(@alignCast(&data[2]))).*));
                        item.data.pos.w = x;
                        item.data.pos.h = y;

                        item.data.contents.moveResize(item.data.pos) catch {
                            return error.OutOfMemory;
                        };

                        return;
                    }
                }
            }
        }

        return;
    }
};

pub const rules = struct {
    pub fn write(data: []const u8, vm_instance: ?*Vm) files.FileError!void {
        if (vm_instance.?.misc_data.get("window")) |aaid| {
            for (windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                    if (self.idx == aaid[0]) {
                        if (std.mem.eql(u8, data[0..3], "clr")) {
                            if (data[3..].len < 7 or data[3] != '#') {
                                return error.InvalidPsuedoData;
                            }
                            const color = Color.parseColor(data[3..][1..7].*) catch {
                                return error.InvalidPsuedoData;
                            };
                            item.data.contents.props.clear_color = color;
                        } else if (std.mem.eql(u8, data[0..3], "min")) {
                            if (data[3..].len < 4) {
                                return error.InvalidPsuedoData;
                            }
                            const x = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[3..5]).*));
                            const y = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[5..7]).*));
                            item.data.contents.props.size.min.x = x;
                            item.data.contents.props.size.min.y = y;
                        } else if (std.mem.eql(u8, data[0..3], "max")) {
                            if (data[3..].len < 4) {
                                return error.InvalidPsuedoData;
                            }
                            const x = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[3..5]).*));
                            const y = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[5..7]).*));
                            item.data.contents.props.size.max = .{ .x = x, .y = y };
                        } else {
                            return error.InvalidPsuedoData;
                        }

                        return;
                    }
                }
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

        for (windows_ptr.*.items) |item| {
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*VmWindow.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid) {
                    return self.addText(dst, to_write);
                }
            }
        }

        return;
    }
};
