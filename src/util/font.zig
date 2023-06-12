const std = @import("std");
const vec = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const col = @import("../math/colors.zig");
const allocator = @import("allocator.zig");
const sb = @import("spritebatch.zig");
const shd = @import("shader.zig");
const va = @import("vertArray.zig");
const tex = @import("texture.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");

var fontId: u8 = 0;

pub const Font = struct {
    tex: []const u8,
    size: f32,
    chars: [256]Char,

    setup: bool,

    pub const Char = struct {
        tx: f32,
        ty: f32,
        tw: f32,
        th: f32,
        bearing: vec.Vector2,
        ax: f32,
        ay: f32,
        size: vec.Vector2,
    };

    pub fn init(path: []const u8) !Font {
        if (try files.root.getFile(path)) |file|
            return initMem(try file.read(null));
        return error.NotFound;
    }

    pub fn deinit(self: *Font) !void {
        if (!self.setup) return;

        var texture = sb.textureManager.textures.fetchRemove(self.tex);
        texture.?.value.deinit();

        allocator.alloc.free(self.tex);
    }

    pub fn initMem(data: []const u8) !Font {
        if (fontId == 255) @panic("Max Fonts Reached");

        if (!std.mem.eql(u8, data[0..4], "efnt")) return error.BadFile;

        var charWidth = @intCast(c_uint, data[4]);
        var charHeight = @intCast(c_uint, data[5]);

        var atlasSize = vec.newVec2(128 * @intToFloat(f32, charWidth), 2 * @intToFloat(f32, charHeight));

        var result: Font = undefined;
        var texture: c.GLuint = undefined;

        c.glGenTextures(1, &texture);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, @floatToInt(c_int, atlasSize.x), @floatToInt(c_int, atlasSize.y), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

        var x: c_uint = 0;

        for (0..128) |i| {
            var chStart = 4 + 3 + (charWidth * charHeight * i);

            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, @intCast(c_int, x), 0, @intCast(c_int, charWidth), @intCast(c_int, charHeight), c.GL_RED, c.GL_UNSIGNED_BYTE, &data[chStart]);

            result.chars[i + 128] = Char{
                .size = vec.newVec2(
                    @intToFloat(f32, charWidth) * 2,
                    @intToFloat(f32, charHeight) * 2,
                ),
                .bearing = vec.newVec2(
                    0,
                    @intToFloat(f32, data[6]) * 2,
                ),
                .ax = @intToFloat(f32, charWidth) * 2 - 4,
                .ay = 0,
                .tx = @intToFloat(f32, x) / atlasSize.x,
                .ty = 0.5,
                .tw = @intToFloat(f32, charWidth) / atlasSize.x,
                .th = @intToFloat(f32, charHeight) / atlasSize.y,
            };

            chStart = 4 + 3 + (charWidth * charHeight * (i + 128));

            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, @intCast(c_int, x), @intCast(c_int, charHeight), @intCast(c_int, charWidth), @intCast(c_int, charHeight), c.GL_RED, c.GL_UNSIGNED_BYTE, &data[chStart]);

            result.chars[i] = Char{
                .size = vec.newVec2(
                    @intToFloat(f32, charWidth) * 2,
                    @intToFloat(f32, charHeight) * 2,
                ),
                .bearing = vec.newVec2(
                    0,
                    @intToFloat(f32, data[6]) * 2,
                ),
                .ax = @intToFloat(f32, charWidth) * 2 - 4,
                .ay = 0,
                .tx = @intToFloat(f32, x) / atlasSize.x,
                .ty = 0,
                .tw = @intToFloat(f32, charWidth) / atlasSize.x,
                .th = @intToFloat(f32, charHeight) / atlasSize.y,
            };

            x += charWidth;
        }

        result.size = @intToFloat(f32, charHeight * 2);

        result.tex = try std.fmt.allocPrint(allocator.alloc, "font{}", .{fontId});

        try sb.textureManager.textures.put(result.tex, .{
            .tex = texture,
            .size = atlasSize,
        });

        fontId += 1;

        result.setup = true;

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
        curLine: usize = 0,
        newLines: bool = true,
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
            var line: usize = 0;

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

                            line = @floatToInt(usize, (pos.y - start.y) / (self.size * params.scale));
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
                                .curLine = line,
                            });

                            pos.y += self.size * params.scale;
                            pos.x = start.x;

                            spaced = spaced[split - 1 ..];

                            size = self.sizeText(.{ .text = spaced, .scale = params.scale });
                        }
                        line = @floatToInt(usize, (pos.y - start.y) / (self.size * params.scale));
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
                            .curLine = line,
                        });
                        continue;
                    } else {
                        pos.y += self.size * params.scale;
                        pos.x = start.x;
                    }
                }
                line = @floatToInt(usize, (pos.y - start.y) / (self.size * params.scale));
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
                    .curLine = line,
                });

                pos.x += spaceSize;
            }

            return;
        }

        if (params.maxlines != null and
            params.curLine >= params.maxlines.?) return;

        var startscissor = params.batch.scissor;

        if (params.batch.scissor != null) {
            if (params.wrap != null)
                params.batch.scissor.?.w =
                    @max(@as(f32, 0), @min(params.batch.scissor.?.w, params.pos.x + params.wrap.? - params.batch.scissor.?.x));
            if (params.maxlines != null)
                params.batch.scissor.?.h =
                    @max(@as(f32, 0), @min(params.batch.scissor.?.h, params.pos.y + ((@intToFloat(f32, params.maxlines.?) - @intToFloat(f32, params.curLine)) * self.size) - params.batch.scissor.?.y));
        } else {
            // TODO: wrap
        }

        var vertarray = try va.VertArray.init();

        for (params.text) |ach| {
            var ch = ach;
            if (ch == '\n' and params.newLines) {
                pos.y += self.size * params.scale;
                pos.x = start.x;
                continue;
            }

            var char = self.chars[ch];
            if (ch != ' ') {
                var w = char.size.x * params.scale;
                var h = char.size.y * params.scale;
                var xpos = pos.x + char.bearing.x * params.scale;
                var ypos = pos.y + char.bearing.y * params.scale;
                srect.x = char.tx;
                srect.y = char.ty;
                srect.w = char.tw;
                srect.h = char.th;

                try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), params.color);
                try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), params.color);
                try vertarray.append(vec.newVec3(xpos + w, ypos, 0), vec.newVec2(srect.x + srect.w, srect.y), params.color);

                try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), params.color);
                try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), params.color);
                try vertarray.append(vec.newVec3(xpos, ypos + h, 0), vec.newVec2(srect.x, srect.y + srect.h), params.color);
            }

            pos.x += char.ax * params.scale;
            pos.y += char.ay * params.scale;
        }

        if (params.origin != null) {
            params.origin.?.* = pos;
        }

        var entry = sb.QueueEntry{
            .texture = self.tex,
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
