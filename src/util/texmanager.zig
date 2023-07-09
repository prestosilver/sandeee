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
            allocator.alloc.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }

        self.textures.deinit();
    }

    pub fn put(self: *TextureManager, name: []const u8, texture: tex.Texture) !void {
        const new = self.textures.getKey(name) orelse try allocator.alloc.dupe(u8, name);

        try self.textures.put(new, texture);
    }

    pub fn putMem(self: *TextureManager, name: []const u8, texture: []const u8) !void {
        const new = self.textures.getKey(name) orelse try allocator.alloc.dupe(u8, name);

        try self.textures.put(new, try tex.newTextureMem(texture));
    }

    pub fn get(self: *TextureManager, name: []const u8) ?*tex.Texture {
        return self.textures.getPtr(name);
    }
};
