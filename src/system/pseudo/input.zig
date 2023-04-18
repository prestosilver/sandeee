const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmWin = @import("../../windows/vm.zig");
const vm = @import("../vm.zig");
const pwindows = @import("window.zig");

const windowsPtr = pwindows.windowsPtr;

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

    return result;
}
