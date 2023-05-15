const std = @import("std");
const vecs = @import("../math/vecs.zig");
const c = @import("../c.zig");
const files = @import("../system/files.zig");
const gfx = @import("graphics.zig");
const cols = @import("../math/colors.zig");

pub const Texture = struct {
    tex: c.GLuint,
    size: vecs.Vector2,

    pub fn deinit(self: *const Texture) void {
        c.glDeleteTextures(1, &self.tex);
    }

    pub fn setPixel(self: *const Texture, x: i32, y: i32, color: cols.Color) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.tex);
        c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, x, y, 1, 1, c.GL_RGBA, c.GL_FLOAT, &color.r);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
    }
};

pub const imageError = error{
    WrongSize,
    NotFound,
};

pub fn newTextureSize(size: vecs.Vector2) Texture {
    var result = Texture{
        .tex = 0,
        .size = size,
    };

    c.glGenTextures(1, &result.tex);
    c.glBindTexture(c.GL_TEXTURE_2D, result.tex);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @floatToInt(c_int, size.x), @floatToInt(c_int, size.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

    return result;
}

pub fn newTextureFile(file: []const u8) !Texture {
    var image = try files.root.getFile(file);

    if (image == null) return error.NotFound;

    var cont = try image.?.read(null);

    return newTextureMem(cont);
}

pub fn newTextureMem(mem: []const u8) !Texture {
    var result = Texture{ .tex = 0, .size = vecs.Vector2{
        .x = 0,
        .y = 0,
    } };

    var width = @intCast(c_int, mem[4]) + @intCast(c_int, mem[5]) * 256;
    var height = @intCast(c_int, mem[6]) + @intCast(c_int, mem[7]) * 256;

    if (mem.len / 4 - 2 != width * height) {
        std.log.info("expected {} got {}", .{ width * height * 4 + 4, mem.len });

        return error.WrongSize;
    }

    result.size.x = @intToFloat(f32, width);
    result.size.y = @intToFloat(f32, height);

    c.glGenTextures(1, &result.tex);
    c.glBindTexture(c.GL_TEXTURE_2D, result.tex);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, &mem[8]);

    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    return result;
}

const errorImage = @embedFile("../images/error.eia");

pub fn uploadTextureFile(tex: *Texture, file: []const u8) !void {
    var image = try files.root.getFile(file);

    if (image == null) return uploadTextureMem(tex, errorImage);

    var cont = try image.?.read(null);

    return uploadTextureMem(tex, cont);
}

pub fn uploadTextureMem(tex: *Texture, mem: []const u8) !void {
    gfx.gContext.makeCurrent();
    defer gfx.gContext.makeNotCurrent();

    var width = @intCast(c_int, mem[4]) + @intCast(c_int, mem[5]) * 256;
    var height = @intCast(c_int, mem[6]) + @intCast(c_int, mem[7]) * 256;

    if (mem.len / 4 - 2 != width * height) {
        std.log.info("expected {} got {}", .{ width * height * 4 + 4, mem.len });

        return error.WrongSize;
    }

    tex.size.x = @intToFloat(f32, width);
    tex.size.y = @intToFloat(f32, height);

    c.glBindTexture(c.GL_TEXTURE_2D, tex.tex);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, &mem[8]);

    c.glGenerateMipmap(c.GL_TEXTURE_2D);
}

pub fn freeTexture(tex: *Texture) void {
    c.glDeleteTextures(1, &tex.tex);
}
