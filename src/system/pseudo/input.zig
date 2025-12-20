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

const headless = system.headless;
const Vm = system.Vm;

const Windowed = states.Windowed;

const pWindows = @import("window.zig");

pub const char = struct {
    pub fn read(vm_instance: ?*Vm) ![]const u8 {
        if (vm_instance == null)
            return &.{};

        if (headless.is_headless) {
            headless.input_mutex.lock();
            defer headless.input_mutex.unlock();
            const result = try allocator.alloc(u8, 1);

            result[0] = headless.popInput() orelse {
                allocator.free(result);

                return &.{};
            };

            return result;
        }

        if (vm_instance.?.input.items.len != 0) {
            const result = try allocator.alloc(u8, 1);

            result[0] = vm_instance.?.input.orderedRemove(0);

            return result;
        }

        return &.{};
    }
};

pub const win = struct {
    pub fn read(vm_instance: ?*Vm) ![]const u8 {
        var result: []u8 = &.{};
        if (vm_instance == null) return result;

        if (vm_instance.?.misc_data.get("window")) |aid| {
            for (pWindows.windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self: *VmWindow.VMData = @ptrCast(@alignCast(item.data.contents.ptr));

                    if (self.idx == aid[0]) {
                        result = try allocator.realloc(result, self.input.len * 2);
                        for (self.input, 0..) |in, index| {
                            result[index * 2] = std.mem.toBytes(in)[0];
                            result[index * 2 + 1] = std.mem.toBytes(in)[1];
                        }
                        return result;
                    }
                }
            }
        }

        return result;
    }
};

pub const mouse = struct {
    pub fn read(vm_instance: ?*Vm) ![]const u8 {
        const result = try allocator.alloc(u8, 5);
        @memset(result, 0);

        if (vm_instance == null) return result;

        if (vm_instance.?.misc_data.get("window")) |aid| {
            for (pWindows.windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self: *VmWindow.VMData = @ptrCast(@alignCast(item.data.contents.ptr));

                    if (self.idx == aid[0]) {
                        result[0] = 255;
                        if (self.mousebtn) |mousebtn| {
                            result[0] = @as(u8, @intCast(mousebtn));
                        }
                        if (self.mousepos.y > 0 and self.mousepos.y < 20000)
                            std.mem.writeInt(u16, result[3..5], @as(u16, @intFromFloat(self.mousepos.y)), .big);

                        if (self.mousepos.x > 0 and self.mousepos.x < 20000)
                            std.mem.writeInt(u16, result[1..3], @as(u16, @intFromFloat(self.mousepos.x)), .big);

                        return result;
                    }
                }
            }
        }

        return result;
    }
};
