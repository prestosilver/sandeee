const std = @import("std");
const tex = @import("texture.zig");
const allocator = @import("allocator.zig");

const log = @import("log.zig").log;

const Self = @This();

pub var instance: Self = .{};

textures: std.StringHashMap(*tex.Texture) = .init(allocator.alloc),

pub fn deinit(self: *Self) void {
    var iter = self.textures.iterator();

    while (iter.next()) |entry| {
        allocator.alloc.free(entry.key_ptr.*);

        // destroy texture
        entry.value_ptr.*.deinit();
        allocator.alloc.destroy(entry.value_ptr.*);
    }

    self.textures.deinit();
}

pub fn remove(self: *Self, name: []const u8) void {
    if (self.textures.fetchRemove(name)) |val| {
        allocator.alloc.free(val.key);
        val.value.deinit();
        allocator.alloc.destroy(val.value);
    }
}

pub fn put(self: *Self, name: []const u8, texture: tex.Texture) !void {
    if (self.textures.fetchRemove(name)) |val| {
        allocator.alloc.free(val.key);
        val.value.deinit();
        allocator.alloc.destroy(val.value);
    }

    const new = try allocator.alloc.dupe(u8, name);
    const adds = try allocator.alloc.create(tex.Texture);
    adds.* = texture;

    try self.textures.put(new, adds);

    log.debug("New texture: '{s}'", .{std.fmt.fmtSliceEscapeUpper(name)});
}

pub fn putMem(self: *Self, name: []const u8, texture: []const u8) !void {
    if (self.textures.fetchRemove(name)) |val| {
        allocator.alloc.free(val.key);
        val.value.deinit();
        allocator.alloc.destroy(val.value);
    }

    const new = try allocator.alloc.dupe(u8, name);
    const adds = try allocator.alloc.create(tex.Texture);
    adds.* = tex.Texture.init();

    try adds.*.loadMem(texture);
    try adds.*.upload();

    try self.textures.put(new, adds);
}

pub fn get(self: *Self, name: []const u8) ?*tex.Texture {
    if (std.mem.eql(u8, name, ""))
        return null;

    return self.textures.get(name);
}
