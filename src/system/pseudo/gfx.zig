const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const tex = @import("../../texture.zig");
const rect = @import("../../math/rects.zig");
const vecs = @import("../../math/vecs.zig");
const gfx = @import("../../graphics.zig");

pub var texIdx: u8 = 0;
pub var textures: std.AutoHashMap(u8, tex.Texture) = undefined;

pub fn readGfxNew() ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 1);

    result[0] = texIdx;

    gfx.gContext.makeCurrent();

    try textures.put(texIdx, tex.newTextureSize(vecs.newVec2(0, 0)));

    gfx.gContext.makeNotCurrent();

    texIdx = texIdx +% 1;

    return result;
}

pub fn writeGfxNew(_: []const u8) !void {
    return;
}

// /fake/gfx/destroy

pub fn readGfxDestroy() ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxDestroy(data: []const u8) !void {
    var idx = data[0];
    var texture = textures.get(idx);
    if (texture == null) return;

    gfx.gContext.makeCurrent();

    tex.freeTexture(&texture.?);

    gfx.gContext.makeNotCurrent();

    _ = textures.remove(idx);
}

// /fake/gfx/upload

pub fn readGfxUpload() ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxUpload(data: []const u8) !void {
    var idx = data[0];
    var image = data[1..];

    var texture = textures.getPtr(idx);
    if (texture == null) return;

    gfx.gContext.makeCurrent();

    tex.uploadTextureMem(texture.?, image) catch return error.UploadError;

    gfx.gContext.makeNotCurrent();
}

// /fake/gfx

pub fn setupFakeGfx(parent: *files.Folder) !files.Folder {
    var result = files.Folder{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/", .{}),
        .subfolders = std.ArrayList(files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    textures = std.AutoHashMap(u8, tex.Texture).init(allocator.alloc);

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/new", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readGfxNew,
        .pseudoWrite = writeGfxNew,
        .parent = undefined,
    });

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/destroy", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readGfxDestroy,
        .pseudoWrite = writeGfxDestroy,
        .parent = undefined,
    });

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/upload", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readGfxUpload,
        .pseudoWrite = writeGfxUpload,
        .parent = undefined,
    });

    return result;
}
