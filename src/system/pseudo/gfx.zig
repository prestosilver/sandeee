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

pub fn readGfxNew() []const u8 {
    var result = allocator.alloc.alloc(u8, 1) catch undefined;

    result[0] = texIdx;

    gfx.gContext.makeCurrent();

    textures.put(texIdx, tex.newTextureSize(vecs.newVec2(0, 0))) catch {};

    gfx.gContext.makeNotCurrent();

    texIdx = texIdx +% 1;

    return result;
}

pub fn writeGfxNew(_: []const u8) void {
    return;
}

// /fake/gfx/destroy

pub fn readGfxDestroy() []const u8 {
    return allocator.alloc.alloc(u8, 0) catch undefined;
}

pub fn writeGfxDestroy(data: []const u8) void {
    var idx = data[0];
    var texture = textures.get(idx);
    if (texture == null) return;

    gfx.gContext.makeCurrent();

    tex.freeTexture(&texture.?);

    gfx.gContext.makeNotCurrent();

    _ = textures.remove(idx);
}

// /fake/gfx/upload

pub fn readGfxUpload() []const u8 {
    return allocator.alloc.alloc(u8, 0) catch undefined;
}

pub fn writeGfxUpload(data: []const u8) void {
    var idx = data[0];
    var image = data[1..];

    var texture = textures.getPtr(idx);
    if (texture == null) return;

    gfx.gContext.makeCurrent();

    tex.uploadTextureMem(texture.?, image) catch |msg| {
        std.log.info("upload err {}", .{msg});
        return;
    };

    gfx.gContext.makeNotCurrent();
}

// /fake/gfx

pub fn setupFakeGfx(parent: *files.Folder) files.Folder {
    var result = files.Folder{
        .name = std.fmt.allocPrint(allocator.alloc, "/fake/gfx/", .{}) catch "",
        .subfolders = std.ArrayList(files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(files.File).init(allocator.alloc),
        .parent = parent,
    };

    textures = std.AutoHashMap(u8, tex.Texture).init(allocator.alloc);

    result.contents.append(files.File{
        .name = std.fmt.allocPrint(allocator.alloc, "/fake/gfx/new", .{}) catch "",
        .contents = std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}) catch "",
        .pseudoRead = readGfxNew,
        .pseudoWrite = writeGfxNew,
        .parent = undefined,
    }) catch {};

    result.contents.append(files.File{
        .name = std.fmt.allocPrint(allocator.alloc, "/fake/gfx/destroy", .{}) catch "",
        .contents = std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}) catch "",
        .pseudoRead = readGfxDestroy,
        .pseudoWrite = writeGfxDestroy,
        .parent = undefined,
    }) catch {};

    result.contents.append(files.File{
        .name = std.fmt.allocPrint(allocator.alloc, "/fake/gfx/upload", .{}) catch "",
        .contents = std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}) catch "",
        .pseudoRead = readGfxUpload,
        .pseudoWrite = writeGfxUpload,
        .parent = undefined,
    }) catch {};

    return result;
}
