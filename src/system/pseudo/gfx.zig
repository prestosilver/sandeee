const std = @import("std");
const c = @import("../../c.zig");

const system = @import("../mod.zig");

const drawers = @import("../../drawers/mod.zig");
const windows = @import("../../windows/mod.zig");
const events = @import("../../events/mod.zig");
const states = @import("../../states/mod.zig");
const math = @import("../../math/mod.zig");
const util = @import("../../util/mod.zig");

const Vm = system.Vm;
const files = system.files;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Color = math.Color;

const VmWindow = windows.Vm;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const EventManager = events.EventManager;
const window_events = events.windows;

const Window = drawers.Window;

pub var texture_idx: u8 = 0;

pub const new = struct {
    pub fn read(_: ?*Vm) files.FileError![]const u8 {
        const result = try allocator.alloc.alloc(u8, 1);

        result[0] = texture_idx;

        {
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            try TextureManager.instance.put(result, Texture.init());
        }

        texture_idx = texture_idx +% 1;

        return result;
    }
};

pub const pixel = struct {
    pub fn write(data: []const u8, _: ?*Vm) files.FileError!void {
        const idx = data[0];
        var tmp = data[1..];

        const texture = TextureManager.instance.get(&.{idx}) orelse return;

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
    pub fn write(data: []const u8, _: ?*Vm) files.FileError!void {
        graphics.Context.makeCurrent();
        defer graphics.Context.makeNotCurrent();

        const idx = data[0];
        TextureManager.instance.remove(&.{idx});
    }
};

pub const upload = struct {
    pub fn write(data: []const u8, _: ?*Vm) files.FileError!void {
        if (data.len == 1) {
            const idx = data[0];

            const texture = TextureManager.instance.get(&.{idx}) orelse return;
            try texture.upload();

            return;
        }

        const idx = data[0];
        const image = data[1..];

        const texture = TextureManager.instance.get(&.{idx}) orelse return;
        texture.loadMem(image) catch {
            return error.InvalidPsuedoData;
        };
        texture.upload() catch {
            return error.InvalidPsuedoData;
        };
    }
};

pub const save = struct {
    pub fn write(data: []const u8, vm_instance: ?*Vm) files.FileError!void {
        const idx = data[0];
        const image = data[1..];

        const texture = TextureManager.instance.get(&.{idx}) orelse return;

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
