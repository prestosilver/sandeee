const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const network = @import("../network.zig");

var recvData: ?[]const u8 = null;

pub fn writeNetRecv(data: []const u8) !void {
    var client = network.Client{
        .port = data[0],
        .host = data[1..],
    };

    recvData = try client.send("");
    std.log.info("{?s}", .{recvData});
}

pub fn readNetRecv() ![]const u8 {
    if (recvData) |result| {
        recvData = null;
        return result;
    }

    return allocator.alloc.alloc(u8, 0);
}

pub fn writeNetSend(data: []const u8) !void {
    try network.server.send(data[0], data[1..]);
}

pub fn readNetSend() ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn setupFakeNet(parent: *files.Folder) !files.Folder {
    var result = files.Folder{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/net/", .{}),
        .subfolders = std.ArrayList(files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/net/send", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readNetSend,
        .pseudoWrite = writeNetSend,
        .parent = undefined,
    });

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/net/recv", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readNetRecv,
        .pseudoWrite = writeNetRecv,
        .parent = undefined,
    });

    return result;
}
