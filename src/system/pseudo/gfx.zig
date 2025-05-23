const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const rect = @import("../../math/rects.zig");
const vecs = @import("../../math/vecs.zig");
const gfx = 
const sb = @import("../../util/spritebatch.zig");
const cols = @import("../../math/colors.zig");


// /fake/gfx/destroy

pub fn readGfxDestroy(_: ?*vm.VM) files.FileError![]const u8 {
    return &.{};
}


// /fake/gfx/upload

pub fn readGfxUpload(_: ?*vm.VM) files.FileError![]const u8 {
    return &.{};
}


// /fake/gfx/save

pub fn readGfxSave(_: ?*vm.VM) files.FileError![]const u8 {
    return &.{};
}


// /fake/gfx

pub fn setupFakeGfx(parent: *files.Folder) !*files.Folder {
    const result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = .link(parent),
        .protected = true,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/pixel", .{}),
        .data = .{
            .Pseudo = .{
                .pseudo_read = readGfxPixel,
                .pseudo_write = writeGfxPixel,
            },
        },
        .parent = .link(result),
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/destroy", .{}),
        .data = .{
            .Pseudo = .{
                .pseudo_read = readGfxDestroy,
                .pseudo_write = writeGfxDestroy,
            },
        },
        .parent = .link(result),
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/upload", .{}),
        .data = .{
            .Pseudo = .{
                .pseudo_read = readGfxUpload,
                .pseudo_write = writeGfxUpload,
            },
        },
        .parent = .link(result),
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/save", .{}),
        .data = .{
            .Pseudo = .{
                .pseudo_read = readGfxSave,
                .pseudo_write = writeGfxSave,
            },
        },
        .parent = .link(result),
    };

    try result.contents.append(file);

    return result;
}
