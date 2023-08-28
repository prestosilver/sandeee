const std = @import("std");
const vecs = @import("../math/vecs.zig");
const c = @import("../c.zig");
const files = @import("../system/files.zig");
const gfx = @import("graphics.zig");
const cols = @import("../math/colors.zig");
const allocator = @import("allocator.zig");

pub const Texture = struct {
    tex: c.GLuint = 0,
    size: vecs.Vector2,
    oldSize: vecs.Vector2 = vecs.newVec2(0, 0),
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

    pub fn upload(self: *Texture) void {
        if (self.tex == 0) {
            c.glGenTextures(1, &self.tex);

            c.glBindTexture(c.GL_TEXTURE_2D, self.tex);

            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        } else {
            c.glBindTexture(c.GL_TEXTURE_2D, self.tex);
        }

        if (self.size.x == 0 or self.size.y == 0) return;

        if (self.size.x == self.oldSize.x and
            self.size.y == self.oldSize.y)
        {
            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, 0, 0, @intFromFloat(self.size.x), @intFromFloat(self.size.y), c.GL_RGBA, c.GL_UNSIGNED_BYTE, self.buffer.ptr);
        } else {
            c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intFromFloat(self.size.x), @intFromFloat(self.size.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, self.buffer.ptr);
            self.oldSize = self.size;
        }
    }
};

pub const imageError = error{
    WrongSize,
    NotFound,
};

pub fn newTextureSize(size: vecs.Vector2) !Texture {
    return Texture{
        .buffer = try allocator.alloc.alloc([4]u8, @intFromFloat(size.x * size.y)),
        .size = size,
    };
}

pub fn newTextureFile(file: []const u8) !Texture {
    const image = try files.root.getFile(file);
    const cont = try image.?.read(null);

    return newTextureMem(cont);
}

pub fn newTextureMem(mem: []const u8) !Texture {
    const width = @as(c_int, @intCast(mem[4])) + @as(c_int, @intCast(mem[5])) * 256;
    const height = @as(c_int, @intCast(mem[6])) + @as(c_int, @intCast(mem[7])) * 256;

    var result = Texture{
        .buffer = try allocator.alloc.alloc([4]u8, @intCast(width * height)),
        .size = vecs.Vector2{
            .x = @floatFromInt(width),
            .y = @floatFromInt(height),
        },
    };

    if (mem.len / 4 - 2 != width * height) {
        std.log.info("new expected {} got {}", .{ width * height * 4 + 4, mem.len });

        return error.WrongSize;
    }

    @memcpy(std.mem.sliceAsBytes(result.buffer), mem[8..]);

    result.upload();

    return result;
}

const errorImage = @embedFile("../images/error.eia");

pub fn uploadTextureFile(tex: *Texture, file: []const u8) !void {
    const image = files.root.getFile(file) catch {
        return uploadTextureMem(tex, errorImage);
    };

    const cont = try image.read(null);

    return uploadTextureMem(tex, cont);
}

pub fn uploadTextureMem(tex: *Texture, mem: []const u8) !void {
    gfx.Context.makeCurrent();
    defer gfx.Context.makeNotCurrent();

    const width = @as(c_int, @intCast(mem[4])) + @as(c_int, @intCast(mem[5])) * 256;
    const height = @as(c_int, @intCast(mem[6])) + @as(c_int, @intCast(mem[7])) * 256;

    if (mem.len / 4 - 2 != width * height) {
        std.log.info("up expected {} got {}", .{ width * height * 4 + 4, mem.len });

        return error.WrongSize;
    }

    tex.buffer = try allocator.alloc.realloc(tex.buffer, @intCast(width * height));

    tex.size.x = @as(f32, @floatFromInt(width));
    tex.size.y = @as(f32, @floatFromInt(height));

    @memcpy(std.mem.sliceAsBytes(tex.buffer), mem[8..]);

    tex.upload();
}
