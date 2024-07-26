const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmWin = @import("../../windows/vm.zig");
const vm = @import("../vm.zig");
const pwindows = @import("window.zig");

// /fake/inp/char

pub fn readInputChar(vmInstance: ?*vm.VM) ![]const u8 {
    if (vmInstance != null and vmInstance.?.input.items.len != 0) {
        const result = try allocator.alloc.alloc(u8, 1);

        result[0] = vmInstance.?.input.orderedRemove(0);

        return result;
    }

    const result = try allocator.alloc.alloc(u8, 0);

    return result;
}

pub fn writeInputChar(_: []const u8, _: ?*vm.VM) !void {
    return;
}

// /fake/inp/win

pub fn readInputWin(vmInstance: ?*vm.VM) ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 0);
    if (vmInstance == null) return result;

    if (vmInstance.?.miscData.get("window")) |aid| {
        for (pwindows.windowsPtr.*.items, 0..) |_, idx| {
            const item = &pwindows.windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self: *vmWin.VMData = @ptrCast(@alignCast(item.data.contents.ptr));

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

pub fn writeInputWin(_: []const u8, _: ?*vm.VM) !void {
    return;
}

// /fake/inp/mouse

pub fn readInputMouse(vmInstance: ?*vm.VM) ![]const u8 {
    const result = try allocator.alloc.alloc(u8, 5);
    @memset(result, 0);

    if (vmInstance == null) return result;

    if (vmInstance.?.miscData.get("window")) |aid| {
        for (pwindows.windowsPtr.*.items, 0..) |_, idx| {
            const item = &pwindows.windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self: *vmWin.VMData = @ptrCast(@alignCast(item.data.contents.ptr));

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

pub fn writeInputMouse(_: []const u8, _: ?*vm.VM) !void {
    return;
}

pub fn setupFakeInp(parent: *files.Folder) !*files.Folder {
    const result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/inp/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    var file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/inp/char", .{}),
        .pseudoRead = readInputChar,
        .pseudoWrite = writeInputChar,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/inp/win", .{}),
        .pseudoRead = readInputWin,
        .pseudoWrite = writeInputWin,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/inp/mouse", .{}),
        .pseudoRead = readInputMouse,
        .pseudoWrite = writeInputMouse,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
