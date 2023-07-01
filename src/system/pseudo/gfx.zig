const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const tex = @import("../../util/texture.zig");
const rect = @import("../../math/rects.zig");
const vecs = @import("../../math/vecs.zig");
const gfx = @import("../../util/graphics.zig");
const vm = @import("../vm.zig");
const sb = @import("../../util/spritebatch.zig");
const cols = @import("../../math/colors.zig");

pub var texIdx: u8 = 0;

pub fn readGfxNew(_: ?*vm.VM) ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 1);

    result[0] = texIdx;

    gfx.gContext.makeCurrent();

    var id = try allocator.alloc.dupe(u8, result);

    try sb.textureManager.put(id, tex.newTextureSize(vecs.newVec2(0, 0)));

    gfx.gContext.makeNotCurrent();

    texIdx = texIdx +% 1;

    return result;
}

pub fn writeGfxNew(_: []const u8, _: ?*vm.VM) !void {
    return;
}

// /fake/gfx/destroy

pub fn readGfxDestroy(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxDestroy(data: []const u8, _: ?*vm.VM) !void {
    var idx = data[0];
    var texture = sb.textureManager.get(&.{idx});
    if (texture == null) return;

    gfx.gContext.makeCurrent();

    tex.freeTexture(texture.?);

    gfx.gContext.makeNotCurrent();

    _ = sb.textureManager.textures.remove(&.{idx});
}

// /fake/gfx/upload

pub fn readGfxUpload(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxUpload(data: []const u8, _: ?*vm.VM) !void {
    var idx = data[0];
    var image = data[1..];

    var texture = sb.textureManager.get(&.{idx});
    if (texture == null) return;

    try tex.uploadTextureMem(texture.?, image);
}

// /fake/gfx/pixel

pub fn readGfxPixel(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxPixel(data: []const u8, _: ?*vm.VM) !void {
    var idx = data[0];

    var texture = sb.textureManager.get(&.{idx});
    if (texture == null) return;

    gfx.gContext.makeCurrent();

    var x = std.mem.bytesToValue(u16, data[1..3]);
    var y = std.mem.bytesToValue(u16, data[3..5]);

    // std.log.debug("setPixel {}, {}", .{ x, y });

    texture.?.setPixel(x, y, cols.newColorRGBA(data[5], data[6], data[7], data[8]));

    gfx.gContext.makeNotCurrent();
}

// /fake/gfx

pub fn setupFakeGfx(parent: *files.Folder) !*files.Folder {
    var result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    var file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/new", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readGfxNew,
        .pseudoWrite = writeGfxNew,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/pixel", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readGfxPixel,
        .pseudoWrite = writeGfxPixel,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/destroy", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readGfxDestroy,
        .pseudoWrite = writeGfxDestroy,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/upload", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readGfxUpload,
        .pseudoWrite = writeGfxUpload,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
