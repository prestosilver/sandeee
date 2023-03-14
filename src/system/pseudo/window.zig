const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const tex = @import("../../texture.zig");
const gfx = @import("gfx.zig");
const rect = @import("../../math/rects.zig");
const shd = @import("../../shader.zig");

pub var wintex: *tex.Texture = undefined;
pub var shader: *shd.Shader = undefined;

pub var vmIdx: u8 = 0;
pub var windowsPtr: *std.ArrayList(win.Window) = undefined;

// /fake/win/new
pub fn readWinNew() ![]const u8 {
    var result: *u8 = try allocator.alloc.create(u8);
    var winDat = try vmwin.new(vmIdx, shader);

    var window = win.Window.new(wintex, win.WindowData{
        .pos = rect.Rectangle{
            .x = 100,
            .y = 100,
            .w = 400,
            .h = 300,
        },
        .source = rect.Rectangle{
            .x = 0.0,
            .y = 0.0,
            .w = 1.0,
            .h = 1.0,
        },
        .contents = winDat,
        .active = true,
    });

    events.em.sendEvent(winev.EventCreateWindow{ .window = window });

    result.* = vmIdx;
    vmIdx = vmIdx +% 1;

    return @ptrCast(*[1]u8, result);
}

pub fn writeWinNew(_: []const u8) !void {
    return;
}

// /fake/win/destroy

pub fn readWinDestroy() ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinDestroy(id: []const u8) !void {
    if (id.len != 1) return;
    var aid = id[0];

    for (windowsPtr.*.items) |_, idx| {
        var item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.kind, "vm")) {
            const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
            var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

            if (self.idx == aid) {
                try item.data.deinit();
                _ = windowsPtr.*.orderedRemove(idx);
                return;
            }
        }
    }
}

// /fake/win/open

pub fn readWinOpen() ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinOpen(_: []const u8) !void {
    return;
}

// /fake/win/flip

pub fn readWinFlip() ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinFlip(id: []const u8) !void {
    if (id.len != 1) return;
    var aid = id[0];

    for (windowsPtr.*.items) |_, idx| {
        var item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.kind, "vm")) {
            const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
            var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

            if (self.idx == aid) {
                self.flip();
                return;
            }
        }
    }

    return;
}

// /fake/win/render

pub fn readWinRender() ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinRender(data: []const u8) !void {
    if (data.len < 66) return;

    var texture = gfx.textures.getPtr(data[0]);
    if (texture == null) return;

    var aid = data[1];

    var dst = rect.newRect(
        @intToFloat(f32, std.mem.bytesToValue(u64, data[2..10])),
        @intToFloat(f32, std.mem.bytesToValue(u64, data[10..18])),
        @intToFloat(f32, std.mem.bytesToValue(u64, data[18..26])),
        @intToFloat(f32, std.mem.bytesToValue(u64, data[26..34])),
    );

    var src = rect.newRect(
        @intToFloat(f32, std.mem.bytesToValue(u64, data[34..42])) / 1024,
        @intToFloat(f32, std.mem.bytesToValue(u64, data[42..50])) / 1024,
        @intToFloat(f32, std.mem.bytesToValue(u64, data[50..58])) / 1024,
        @intToFloat(f32, std.mem.bytesToValue(u64, data[58..66])) / 1024,
    );

    for (windowsPtr.*.items) |_, idx| {
        var item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.kind, "vm")) {
            const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
            var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

            if (self.idx == aid) {
                return self.addRect(texture.?, src, dst);
            }
        }
    }

    return;
}

// /fake/win

pub fn setupFakeWin(parent: *files.Folder) !files.Folder {
    var result = files.Folder{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/", .{}),
        .subfolders = std.ArrayList(files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/new", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinNew,
        .pseudoWrite = writeWinNew,
        .parent = undefined,
    });

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/destroy", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinDestroy,
        .pseudoWrite = writeWinDestroy,
        .parent = undefined,
    });

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/render", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinRender,
        .pseudoWrite = writeWinRender,
        .parent = undefined,
    });

    try result.contents.append(files.File{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/flip", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinFlip,
        .pseudoWrite = writeWinFlip,
        .parent = undefined,
    });

    return result;
}
