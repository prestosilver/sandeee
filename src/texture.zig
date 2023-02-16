const std = @import("std");
const vecs = @import("math/vecs.zig");
const c = @import("c.zig");
const files = @import("system/files.zig");

pub const Texture = struct { tex: c.GLuint, size: vecs.Vector2 };

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
    var image = files.root.getFile(file);

    if (image == null) return error.NotFound;

    var cont = image.?.read();

    var result = Texture{ .tex = 0, .size = vecs.Vector2{
        .x = 0,
        .y = 0,
    } };

    var width = @intCast(c_int, cont[4]) + @intCast(c_int, cont[5]) * 256;
    var height = @intCast(c_int, cont[6]) + @intCast(c_int, cont[7]) * 256;

    if (cont.len / 4 - 2 != width * height) {
        return error.WriongSize;
    }

    result.size.x = @intToFloat(f32, width);
    result.size.y = @intToFloat(f32, height);

    c.glGenTextures(1, &result.tex);
    c.glBindTexture(c.GL_TEXTURE_2D, result.tex);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, &cont[8]);

    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    return result;
}
