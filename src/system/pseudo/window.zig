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
const vecs = @import("../../math/vecs.zig");
const sb = @import("../../util/spritebatch.zig");
const windowedState = @import("../../states/windowed.zig");

pub var wintex: *tex.Texture = undefined;
pub var shader: *shd.Shader = undefined;

pub var vmIdx: u8 = 0;
pub var windowsPtr: *std.ArrayList(win.Window) = undefined;

// /fake/win/new
pub fn readWinNew(vmInstance: ?*vm.VM) ![]const u8 {
    const result = try allocator.alloc.alloc(u8, 1);
    const winDat = try vmwin.new(vmIdx, shader);

    const window = win.Window.new("win", win.WindowData{
        .source = rect.Rectangle{
            .x = 0.0,
            .y = 0.0,
            .w = 1.0,
            .h = 1.0,
        },
        .contents = winDat,
        .active = true,
    });

    try events.EventManager.instance.sendEvent(winev.EventCreateWindow{ .window = window });

    result[0] = vmIdx;
    vmIdx = vmIdx +% 1;

    const windowId = try allocator.alloc.dupe(u8, result);
    try vmInstance.?.miscData.put("window", windowId);

    return result;
}

pub fn writeWinNew(_: []const u8, _: ?*vm.VM) !void {
    return;
}

// /fake/win/size

pub fn readWinSize(vmInstance: ?*vm.VM) ![]const u8 {
    const result = try allocator.alloc.alloc(u8, 4);
    @memset(result, 0);

    if (vmInstance == null) return result;

    if (vmInstance.?.miscData.get("window")) |aid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            const item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid[0]) {
                    const x = std.mem.asBytes(&@as(u16, @intFromFloat(item.data.pos.w)));
                    const y = std.mem.asBytes(&@as(u16, @intFromFloat(item.data.pos.h)));
                    @memcpy(result[0..2], x);
                    @memcpy(result[2..4], y);
                    return result;
                }
            }
        }
    }

    return result;
}

pub fn writeWinSize(data: []const u8, vmInstance: ?*vm.VM) !void {
    if (vmInstance.?.miscData.get("window")) |aid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            const item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid[0]) {
                    const x = @as(f32, @floatFromInt(@as(*const u16, @ptrCast(@alignCast(&data[0]))).*));
                    const y = @as(f32, @floatFromInt(@as(*const u16, @ptrCast(@alignCast(&data[2]))).*));
                    item.data.pos.w = x;
                    item.data.pos.h = y;

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
    const aid = id[0];

    if (vmInstance.?.miscData.get("window")) |aaid| {
        if (aid != aaid[0]) return;

        for (windowsPtr.*.items, 0..) |_, idx| {
            const item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aid) {
                    item.data.shouldClose = true;
                    return;
                }
            }
        }
    }
}

// /fake/win/open

pub fn readWinOpen(vmInstance: ?*vm.VM) ![]const u8 {
    const result = try allocator.alloc.alloc(u8, 1);
    @memset(result, 0);

    if (vmInstance == null) return result;

    if (vmInstance.?.miscData.get("window")) |aid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            const item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

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

pub fn readWinRules(_: ?*vm.VM) ![]const u8 {
    const result = try allocator.alloc.alloc(u8, 0);

    return result;
}

pub fn writeWinRules(data: []const u8, vmInstance: ?*vm.VM) !void {
    if (vmInstance.?.miscData.get("window")) |aaid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            const item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

                if (self.idx == aaid[0]) {
                    if (std.mem.eql(u8, data[0..3], "min")) {
                        if (data[3..].len < 4) {
                            return;
                        }
                        const x = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[3..5]).*));
                        const y = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[5..7]).*));
                        item.data.contents.props.size.min.x = x;
                        item.data.contents.props.size.min.y = y;
                    } else if (std.mem.eql(u8, data[0..3], "max")) {
                        if (data[3..].len < 4) {
                            return;
                        }
                        const x = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[3..5]).*));
                        const y = @as(f32, @floatFromInt(std.mem.bytesAsValue(u16, data[5..7]).*));
                        item.data.contents.props.size.max = .{ .x = x, .y = y };
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
    const aid = id[0];

    for (windowsPtr.*.items, 0..) |_, idx| {
        const item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
            const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

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
    if (vmInstance == null) return allocator.alloc.alloc(u8, 0);

    if (vmInstance.?.miscData.get("window")) |aaid| {
        for (windowsPtr.*.items, 0..) |_, idx| {
            const item = &windowsPtr.*.items[idx];
            if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
                const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

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
    const aid = id[0];

    for (windowsPtr.*.items, 0..) |_, idx| {
        const item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
            const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

            if (self.idx == aid) {
                try item.data.contents.props.setTitle(id[1..]);
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
    if (data.len < 66) {
        std.log.info("{}", .{data.len});
        return;
    }

    if (sb.textureManager.get(data[1..2]) == null) {
        std.log.info("{any}", .{data[1..2]});
        return;
    }

    const aid = data[0];

    const dst = rect.newRect(
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[2..10]))),
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[10..18]))),
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[18..26]))),
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[26..34]))),
    );

    const src = rect.newRect(
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[34..42]))) / 1024,
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[42..50]))) / 1024,
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[50..58]))) / 1024,
        @as(f32, @floatFromInt(std.mem.bytesToValue(u64, data[58..66]))) / 1024,
    );

    for (windowsPtr.*.items, 0..) |_, idx| {
        const item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
            const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

            if (self.idx == aid) {
                return self.addRect(data[1..2], src, dst);
            }
        }
    }

    return;
}

// /fake/win/text

pub fn readWinText(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeWinText(data: []const u8, _: ?*vm.VM) !void {
    if (data.len < 6) return;

    const aid = data[0];

    const dst = vecs.newVec2(
        @as(f32, @floatFromInt(std.mem.bytesToValue(u16, data[1..3]))),
        @as(f32, @floatFromInt(std.mem.bytesToValue(u16, data[3..5]))),
    );

    const text = data[5..];

    for (windowsPtr.*.items, 0..) |_, idx| {
        const item = &windowsPtr.*.items[idx];
        if (std.mem.eql(u8, item.data.contents.props.info.kind, "vm")) {
            const self = @as(*vmwin.VMData, @ptrCast(@alignCast(item.data.contents.ptr)));

            if (self.idx == aid) {
                return self.addText(dst, text);
            }
        }
    }

    return;
}

// /fake/win

pub fn setupFakeWin(parent: *files.Folder) !*files.Folder {
    const result = try allocator.alloc.create(files.Folder);
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

    file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/win/text", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readWinText,
        .pseudoWrite = writeWinText,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
