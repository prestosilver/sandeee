const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const network = @import("../network.zig");
const vm = @import("../vm.zig");

pub fn writeNetRecv(data: []const u8, vmInstance: ?*vm.VM) !void {
    var client = network.Client{
        .port = data[0],
        .host = data[1..],
    };

    var recvData = try client.send("");

    try vmInstance.?.miscData.put("recvData", recvData);
}

pub fn readNetRecv(vmInstance: ?*vm.VM) ![]const u8 {
    if (vmInstance.?.miscData.get("recvData")) |result| {
        _ = vmInstance.?.miscData.remove("recvData");
        return result;
    }

    return allocator.alloc.alloc(u8, 0);
}

pub fn writeNetSend(data: []const u8, _: ?*vm.VM) !void {
    try network.server.send(data[0], data[1..]);
}

pub fn readNetSend(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn setupFakeNet(parent: *files.Folder) !*files.Folder {
    var result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/net/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    var file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/net/send", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readNetSend,
        .pseudoWrite = writeNetSend,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/net/recv", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readNetRecv,
        .pseudoWrite = writeNetRecv,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
