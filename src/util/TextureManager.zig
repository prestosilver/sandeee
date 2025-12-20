const std = @import("std");

const util = @import("../util.zig");

const Texture = util.Texture;
const allocator = util.allocator;
const log = util.log;

const Self = @This();

pub var instance: Self = .{};

textures: std.StringHashMap(*Texture) = .init(allocator),

pub fn deinit(self: *Self) void {
    var iter = self.textures.iterator();

    while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);

        // destroy texture
        entry.value_ptr.*.deinit();
        allocator.destroy(entry.value_ptr.*);
    }

    self.textures.deinit();
}

pub fn remove(self: *Self, name: []const u8) void {
    if (self.textures.fetchRemove(name)) |val| {
        allocator.free(val.key);
        val.value.deinit();
        allocator.destroy(val.value);
    }
}

pub fn put(self: *Self, name: []const u8, texture: Texture) !void {
    if (self.textures.fetchRemove(name)) |val| {
        allocator.free(val.key);
        val.value.deinit();
        allocator.destroy(val.value);
    }

    const new = try allocator.dupe(u8, name);
    const adds = try allocator.create(Texture);
    adds.* = texture;

    try self.textures.put(new, adds);

    log.debug("New texture: '{f}'", .{std.ascii.hexEscape(name, .upper)});
}

pub fn putMem(self: *Self, name: []const u8, texture: []const u8) !void {
    if (self.textures.fetchRemove(name)) |val| {
        allocator.free(val.key);
        val.value.deinit();
        allocator.destroy(val.value);
    }

    const new = try allocator.dupe(u8, name);
    const adds = try allocator.create(Texture);
    adds.* = Texture.init();

    try adds.*.loadMem(texture);
    try adds.*.upload();

    try self.textures.put(new, adds);
}

pub fn get(self: *Self, name: []const u8) ?*Texture {
    if (std.mem.eql(u8, name, ""))
        return null;

    return self.textures.get(name);
}
