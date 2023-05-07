const std = @import("std");
const tex = @import("texture.zig");
const allocator = @import("allocator.zig");

pub const TextureManager = struct {
    textures: std.StringHashMap(tex.Texture),

    pub fn init() TextureManager {
        return .{
            .textures = std.StringHashMap(tex.Texture).init(allocator.alloc),
        };
    }

    pub fn deinit(self: *TextureManager) !void {
        var iter = self.textures.iterator();

        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }

        self.textures.deinit();
    }

    pub fn putMem(self: *TextureManager, name: []const u8, texture: []const u8) !void {
        if (self.textures.fetchRemove(name)) |old| {
            old.value.deinit();
        }

        try self.textures.put(name, try tex.newTextureMem(texture));
    }

    pub fn get(self: *TextureManager, name: []const u8) ?*tex.Texture {
        return self.textures.getPtr(name);
    }
};
