const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const rect = @import("../../math/rects.zig");
const vecs = @import("../../math/vecs.zig");
const sb = @import("../../util/spritebatch.zig");
const cols = @import("../../math/colors.zig");
const vm = @import("../vm.zig");
const graphics = @import("../../util/graphics.zig");
const texture_manager = @import("../../util/texmanager.zig");
const tex = @import("../../util/texture.zig");

pub var texture_idx: u8 = 0;

pub const new = struct {
    pub fn read(_: ?*vm.VM) files.FileError![]const u8 {
        const result = try allocator.alloc.alloc(u8, 1);

        result[0] = texture_idx;

        {
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            try texture_manager.TextureManager.instance.put(result, tex.Texture.init());
        }

        texture_idx = texture_idx +% 1;

        return result;
    }
};

pub const pixel = struct {
    pub fn write(data: []const u8, _: ?*vm.VM) files.FileError!void {
        const idx = data[0];
        var tmp = data[1..];

        const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;

        while (tmp.len > 7) {
            const x = std.mem.bytesToValue(u16, tmp[0..2]);
            const y = std.mem.bytesToValue(u16, tmp[2..4]);

            texture.setPixel(x, y, tmp[4..8].*);

            if (tmp.len > 8)
                tmp = tmp[8..]
            else
                break;
        }
    }
};

pub const destroy = struct {
    pub fn write(data: []const u8, _: ?*vm.VM) files.FileError!void {
        const idx = data[0];
        const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;

        {
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            texture.deinit();
        }

        const key = texture_manager.TextureManager.instance.textures.getKeyPtr(&.{idx}) orelse return;
        allocator.alloc.free(key.*);

        _ = texture_manager.TextureManager.instance.textures.removeByPtr(key);
    }
};

pub const upload = struct {
    pub fn write(data: []const u8, _: ?*vm.VM) files.FileError!void {
        if (data.len == 1) {
            const idx = data[0];

            const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;
            try texture.upload();

            return;
        }

        const idx = data[0];
        const image = data[1..];

        const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;
        texture.loadMem(image) catch {
            return error.InvalidPsuedoData;
        };
        texture.upload() catch {
            return error.InvalidPsuedoData;
        };
    }
};

pub const save = struct {
    pub fn write(data: []const u8, vm_instance: ?*vm.VM) files.FileError!void {
        const idx = data[0];
        const image = data[1..];

        const texture = texture_manager.TextureManager.instance.get(&.{idx}) orelse return;

        if (vm_instance) |vmi| {
            const root = try vmi.root.resolve();
            try root.newFile(image);

            const conts = try std.mem.concat(allocator.alloc, u8, &.{
                "eimg",
                std.mem.asBytes(&@as(i16, @intFromFloat(texture.size.x))),
                std.mem.asBytes(&@as(i16, @intFromFloat(texture.size.y))),
                std.mem.sliceAsBytes(texture.buffer),
            });
            defer allocator.alloc.free(conts);

            try root.writeFile(image, conts, null);
        }
    }
};
