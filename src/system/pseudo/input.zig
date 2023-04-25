const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmWin = @import("../../windows/vm.zig");
const vm = @import("../vm.zig");
const pwindows = @import("window.zig");

// /fake/inp/char

pub fn readInputChar(vmInstance: ?*vm.VM) ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 1);

    result[0] = 0;

    if (vmInstance.?.input.items.len != 0)
        result[0] = vmInstance.?.input.orderedRemove(vmInstance.?.input.items.len - 1);

    return result;
}
pub fn writeInputChar(_: []const u8, _: ?*vm.VM) !void {
    return;
}

// /fake/inp/win

pub fn readInputWin(vmInstance: ?*vm.VM) ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 0);
    if (vmInstance.?.miscData.get("window")) |aid| {
        for (pwindows.windowsPtr.*.items, 0..) |_, idx| {
            var item = &pwindows.windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const alignment = @typeInfo(*vmWin.VMData).Pointer.alignment;
                var self = @ptrCast(*vmWin.VMData, @alignCast(alignment, item.data.contents.ptr));

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
    var result = try allocator.alloc.alloc(u8, 3);

    if (vmInstance.?.miscData.get("window")) |aid| {
        for (pwindows.windowsPtr.*.items, 0..) |_, idx| {
            var item = &pwindows.windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const alignment = @typeInfo(*vmWin.VMData).Pointer.alignment;
                var self = @ptrCast(*vmWin.VMData, @alignCast(alignment, item.data.contents.ptr));

                if (self.idx == aid[0]) {
                    result[0] = 255;
                    if (self.mousebtn != null)
                        result[0] = @intCast(u8, self.mousebtn.?);
                    result[1] = @floatToInt(u8, self.mousepos.x);
                    result[2] = @floatToInt(u8, self.mousepos.y);

                    return result;
                }
            }
        }
    }

    std.mem.set(u8, result, 0);
    return result;
}
pub fn writeInputMouse(_: []const u8, _: ?*vm.VM) !void {
    return;
}
pub fn setupFakeInp(parent: *files.Folder) !*files.Folder {
    var result = try allocator.alloc.create(files.Folder);
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
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readInputChar,
        .pseudoWrite = writeInputChar,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/inp/win", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readInputWin,
        .pseudoWrite = writeInputWin,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/inp/mouse", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readInputMouse,
        .pseudoWrite = writeInputMouse,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
