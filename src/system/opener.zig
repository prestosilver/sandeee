const std = @import("std");

const system = @import("mod.zig");
const drawers = @import("../drawers/mod.zig");
const util = @import("../util/mod.zig");

const Sprite = drawers.Sprite;

const Eln = util.Eln;
const allocator = util.allocator;
const log = util.log;

const files = system.files;

const OpenError = error{
    CommandNotFound,
};

const Self = @This();
pub var instance: Self = .{};

const OpenerEntry = struct {
    cmd: []const u8,
    icon: ?[]const u8,
};

types: std.StringHashMap(OpenerEntry) = .init(allocator.alloc),
cont: []const u8 = &.{},

pub fn setup(self: *Self) !void {
    const root = try files.FolderLink.resolve(.root);
    const file = try root.getFile("/conf/opener.cfg");

    const cont = try file.read(null);
    var lines = std.mem.splitScalar(u8, cont, '\n');

    while (lines.next()) |line| {
        const space_idx = std.mem.indexOf(u8, line, " ") orelse continue;
        const line_ext = line[0..space_idx];
        log.debug("opener {s}: {s}", .{ line_ext, line[space_idx + 1 ..] });

        try self.types.put(line_ext, .{
            .cmd = line[space_idx + 1 ..],
            .icon = null,
        });
    }

    self.cont = cont;
}

pub fn openFile(self: *Self, path: []const u8) ![]const u8 {
    var back = std.mem.splitBackwardsScalar(u8, path, '.');
    const ext = back.first();

    return if (self.types.get(ext)) |runs|
        runs.cmd
    else blk: {
        log.warn("no opener for {s}", .{ext});

        break :blk error.InvalidFileType;
    };
}

pub fn getIcon(self: *Self, path: []const u8) ?[]const u8 {
    var back = std.mem.splitBackwardsScalar(u8, path, '.');
    const ext = back.first();

    return if (self.types.get(ext)) |runs|
        runs.icon
    else
        null;
}

pub fn deinit(self: *Self) void {
    self.types.clearAndFree();
}
