const std = @import("std");
const allocator = @import("allocator.zig");
const texMan = @import("texmanager.zig");
const tex = @import("texture.zig");
const files = @import("../system/files.zig");

const log = @import("log.zig").log;

pub const ElnData = struct {
    name: []const u8,
    icon: ?u8 = null,
    launches: []const u8,

    var texture: u8 = 0;
    var textures: std.StringHashMap(u8) = std.StringHashMap(u8).init(allocator.alloc);

    pub fn parse(file: *files.File) !ElnData {
        const ext_idx = std.mem.lastIndexOf(u8, file.name, ".") orelse file.name.len;
        const folder_idx = std.mem.lastIndexOf(u8, file.name, "/") orelse file.name.len;

        var result = ElnData{
            .name = file.name[folder_idx..],
            .icon = null,
            .launches = file.name[folder_idx..ext_idx],
        };

        const conts = try file.read(null);
        var split = std.mem.split(u8, conts, "\n");
        while (split.next()) |entry| {
            const colon_idx = std.mem.indexOf(u8, entry, ":") orelse continue;
            const prop = std.mem.trim(u8, entry[0..colon_idx], " ");
            const value = std.mem.trim(u8, entry[colon_idx + 1 ..], " ");
            if (std.mem.eql(u8, prop, "name")) {
                result.name = value;
            } else if (std.mem.eql(u8, prop, "icon")) {
                if (textures.get(value)) |idx| {
                    result.icon = idx;
                } else {
                    const name = .{ 'e', 'l', 'n', texture };
                    if (tex.newTextureFile(value) catch null) |tmp_tex| {
                        try texMan.TextureManager.instance.put(&name, tmp_tex);
                    } else {
                        log.err("Failed to load image {s}", .{value});
                    }
                    try textures.put(value, texture);
                    result.icon = texture;

                    texture += 1;
                }
            } else if (std.mem.eql(u8, prop, "runs")) {
                result.launches = value;
            }
        }

        return result;
    }
};
