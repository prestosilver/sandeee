const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const tex = @import("../../util/texture.zig");
const rect = @import("../../math/rects.zig");
const shd = @import("../../util/shader.zig");
const audio = @import("../../util/audio.zig");
const vm = @import("../vm.zig");

// snd play

pub fn readSndPlay(_: ?*vm.VM) ![]const u8 {
    return &.{};
}

pub fn writeSndPlay(data: []const u8, _: ?*vm.VM) !void {
    if (data.len == 0) return;

    const snd = audio.Sound.init(data);
    defer snd.deinit();

    try audio.instance.playSound(snd);
}

// /fake/win

pub fn setupFakeSnd(parent: *files.Folder) !*files.Folder {
    const result = try allocator.alloc.create(files.Folder);
    result.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/snd/", .{}),
        .subfolders = std.ArrayList(*files.Folder).init(allocator.alloc),
        .contents = std.ArrayList(*files.File).init(allocator.alloc),
        .parent = .link(parent),
        .protected = true,
    };

    const file = try allocator.alloc.create(files.File);
    file.* = .{
        .name = try std.fmt.allocPrint(allocator.alloc, "/fake/snd/play", .{}),
        .data = .{
            .Pseudo = .{
                .pseudo_read = readSndPlay,
                .pseudo_write = writeSndPlay,
            },
        },
        .parent = .link(result),
    };

    try result.contents.append(file);

    return result;
}
