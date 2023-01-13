const std = @import("std");
const vecs = @import("math/vecs.zig");
const c = @import("c.zig");

pub const Texture = struct { tex: c.GLuint, size: vecs.Vector2 };

pub fn newTextureSize(size: vecs.Vector2) Texture {
    var result = Texture{
        .tex = 0,
        .size = size,
    };

    c.glGenTextures(1, &result.tex);
    c.glBindTexture(c.GL_TEXTURE_2D, result.tex);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, size.x, size.y, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

    return result;
}

pub fn newTextureFile(image: []const u8) Texture {
    var width: c_int = 0;
    var height: c_int = 0;
    var channels: c_int = 0;

    var result = Texture{ .tex = 0, .size = vecs.Vector2{
        .x = 0,
        .y = 0,
    } };

    var data = c.stbi_load(@ptrCast([*c]const u8, image), &width, &height, &channels, 4);

    if (data == null) {
        std.log.info("Error: Bad Image\n", .{});
        std.c.exit(1);
    }

    result.size.x = @intToFloat(f32, width);
    result.size.y = @intToFloat(f32, height);

    c.glGenTextures(1, &result.tex);
    c.glBindTexture(c.GL_TEXTURE_2D, result.tex);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, data);

    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    c.stbi_image_free(data);

    return result;
}
