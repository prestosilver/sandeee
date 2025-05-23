const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vm_window = @import("../../windows/vm.zig");
const vm = @import("../vm.zig");
const pwindows = @import("window.zig");

pub const char = struct {
    pub fn read(vm_instance: ?*vm.VM) ![]const u8 {
        if (vm_instance != null and vm_instance.?.input.items.len != 0) {
            const result = try allocator.alloc.alloc(u8, 1);

            result[0] = vm_instance.?.input.orderedRemove(0);

            return result;
        }

        return &.{};
    }
};

pub const win = struct {
    pub fn read(vm_instance: ?*vm.VM) ![]const u8 {
        var result: []u8 = &.{};
        if (vm_instance == null) return result;

        if (vm_instance.?.misc_data.get("window")) |aid| {
            for (pwindows.windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self: *vm_window.VMData = @ptrCast(@alignCast(item.data.contents.ptr));

                    if (self.idx == aid[0]) {
                        result = try allocator.alloc.realloc(result, self.input.len * 2);
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
    pub fn read(vm_instance: ?*vm.VM) ![]const u8 {
        const result = try allocator.alloc.alloc(u8, 5);
        @memset(result, 0);

        if (vm_instance == null) return result;

        if (vm_instance.?.misc_data.get("window")) |aid| {
            for (pwindows.windows_ptr.*.items) |item| {
                if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                    const self: *vm_window.VMData = @ptrCast(@alignCast(item.data.contents.ptr));

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
