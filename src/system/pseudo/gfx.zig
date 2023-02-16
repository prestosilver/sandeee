const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const tex = @import("../../texture.zig");
const rect = @import("../../math/rects.zig");

pub var texIdx: u8 = 0;
pub var textures: *std.ArrayList(tex.Texture) = undefined;

pub fn readGfxNew() []const u8 {
    var result = allocator.alloc.alloc(u8, 1) catch undefined;

    result[0] = 0;

    return result;
}

pub fn writeGfxNew(_: []const u8) void {
    return;
}

// /fake/gfx

pub fn setupFakeGfx(parent: *files.Folder) files.Folder {
    var result = files.Folder{
        .name = std.fmt.allocPrint(allocator.alloc, "/fake/gfx/", .{}) catch "",
        .subfolders = std.ArrayList(files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(files.File).init(allocator.alloc),
        .parent = parent,
    };

    result.contents.append(files.File{
        .name = std.fmt.allocPrint(allocator.alloc, "/fake/gfx/new", .{}) catch "",
        .contents = std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}) catch "",
        .pseudoRead = readGfxNew,
        .pseudoWrite = writeGfxNew,
    }) catch {};

    //result.contents.append(files.File{
    //    .name = std.fmt.allocPrint(allocator.alloc, "/fake/gfx/destroy", .{}) catch "",
    //    .contents = std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}) catch "",
    //    .pseudoRead = readWinDestroy,
    //    .pseudoWrite = writeWinDestroy,
    //}) catch {};

    return result;
}
