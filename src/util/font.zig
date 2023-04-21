const std = @import("std");
const vec = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const col = @import("../math/colors.zig");
const ft = @import("freetype");
const allocator = @import("allocator.zig");
const sb = @import("spritebatch.zig");
const shd = @import("shader.zig");
const va = @import("vertArray.zig");
const tex = @import("texture.zig");
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

    pub fn init(file: [*c]const u8, size: u32) !Font {
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

        err = ft.c.FT_Set_Pixel_Sizes(face, 0, size);
        if (err != 0) {
            return error.UnsupportedPixelSize;
        }

        var atlasSize = vec.newVec2(0, 0);
        for (range(128), 0..) |_, i| {
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

        for (range(128), 0..) |_, i| {
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

        err = ft.c.FT_Done_FreeType(lib);

        return result;
    }

    pub const drawParams = struct {
        batch: *sb.SpriteBatch,
        shader: *shd.Shader,
        pos: vec.Vector2,
        text: []const u8,
        origin: ?*vec.Vector2 = null,
        scale: f32 = 1,
        color: col.Color = col.newColor(0, 0, 0, 1),
        wrap: ?f32 = null,
        maxlines: ?usize = null,
    };

    pub fn draw(self: *Font, params: drawParams) !void {
        var pos = if (params.origin) |orig| orig.* else params.pos;
        var srect = rect.newRect(0, 0, 1, 1);
        pos.x = @round(pos.x);
        pos.y = @round(pos.y);

        var start = params.pos;
        start.x = @round(start.x);
        start.y = @round(start.y);

        if (params.wrap) |maxSize| {
            if (maxSize <= 0) return;
            var iter = std.mem.split(u8, params.text, " ");
            var spaceSize = self.sizeText(.{ .text = " ", .scale = params.scale }).x;

            while (iter.next()) |word| {
                var size = self.sizeText(.{ .text = word, .scale = params.scale });

                if (pos.x - start.x + size.x > maxSize) {
                    if (pos.x == start.x) {
                        var spaced = word;
                        while (size.x > maxSize) {
                            var split: usize = 0;
                            while (self.sizeText(.{ .text = spaced[0..split], .scale = params.scale }).x < maxSize) {
                                split += 1;
                            }

                            try self.draw(.{
                                .batch = params.batch,
                                .shader = params.shader,
                                .text = spaced[0 .. split - 1],
                                .pos = start,
                                .origin = &pos,
                                .color = params.color,
                                .scale = params.scale,
                                .wrap = null,
                                .maxlines = params.maxlines,
                            });

                            pos.y += self.size * params.scale;
                            pos.x = start.x;

                            spaced = spaced[split - 1 ..];

                            size = self.sizeText(.{ .text = spaced, .scale = params.scale });
                        }
                        try self.draw(.{
                            .batch = params.batch,
                            .shader = params.shader,
                            .text = spaced,
                            .pos = start,
                            .origin = &pos,
                            .color = params.color,
                            .scale = params.scale,
                            .wrap = null,
                            .maxlines = params.maxlines,
                        });
                        continue;
                    } else {
                        pos.y += self.size * params.scale;
                        pos.x = start.x;
                    }
                }
                try self.draw(.{
                    .batch = params.batch,
                    .shader = params.shader,
                    .text = word,
                    .pos = start,
                    .origin = &pos,
                    .color = params.color,
                    .scale = params.scale,
                    .wrap = null,
                    .maxlines = params.maxlines,
                });

                pos.x += spaceSize;
            }

            return;
        }

        var startscissor = params.batch.scissor;

        if (params.batch.scissor != null) {
            // if (!params.batch.scissor.?.contains(start)) return;
            if (params.wrap != null)
                params.batch.scissor.?.w =
                    @max(0, @min(params.batch.scissor.?.w, params.pos.x + params.wrap.? - params.batch.scissor.?.x));
            if (params.maxlines != null)
                params.batch.scissor.?.h =
                    @max(0, @min(params.batch.scissor.?.h, params.pos.y + (@intToFloat(f32, params.maxlines.?) + 0.25) * self.size * params.scale - params.batch.scissor.?.y));
        } else {
            // TODO: wrap
        }

        var vertarray = try va.VertArray.init();

        for (params.text) |ach| {
            var ch = ach;
            if (ch == '\n') {
                pos.y += self.size * params.scale;
                pos.x = start.x;
                continue;
            }
            if (ch > 127) ch = '?';
            if (ch < 32) ch = '?';

            var char = self.chars[ch];
            var w = char.size.x * params.scale;
            var h = char.size.y * params.scale;
            var xpos = pos.x + char.bearing.x * params.scale;
            var ypos = pos.y - (char.bearing.y - self.size) * params.scale;
            srect.x = char.tx;
            srect.w = char.tw;
            srect.h = char.th;

            try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), params.color);
            try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), params.color);
            try vertarray.append(vec.newVec3(xpos + w, ypos, 0), vec.newVec2(srect.x + srect.w, srect.y), params.color);

            try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), params.color);
            try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), params.color);
            try vertarray.append(vec.newVec3(xpos, ypos + h, 0), vec.newVec2(srect.x, srect.y + srect.h), params.color);

            pos.x += char.ax * params.scale;
            pos.y += char.ay * params.scale;
        }

        if (params.origin != null) {
            params.origin.?.* = pos;
        }

        var entry = sb.QueueEntry{
            .update = true,
            .texture = &self.tex,
            .verts = vertarray,
            .shader = params.shader.*,
        };

        try params.batch.addEntry(&entry);

        params.batch.scissor = startscissor;
    }

    pub const sizeParams = struct {
        text: []const u8,
        scale: f32 = 1,
        wrap: ?f32 = null,
        turnicate: bool = false,
    };

    pub fn sizeText(self: *Font, params: sizeParams) vec.Vector2 {
        var result = vec.newVec2(0, 0);

        if (params.wrap) |maxSize| {
            var iter = std.mem.split(u8, params.text, " ");
            var spaceSize = self.sizeText(.{
                .text = " ",
                .scale = params.scale,
            }).x;

            while (iter.next()) |word| {
                if (result.y != 0 and params.turnicate) {
                    result.y = params.scale * self.size;
                    result.x = maxSize;
                    return result;
                }

                var size = self.sizeText(.{ .text = word, .scale = params.scale });
                if (result.x + size.x > maxSize) {
                    if (result.x == 0) {
                        var spaced = word;
                        while (size.x > maxSize) {
                            var split: usize = 0;
                            while (self.sizeText(.{
                                .text = spaced[0..split],
                                .scale = params.scale,
                            }).x < maxSize) {
                                split += 1;
                            }

                            spaced = spaced[split - 1 ..];
                            result.y += params.scale * self.size;
                            if (params.turnicate) {
                                result.y = params.scale * self.size;
                                result.x = maxSize;
                                return result;
                            }

                            size = self.sizeText(.{ .text = spaced, .scale = params.scale });
                        }
                        result.x += size.x;
                        result.x += spaceSize;
                        continue;
                    } else {
                        result.x = 0;
                        result.y += params.scale * self.size;
                    }
                }
                result.x += size.x;
                result.x += spaceSize;
            }
            result.y += self.size * params.scale;

            return result;
        }

        var maxx: f32 = 0;

        for (params.text) |ach| {
            var ch = ach;
            if (ch == '\n') {
                maxx = @max(result.x, maxx);
                result.y += self.size * params.scale;
                result.x = 0;
                continue;
            }

            if (ch > 127) ch = '?';
            if (ch < 32) ch = '?';

            var char = self.chars[ch];
            result.x += char.ax * params.scale;
            result.y += char.ay * params.scale;
        }

        result.y += self.size * params.scale;
        result.x = @max(result.x, maxx);

        return result;
    }
};
