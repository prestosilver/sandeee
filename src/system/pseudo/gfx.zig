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
const texMan = @import("../../util/texmanager.zig");
const cols = @import("../../math/colors.zig");

pub var texIdx: u8 = 0;

pub fn readGfxNew(_: ?*vm.VM) files.FileError![]const u8 {
    const result = try allocator.alloc.alloc(u8, 1);

    result[0] = texIdx;

    {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        try texMan.TextureManager.instance.put(result, try tex.newTextureSize(vecs.newVec2(0, 0)));
    }

    texIdx = texIdx +% 1;

    return result;
}

pub fn writeGfxNew(_: []const u8, _: ?*vm.VM) files.FileError!void {
    return;
}

// /fake/gfx/destroy

pub fn readGfxDestroy(_: ?*vm.VM) files.FileError![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxDestroy(data: []const u8, _: ?*vm.VM) files.FileError!void {
    const idx = data[0];
    const texture = texMan.TextureManager.instance.get(&.{idx}) orelse return;

    {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        texture.deinit();
    }

    const key = texMan.TextureManager.instance.textures.getKeyPtr(&.{idx}) orelse return;
    allocator.alloc.free(key.*);

    _ = texMan.TextureManager.instance.textures.removeByPtr(key);
}

// /fake/gfx/upload

pub fn readGfxUpload(_: ?*vm.VM) files.FileError![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxUpload(data: []const u8, _: ?*vm.VM) files.FileError!void {
    if (data.len == 1) {
        const idx = data[0];

        const texture = texMan.TextureManager.instance.get(&.{idx}) orelse return;

        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        texture.upload();

        return;
    }

    const idx = data[0];
    const image = data[1..];

    const texture = texMan.TextureManager.instance.get(&.{idx}) orelse return;

    tex.uploadTextureMem(texture, image) catch {
        return error.InvalidPsuedoData;
    };
}

// /fake/gfx/save

pub fn readGfxSave(_: ?*vm.VM) files.FileError![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxSave(data: []const u8, vmInstance: ?*vm.VM) files.FileError!void {
    const idx = data[0];
    const image = data[1..];

    const texture = texMan.TextureManager.instance.get(&.{idx}) orelse return;

    if (vmInstance) |vmi| {
        try vmi.root.newFile(image);

        const conts = try std.mem.concat(allocator.alloc, u8, &.{
            "eimg",
            std.mem.asBytes(&@as(i16, @intFromFloat(texture.size.x))),
            std.mem.asBytes(&@as(i16, @intFromFloat(texture.size.y))),
            std.mem.sliceAsBytes(texture.buffer),
        });
        defer allocator.alloc.free(conts);

        try vmi.root.writeFile(image, conts, null);
    }
}

// /fake/gfx/pixel

pub fn readGfxPixel(_: ?*vm.VM) files.FileError![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeGfxPixel(data: []const u8, _: ?*vm.VM) files.FileError!void {
    const idx = data[0];
    var tmp = data[1..];

    const texture = texMan.TextureManager.instance.get(&.{idx}) orelse return;

    while (tmp.len > 7) {
        const x = std.mem.bytesToValue(u16, tmp[0..2]);
        const y = std.mem.bytesToValue(u16, tmp[2..4]);

        texture.setPixel(x, y, tmp[4..8].*);

        if (tmp.len > 8)
            tmp = tmp[8..]
        else
            break;
    }
}

// /fake/gfx

pub fn setupFakeGfx(parent: *files.Folder) !*files.Folder {
    const result = try allocator.alloc.create(files.Folder);
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
        .pseudoRead = readGfxNew,
        .pseudoWrite = writeGfxNew,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/pixel", .{}),
        .pseudoRead = readGfxPixel,
        .pseudoWrite = writeGfxPixel,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/destroy", .{}),
        .pseudoRead = readGfxDestroy,
        .pseudoWrite = writeGfxDestroy,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/upload", .{}),
        .pseudoRead = readGfxUpload,
        .pseudoWrite = writeGfxUpload,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/gfx/save", .{}),
        .pseudoRead = readGfxSave,
        .pseudoWrite = writeGfxSave,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
