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
const texture_manager = @import("../../util/texmanager.zig");
const cols = @import("../../math/colors.zig");

pub var texture_idx: u8 = 0;

pub fn readGfxNew(_: ?*vm.VM) files.FileError![]const u8 {
    const result = try allocator.alloc.alloc(u8, 1);

    result[0] = texture_idx;

    {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        try texture_manager.TextureManager.instance.put(result, tex.Texture.init());
    }

    texture_idx = texture_idx +% 1;

    return result;
}

pub fn writeGfxNew(_: []const u8, _: ?*vm.VM) files.FileError!void {
    return;
}

// /fake/gfx/destroy

pub fn readGfxDestroy(_: ?*vm.VM) files.FileError![]const u8 {
    return &.{};
}

pub fn writeGfxDestroy(data: []const u8, _: ?*vm.VM) files.FileError!void {
    const idx = data[0];
    const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;

    {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        texture.deinit();
    }

    const key = texture_manager.TextureManager.instance.textures.getKeyPtr(&.{idx}) orelse return;
    allocator.alloc.free(key.*);

    _ = texture_manager.TextureManager.instance.textures.removeByPtr(key);
}

// /fake/gfx/upload

pub fn readGfxUpload(_: ?*vm.VM) files.FileError![]const u8 {
    return &.{};
}

pub fn writeGfxUpload(data: []const u8, _: ?*vm.VM) files.FileError!void {
    if (data.len == 1) {
        const idx = data[0];

        const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;
        try texture.upload();

        return;
    }

    const idx = data[0];
    const image = data[1..];

    const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;
    texture.loadMem(image) catch {
        return error.InvalidPsuedoData;
    };
    texture.upload() catch {
        return error.InvalidPsuedoData;
    };
}

// /fake/gfx/save

pub fn readGfxSave(_: ?*vm.VM) files.FileError![]const u8 {
    return &.{};
}

pub fn writeGfxSave(data: []const u8, vm_instance: ?*vm.VM) files.FileError!void {
    const idx = data[0];
    const image = data[1..];

    const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;

    if (vm_instance) |vmi| {
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
    return &.{};
}

pub fn writeGfxPixel(data: []const u8, _: ?*vm.VM) files.FileError!void {
    const idx = data[0];
    var tmp = data[1..];

    const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;

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
        .data = .{
            .Pseudo = .{
                .pseudo_read = readGfxNew,
                .pseudo_write = writeGfxNew,
            },
        },
        .parent = undefined,
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
        .parent = undefined,
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
        .parent = undefined,
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
        .parent = undefined,
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
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
