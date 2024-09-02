const std = @import("std");
const vecs = @import("../math/vecs.zig");
const c = @import("../c.zig");
const files = @import("../system/files.zig");
const gfx = @import("graphics.zig");
const cols = @import("../math/colors.zig");
const allocator = @import("allocator.zig");

const log = @import("../util/log.zig").log;

pub const Texture = struct {
    tex: c.GLuint = 0,
    size: vecs.Vector2,
    old_size: vecs.Vector2 = .{},
    buffer: [][4]u8,

    pub fn deinit(self: *const Texture) void {
        allocator.alloc.free(self.buffer);
        c.glDeleteTextures(1, &self.tex);
    }

    pub inline fn setPixel(self: *const Texture, x: i32, y: i32, color: [4]u8) void {
        if (x >= @as(i32, @intFromFloat(self.size.x)) or y >= @as(i32, @intFromFloat(self.size.y))) return;

        const idx: usize = @intCast(x + @as(i32, @intFromFloat(self.size.x)) * y);

        self.buffer[idx] = color;
    }

    pub fn upload(self: *Texture) !void {
        gfx.Context.makeCurrent();
        defer gfx.Context.makeNotCurrent();

        if (self.tex == 0) {
            c.glGenTextures(1, &self.tex);

            c.glBindTexture(c.GL_TEXTURE_2D, self.tex);

            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        } else {
            c.glBindTexture(c.GL_TEXTURE_2D, self.tex);
        }

        if (self.size.x == 0 or self.size.y == 0) return;

        if (self.size.x == self.old_size.x and
            self.size.y == self.old_size.y)
        {
            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, 0, 0, @intFromFloat(self.size.x), @intFromFloat(self.size.y), c.GL_RGBA, c.GL_UNSIGNED_BYTE, self.buffer.ptr);
        } else {
            c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intFromFloat(self.size.x), @intFromFloat(self.size.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, self.buffer.ptr);
            self.old_size = self.size;
        }
    }

    pub fn init() Texture {
        return .{
            .buffer = &.{},
            .size = .{ .x = 0, .y = 0 },
        };
    }

    pub fn resize(self: *Texture, size: vecs.Vector2) !void {
        self.buffer = try allocator.alloc.realloc(self.buffer, @intFromFloat(size.x * size.y));
        self.size = size;
    }

    pub fn loadMem(self: *Texture, mem: []const u8) !void {
        const width = @as(c_int, @intCast(mem[4])) + @as(c_int, @intCast(mem[5])) * 256;
        const height = @as(c_int, @intCast(mem[6])) + @as(c_int, @intCast(mem[7])) * 256;

        if (mem.len / 4 - 2 != width * height) {
            log.err("new expected {} got {}", .{ width * height * 4 + 4, mem.len });

            return error.WrongSize;
        }

        try self.resize(.{
            .x = @floatFromInt(width),
            .y = @floatFromInt(height),
        });

        @memcpy(std.mem.sliceAsBytes(self.buffer), mem[8..]);
    }

    pub fn loadFile(self: *Texture, file: []const u8) !void {
        const image = try files.root.getFile(file);
        const cont = try image.read(null);

        return self.loadMem(cont);
    }
};

pub const imageError = error{
    WrongSize,
    NotFound,
};

const errorImage = @embedFile("../images/error.eia");
