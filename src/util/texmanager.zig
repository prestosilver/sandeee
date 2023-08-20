const std = @import("std");
const tex = @import("texture.zig");
const allocator = @import("allocator.zig");

pub const TextureManager = struct {
    pub var instance: TextureManager = undefined;

    textures: std.StringHashMap(*tex.Texture),

    pub fn init() void {
        instance = .{
            .textures = std.StringHashMap(*tex.Texture).init(allocator.alloc),
        };
    }

    pub fn deinit() void {
        var iter = instance.textures.iterator();

        while (iter.next()) |entry| {
            allocator.alloc.free(entry.key_ptr.*);

            // destroy texture
            entry.value_ptr.*.deinit();
            allocator.alloc.destroy(entry.value_ptr.*);
        }

        instance.textures.deinit();
    }

    pub fn put(self: *TextureManager, name: []const u8, texture: tex.Texture) !void {
        const new = self.textures.getKey(name) orelse try allocator.alloc.dupe(u8, name);
        const adds = try allocator.alloc.create(tex.Texture);
        adds.* = texture;

        try self.textures.put(new, adds);
    }

    pub fn putMem(self: *TextureManager, name: []const u8, texture: []const u8) !void {
        const new = self.textures.getKey(name) orelse try allocator.alloc.dupe(u8, name);
        const adds = try allocator.alloc.create(tex.Texture);
        adds.* = try tex.newTextureMem(texture);

        try self.textures.put(new, adds);
    }

    pub fn get(self: *TextureManager, name: []const u8) ?*tex.Texture {
        return self.textures.get(name);
    }
};
