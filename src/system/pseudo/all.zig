const std = @import("std");
const files = @import("../files.zig");
const allocator = @import("../../util/allocator.zig");
pub const window = @import("window.zig");
pub const gfx = @import("gfx.zig");
pub const snd = @import("snd.zig");

pub fn setupFake(parent: *files.Folder) files.Folder {
    var result = files.Folder{
        .name = std.fmt.allocPrint(allocator.alloc, "/fake/", .{}) catch "",
        .subfolders = std.ArrayList(files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(files.File).init(allocator.alloc),
        .parent = parent,
    };

    result.subfolders.append(window.setupFakeWin(&result)) catch {};
    result.subfolders.append(gfx.setupFakeGfx(&result)) catch {};
    result.subfolders.append(snd.setupFakeSnd(&result)) catch {};

    return result;
}
