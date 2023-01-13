const std = @import("std");
const vec = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const col = @import("../math/colors.zig");
const ft = @import("freetype");
const allocator = @import("allocator");
const sb = @import("../spritebatch.zig");
const shd = @import("../shader.zig");
const va = @import("../vertArray.zig");
const tex = @import("../texture.zig");
const c = @import("../c.zig");

var lib: ft.c.FT_Library = undefined;

const Error = error{
    InitError,
    LoadFaceError,
    LoadGlyphError,
    RenderGlyphError,
    UnsupportedFileFormat,
    UnsupportedPixelSize,
};

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub const Font = struct {
    tex: tex.Texture,
    size: f32,
    chars: [128]Char,

    pub const Char = struct {
        tx: f32,
        tw: f32,
        th: f32,
        bearing: vec.Vector2,
        ax: f32,
        ay: f32,
        size: vec.Vector2,
    };

    pub fn init(file: []const u8, size: u32) !Font {
        var face: ft.c.FT_Face = undefined;

        var err = ft.c.FT_Init_FreeType(&lib);
        if (err != 0) {
            return error.InitError;
        }

        err = ft.c.FT_New_Face(lib, @ptrCast([*c]const u8, file), 0, &face);
        if (err == ft.c.FT_Err_Unknown_File_Format) {
            return error.UnsupportedFileFormat;
        } else if (err != 0) {
            return error.LoadFaceError;
        }

        std.log.debug("I have created font", .{});

        err = ft.c.FT_Set_Pixel_Sizes(face, 0, size);
        if (err != 0) {
            return error.UnsupportedPixelSize;
        }

        var atlasSize = vec.newVec2(0, 0);
        for (range(128)) |_, i| {
            err = ft.c.FT_Load_Char(face, @intCast(c_ulong, i), ft.c.FT_LOAD_RENDER);
            if (err != 0) {
                return error.UnsupportedPixelSize;
            }

            atlasSize.x += @intToFloat(f32, face.*.glyph.*.bitmap.width);
            if (atlasSize.y < @intToFloat(f32, face.*.glyph.*.bitmap.rows)) atlasSize.y = @intToFloat(f32, face.*.glyph.*.bitmap.rows);
        }

        var result: Font = undefined;
        c.glGenTextures(1, &result.tex.tex);
        c.glBindTexture(c.GL_TEXTURE_2D, result.tex.tex);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, @floatToInt(c_int, atlasSize.x), @floatToInt(c_int, atlasSize.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

        var x: c_uint = 0;

        for (range(128)) |_, i| {
            err = ft.c.FT_Load_Char(face, @intCast(c_ulong, i), ft.c.FT_LOAD_RENDER);
            if (err != 0) {
                continue;
            }
            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, @intCast(c_int, x), 0, @intCast(c_int, face.*.glyph.*.bitmap.width), @intCast(c_int, face.*.glyph.*.bitmap.rows), c.GL_RED, c.GL_UNSIGNED_BYTE, face.*.glyph.*.bitmap.buffer);

            result.chars[i] = Char{
                .size = vec.newVec2(
                    @intToFloat(f32, face.*.glyph.*.bitmap.width),
                    @intToFloat(f32, face.*.glyph.*.bitmap.rows),
                ),
                .bearing = vec.newVec2(
                    @intToFloat(f32, face.*.glyph.*.bitmap_left),
                    @intToFloat(f32, face.*.glyph.*.bitmap_top),
                ),
                .ax = @intToFloat(f32, face.*.glyph.*.advance.x >> 6),
                .ay = @intToFloat(f32, face.*.glyph.*.advance.y >> 6),
                .tx = @intToFloat(f32, x) / atlasSize.x,
                .tw = @intToFloat(f32, face.*.glyph.*.bitmap.width) / atlasSize.x,
                .th = @intToFloat(f32, face.*.glyph.*.bitmap.rows) / atlasSize.y,
            };

            x += face.*.glyph.*.bitmap.width;
        }

        result.size = @intToFloat(f32, size);

        err = ft.c.FT_Done_Face(face);
        if (err != 0) {
            return error.LoadFaceError;
        }

        return result;
    }

    pub fn draw(self: *Font, batch: *sb.SpriteBatch, shader: shd.Shader, text: []const u8, position: vec.Vector2, color: col.Color) void {
        var pos = position;

        var srect = rect.newRect(0, 0, 1, 1);

        var vertarray = va.VertArray.init();

        for (text) |ch| {
            if (ch > 128) continue;

            var char = self.chars[ch];
            var w = char.size.x;
            var h = char.size.y;
            var xpos = pos.x + char.bearing.x;
            var ypos = pos.y - char.bearing.y + self.size;
            srect.x = char.tx;
            srect.w = char.tw;
            srect.h = char.th;

            vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), color);
            vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), color);
            vertarray.append(vec.newVec3(xpos + w, ypos, 0), vec.newVec2(srect.x + srect.w, srect.y), color);

            vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), color);
            vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), color);
            vertarray.append(vec.newVec3(xpos, ypos + h, 0), vec.newVec2(srect.x, srect.y + srect.h), color);

            pos.x += char.ax;
            pos.y += char.ay;
        }

        var entry = sb.QueueEntry{
            .update = true,
            .texture = self.tex,
            .verts = vertarray,
            .shader = shader,
        };

        batch.addEntry(&entry);
    }

    pub fn sizeText(self: *Font, text: []const u8) vec.Vector2 {
        var result = vec.newVec2(0, 0);

        for (text) |ch| {
            if (ch > 128) continue;

            var char = self.chars[ch];
            result.x += char.ax;
            result.y += char.ay;
        }

        return result;
    }
};
