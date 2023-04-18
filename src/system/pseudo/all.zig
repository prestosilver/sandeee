const std = @import("std");
const files = @import("../files.zig");
const allocator = @import("../../util/allocator.zig");
pub const win = @import("window.zig");
pub const inp = @import("input.zig");
pub const gfx = @import("gfx.zig");
pub const snd = @import("snd.zig");
pub const net = @import("net.zig");

pub fn setupFake(parent: *files.Folder) !*files.Folder {
    var result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    if (!@import("builtin").is_test) {
        try result.subfolders.append(try win.setupFakeWin(result));
        try result.subfolders.append(try gfx.setupFakeGfx(result));
        try result.subfolders.append(try snd.setupFakeSnd(result));
        try result.subfolders.append(try net.setupFakeNet(result));
        try result.subfolders.append(try inp.setupFakeInp(result));
    }

    return result;
}
