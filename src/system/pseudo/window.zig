const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const tex = @import("../../util/texture.zig");
const gfx = @import("gfx.zig");
const rect = @import("../../math/rects.zig");
const shd = @import("../../util/shader.zig");
const vm = @import("../vm.zig");

pub var wintex: *tex.Texture = undefined;
pub var shader: *shd.Shader = undefined;

pub var vmIdx: u8 = 0;
pub var windowsPtr: *std.ArrayList(win.Window) = undefined;

// /fake/win/new
pub fn readWinNew(vmInstance: ?*vm.VM) ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 1);
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

    result[0] = vmIdx;
    vmIdx = vmIdx +% 1;

    var windowId = try allocator.alloc.dupe(u8, result);
    try vmInstance.?.miscData.put("window", windowId);

    return result;
}

pub fn writeWinNew(_: []const u8, _: ?*vm.VM) !void {
    return;
}

// /fake/win/size

pub fn readWinSize(vmInstance: ?*vm.VM) ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 4);
    if (vmInstance.?.miscData.get("window")) |aid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            var item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
                var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

                if (self.idx == aid[0]) {
                    var x = std.mem.asBytes(&@floatToInt(u16, item.data.pos.w));
                    var y = std.mem.asBytes(&@floatToInt(u16, item.data.pos.h));
                    std.mem.copy(u8, result[0..2], x);
                    std.mem.copy(u8, result[2..4], y);
                    return result;
                }
            }
        }
    }

    std.mem.set(u8, result, 0);
    return result;
}

pub fn writeWinSize(data: []const u8, vmInstance: ?*vm.VM) !void {
    if (vmInstance.?.miscData.get("window")) |aid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            var item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
                var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

                if (self.idx == aid[0]) {
                    var x = @intToFloat(f32, @ptrCast(*const u16, @alignCast(@alignOf(u16), &data[0])).*);
                    var y = @intToFloat(f32, @ptrCast(*const u16, @alignCast(@alignOf(u16), &data[2])).*);
                    item.data.pos.w = x;
                    item.data.pos.h = y;

                    std.log.info("{any}, {}, {}", .{ data, @floatToInt(i32, x), @floatToInt(i32, y) });
                    return;
                }
            }
        }
    }

    return;
}

// /fake/win/destroy

pub fn readWinDestroy(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinDestroy(id: []const u8, vmInstance: ?*vm.VM) !void {
    if (id.len != 1) return;
    var aid = id[0];

    if (vmInstance.?.miscData.get("window")) |aaid| {
        if (aid != aaid[0]) return;

        for (windowsPtr.*.items, 0..) |_, idx| {
            var item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
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
}

// /fake/win/open

pub fn readWinOpen(vmInstance: ?*vm.VM) ![]const u8 {
    var result = try allocator.alloc.alloc(u8, 1);
    result[0] = 0;

    if (vmInstance.?.miscData.get("window")) |aid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            var item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
                var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

                if (self.idx == aid[0]) {
                    result[0] = 1;
                    return result;
                }
            }
        }
    }

    return result;
}

pub fn writeWinOpen(_: []const u8, _: ?*vm.VM) !void {
    return;
}

// /fake/win/rules

pub fn readWinRules(vmInstance: ?*vm.VM) ![]const u8 {
    _ = vmInstance;
    var result = try allocator.alloc.alloc(u8, 0);

    return result;
}

pub fn writeWinRules(data: []const u8, vmInstance: ?*vm.VM) !void {
    if (vmInstance.?.miscData.get("window")) |aaid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            var item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
                var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

                if (self.idx == aaid) {
                    if (std.mem.eql(u8, data[0..3], "min")) {
                        if (data.len[3..].len < 4) {
                            return;
                        }
                        item.data.contents.props.size.min.x = @intToFloat(f32, data[4]);
                        item.data.contents.props.size.min.y = @intToFloat(f32, data[5]);
                        item.data.contents.props.size.min.w = @intToFloat(f32, data[6]);
                        item.data.contents.props.size.min.h = @intToFloat(f32, data[7]);
                    } else if (std.mem.eql(u8, data[0..3], "max")) {
                        if (data.len[3..].len < 4) {
                            return;
                        }
                        item.data.contents.props.size.max.x = @intToFloat(f32, data[4]);
                        item.data.contents.props.size.max.y = @intToFloat(f32, data[5]);
                        item.data.contents.props.size.max.w = @intToFloat(f32, data[6]);
                        item.data.contents.props.size.max.h = @intToFloat(f32, data[7]);
                    }
                    return;
                }
            }
        }
    }
    return;
}

// /fake/win/flip

pub fn readWinFlip(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinFlip(id: []const u8, _: ?*vm.VM) !void {
    if (id.len != 1) return;
    var aid = id[0];

    for (windowsPtr.*.items, 0..) |_, idx| {
        var item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
            const alignment = @alignOf(vmwin.VMData);
            var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

            if (self.idx == aid) {
                self.flip();
                return;
            }
        }
    }

    return;
}

// /fake/win/title

pub fn readWinTitle(vmInstance: ?*vm.VM) ![]const u8 {
    if (vmInstance.?.miscData.get("window")) |aaid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            var item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const alignment = @alignOf(vmwin.VMData);
                var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

                if (self.idx == aaid[0]) {
                    return allocator.alloc.dupe(u8, item.data.contents.props.info.name);
                }
            }
        }
    }

    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinTitle(id: []const u8, _: ?*vm.VM) !void {
    if (id.len < 2) return;
    var aid = id[0];

    for (windowsPtr.*.items, 0..) |_, idx| {
        var item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
            const alignment = @typeInfo(*vmwin.VMData).Pointer.alignment;
            var self = @ptrCast(*vmwin.VMData, @alignCast(alignment, item.data.contents.ptr));

            if (self.idx == aid) {
                item.data.contents.props.info.name = try allocator.alloc.dupe(u8, id[1..]);
                return;
            }
        }
    }

    return;
}

// /fake/win/render

pub fn readWinRender(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinRender(data: []const u8, _: ?*vm.VM) !void {
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

    for (windowsPtr.*.items, 0..) |_, idx| {
        var item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
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

pub fn setupFakeWin(parent: *files.Folder) !*files.Folder {
    var result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    var file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/new", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinNew,
        .pseudoWrite = writeWinNew,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/open", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinOpen,
        .pseudoWrite = writeWinOpen,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/destroy", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinDestroy,
        .pseudoWrite = writeWinDestroy,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/render", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinRender,
        .pseudoWrite = writeWinRender,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/flip", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinFlip,
        .pseudoWrite = writeWinFlip,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/title", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinTitle,
        .pseudoWrite = writeWinTitle,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/size", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinSize,
        .pseudoWrite = writeWinSize,
        .parent = undefined,
    };

    try result.contents.append(file);

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/rules", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinRules,
        .pseudoWrite = writeWinRules,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
