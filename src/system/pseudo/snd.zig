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
const audio = @import("../../util/audio.zig");
const vm = @import("../vm.zig");

pub var audioPtr: *audio.Audio = undefined;

// snd play

pub fn readSndPlay(_: ?*vm.VM) ![]const u8 {
    return allocator.alloc.alloc(u8, 0);
}

pub fn writeSndPlay(data: []const u8, _: ?*vm.VM) !void {
    if (data.len == 0) return;

    const snd = audio.Sound.init(data);
    defer snd.deinit();

    try audioPtr.playSound(snd);
}

// /fake/win

pub fn setupFakeSnd(parent: *files.Folder) !*files.Folder {
    const result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/snd/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = parent,
        .protected = true,
    };

    var file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/snd/play", .{}),
        .contents = try std.fmt.allocPrint(allocator.alloc, "HOW DID YOU SEE THIS", .{}),
        .pseudoRead = readSndPlay,
        .pseudoWrite = writeSndPlay,
        .parent = undefined,
    };

    try result.contents.append(file);

    return result;
}
