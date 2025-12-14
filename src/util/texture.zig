const std = @import("std");
const zgl = @import("zgl");

const util = @import("mod.zig");

const system = @import("../system/mod.zig");
const math = @import("../math/mod.zig");

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;
const Color = math.Color;

const graphics = util.graphics;
const allocator = util.allocator;
const log = util.log;

const files = system.files;

const Texture = @This();

tex: zgl.Texture = .invalid,
size: Vec2,
old_size: Vec2 = .{},
buffer: [][4]u8,

pub fn deinit(self: *const Texture) void {
    allocator.alloc.free(self.buffer);
    self.tex.delete();
}

pub inline fn setPixel(self: *const Texture, x: i32, y: i32, color: [4]u8) void {
    if (x >= @as(i32, @intFromFloat(self.size.x)) or y >= @as(i32, @intFromFloat(self.size.y))) return;

    const idx: usize = @intCast(x + @as(i32, @intFromFloat(self.size.x)) * y);

    self.buffer[idx] = color;
}

pub fn upload(self: *Texture) !void {
    graphics.Context.makeCurrent();
    defer graphics.Context.makeNotCurrent();

    if (self.tex == .invalid) {
        self.tex = zgl.genTexture();
        self.tex.bind(.@"2d");
        self.tex.parameter(.min_filter, .nearest);
        self.tex.parameter(.mag_filter, .nearest);
    } else {
        self.tex.bind(.@"2d");
    }

    if (self.size.x == 0 or self.size.y == 0) return;

    if (self.size.x == self.old_size.x and
        self.size.y == self.old_size.y)
    {
        self.tex.subImage2D(0, 0, 0, @intFromFloat(self.size.x), @intFromFloat(self.size.y), .rgba, .unsigned_byte, @ptrCast(self.buffer));
    } else {
        zgl.textureImage2D(.@"2d", 0, .rgba, @intFromFloat(self.size.x), @intFromFloat(self.size.y), .rgba, .unsigned_byte, @ptrCast(self.buffer));
        self.old_size = self.size;
    }
}

pub fn init() Texture {
    return .{
        .buffer = &.{},
        .size = .{ .x = 0, .y = 0 },
    };
}

pub fn resize(self: *Texture, size: Vec2) !void {
    self.buffer = try allocator.alloc.realloc(self.buffer, @intFromFloat(size.x * size.y));
    self.size = size;
}

pub fn loadMem(self: *Texture, mem: []const u8) !void {
    const width = @as(c_int, @intCast(mem[4])) + @as(c_int, @intCast(mem[5])) * 256;
    const height = @as(c_int, @intCast(mem[6])) + @as(c_int, @intCast(mem[7])) * 256;

    if (mem.len / 4 - 2 != width * height) {
        log.err("new expected {} got {}", .{ width * height, mem.len / 4 - 2 });

        return error.WrongSize;
    }

    try self.resize(.{
        .x = @floatFromInt(width),
        .y = @floatFromInt(height),
    });

    @memcpy(std.mem.sliceAsBytes(self.buffer), mem[8..]);
}

pub fn loadFile(self: *Texture, file: []const u8) !void {
    const root = try files.FolderLink.resolve(.root);
    const image = try root.getFile(file);
    const cont = try image.read(null);

    return self.loadMem(cont);
}

pub const imageError = error{
    WrongSize,
    NotFound,
};

const errorImage = @embedFile("error.eia");
