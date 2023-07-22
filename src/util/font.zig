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

const FONT_COLORS = [16]col.Color{
    .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1 },
    .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1 },
    .{ .r = 0.5, .g = 0.0, .b = 0.0, .a = 1 },
    .{ .r = 0.5, .g = 0.5, .b = 0.0, .a = 1 },
    .{ .r = 0.0, .g = 0.5, .b = 0.0, .a = 1 },
    .{ .r = 0.0, .g = 0.5, .b = 0.5, .a = 1 },
    .{ .r = 0.0, .g = 0.0, .b = 0.5, .a = 1 },
    .{ .r = 0.5, .g = 0.0, .b = 0.5, .a = 1 },
    .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    .{ .r = 1, .g = 1, .b = 1, .a = 1 },
    .{ .r = 1, .g = 0, .b = 0, .a = 1 },
    .{ .r = 1, .g = 1, .b = 0, .a = 1 },
    .{ .r = 0, .g = 1, .b = 0, .a = 1 },
    .{ .r = 0, .g = 1, .b = 1, .a = 1 },
    .{ .r = 0, .g = 0, .b = 1, .a = 1 },
    .{ .r = 1, .g = 0, .b = 1, .a = 1 },
};

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
        const file = try files.root.getFile(path);

        return initMem(try file.read(null));
    }

    pub fn deinit(self: *Font) !void {
        if (!self.setup) return;

        allocator.alloc.free(self.tex);
    }

    pub fn initMem(data: []const u8) !Font {
        if (fontId == 255) @panic("Max Fonts Reached");

        if (!std.mem.eql(u8, data[0..4], "efnt")) return error.BadFile;

        const charWidth = @as(c_uint, @intCast(data[4]));
        const charHeight = @as(c_uint, @intCast(data[5]));

        const atlasSize = vec.newVec2(128 * @as(f32, @floatFromInt(charWidth)), 2 * @as(f32, @floatFromInt(charHeight)));

        var result: Font = undefined;
        var texture: c.GLuint = undefined;

        c.glGenTextures(1, &texture);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, @as(c_int, @intFromFloat(atlasSize.x)), @as(c_int, @intFromFloat(atlasSize.y)), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

        var x: c_uint = 0;

        for (0..128) |i| {
            var chStart = 4 + 3 + (charWidth * charHeight * i);

            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, @as(c_int, @intCast(x)), 0, @as(c_int, @intCast(charWidth)), @as(c_int, @intCast(charHeight)), c.GL_RED, c.GL_UNSIGNED_BYTE, &data[chStart]);

            result.chars[i + 128] = Char{
                .size = vec.newVec2(
                    @as(f32, @floatFromInt(charWidth)) * 2,
                    @as(f32, @floatFromInt(charHeight)) * 2,
                ),
                .bearing = vec.newVec2(
                    0,
                    @as(f32, @floatFromInt(data[6])) * 2,
                ),
                .ax = @as(f32, @floatFromInt(charWidth)) * 2 - 4,
                .ay = 0,
                .tx = @as(f32, @floatFromInt(x)) / atlasSize.x,
                .ty = 0.5,
                .tw = @as(f32, @floatFromInt(charWidth)) / atlasSize.x,
                .th = @as(f32, @floatFromInt(charHeight)) / atlasSize.y,
            };

            chStart = 4 + 3 + (charWidth * charHeight * (i + 128));

            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, @as(c_int, @intCast(x)), @as(c_int, @intCast(charHeight)), @as(c_int, @intCast(charWidth)), @as(c_int, @intCast(charHeight)), c.GL_RED, c.GL_UNSIGNED_BYTE, &data[chStart]);

            result.chars[i] = Char{
                .size = vec.newVec2(
                    @as(f32, @floatFromInt(charWidth)) * 2,
                    @as(f32, @floatFromInt(charHeight)) * 2,
                ),
                .bearing = vec.newVec2(
                    0,
                    @as(f32, @floatFromInt(data[6])) * 2,
                ),
                .ax = @as(f32, @floatFromInt(charWidth)) * 2 - 4,
                .ay = 0,
                .tx = @as(f32, @floatFromInt(x)) / atlasSize.x,
                .ty = 0,
                .tw = @as(f32, @floatFromInt(charWidth)) / atlasSize.x,
                .th = @as(f32, @floatFromInt(charHeight)) / atlasSize.y,
            };

            x += charWidth;
        }

        result.size = @as(f32, @floatFromInt(charHeight * 2));

        result.tex = try std.fmt.allocPrint(allocator.alloc, "font{}", .{fontId});

        try sb.textureManager.put(result.tex, .{
            .tex = texture,
            .size = atlasSize,
            .buffer = try allocator.alloc.alloc([4]u8, 0),
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
        center: bool = false,
    };

    pub fn draw(self: *Font, params: drawParams) !void {
        var pos = if (params.origin) |orig| orig.* else params.pos;
        var srect = rect.newRect(0, 0, 1, 1);
        var color = params.color;
        pos.x = @round(pos.x);
        pos.y = @round(pos.y);

        var start = params.pos;
        start.x = @round(start.x);
        start.y = @round(start.y);

        if (params.wrap) |maxSize| {
            if (maxSize <= 0) return;
            var iter = std.mem.split(u8, params.text, " ");
            const spaceSize = self.sizeText(.{ .text = " ", .scale = params.scale }).x;
            var line: usize = 0;

            while (iter.next()) |word| {
                var size = self.sizeText(.{ .text = word, .scale = params.scale });

                if (pos.x - start.x + size.x >= maxSize) {
                    if (pos.x == start.x) {
                        var spaced = word;
                        while (size.x >= maxSize) {
                            var split: usize = 0;
                            while (self.sizeText(.{ .text = spaced[0..split], .scale = params.scale }).x < maxSize) {
                                split += 1;
                            }

                            const end = if (params.maxlines != null and params.curLine == params.maxlines.? - 1) "\x90" else "";
                            const text = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ spaced[0 .. split - end.len - 1], end });
                            defer allocator.alloc.free(text);

                            line = @as(usize, @intFromFloat((pos.y - start.y) / (self.size * params.scale)));
                            try self.draw(.{
                                .batch = params.batch,
                                .shader = params.shader,
                                .text = text,
                                .pos = start,
                                .origin = &pos,
                                .color = color,
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

                        const lineSize = self.sizeText(.{ .text = spaced, .scale = params.scale }).x;

                        pos = pos.add(.{
                            .x = if (params.center) (maxSize - lineSize) / 2 else 0,
                            .y = 0,
                        });

                        line = @as(usize, @intFromFloat((pos.y - start.y) / (self.size * params.scale)));
                        try self.draw(.{
                            .batch = params.batch,
                            .shader = params.shader,
                            .text = spaced,
                            .pos = start,
                            .origin = &pos,
                            .color = color,
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

                line = @as(usize, @intFromFloat((pos.y - start.y) / (self.size * params.scale)));
                try self.draw(.{
                    .batch = params.batch,
                    .shader = params.shader,
                    .text = word,
                    .pos = start,
                    .origin = &pos,
                    .color = color,
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

        const startscissor = params.batch.scissor;

        if (params.batch.scissor != null) {
            if (params.wrap != null)
                params.batch.scissor.?.w =
                    @max(@as(f32, 0), @min(params.batch.scissor.?.w, params.pos.x + params.wrap.? - params.batch.scissor.?.x));
            if (params.maxlines != null)
                params.batch.scissor.?.h =
                    @max(@as(f32, 0), @min(params.batch.scissor.?.h, params.pos.y + ((@as(f32, @floatFromInt(params.maxlines.?)) - @as(f32, @floatFromInt(params.curLine))) * self.size) - params.batch.scissor.?.y));
        }

        var vertarray = try va.VertArray.init();

        for (params.text) |ach| {
            if (ach == '\n' and params.newLines) {
                pos.y += self.size * params.scale;
                pos.x = start.x;
                continue;
            }

            if (ach & 0xF0 == 0xF0) {
                color = FONT_COLORS[@intCast(ach & 0x0F)];
                continue;
            }

            const char = self.chars[ach];
            if (ach != ' ') {
                const w = char.size.x * params.scale;
                const h = char.size.y * params.scale;
                const xpos = pos.x + char.bearing.x * params.scale;
                const ypos = pos.y + char.bearing.y * params.scale;
                srect.x = char.tx;
                srect.y = char.ty;
                srect.w = char.tw;
                srect.h = char.th;

                try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), color);
                try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), color);
                try vertarray.append(vec.newVec3(xpos + w, ypos, 0), vec.newVec2(srect.x + srect.w, srect.y), color);

                try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), color);
                try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), color);
                try vertarray.append(vec.newVec3(xpos, ypos + h, 0), vec.newVec2(srect.x, srect.y + srect.h), color);
            }

            pos.x += char.ax * params.scale;
            pos.y += char.ay * params.scale;
        }

        if (params.origin != null) {
            params.origin.?.* = pos;
        }

        const entry = sb.QueueEntry{
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
        var maxx: f32 = 0;

        if (params.wrap) |maxSize| {
            var iter = std.mem.split(u8, params.text, " ");
            const spaceSize = self.sizeText(.{
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
                if (result.x + size.x >= maxSize) {
                    if (result.x == 0) {
                        var spaced = word;
                        while (size.x >= maxSize) {
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
                        maxx = @max(maxx, result.x);
                        result.x = 0;
                        result.y += params.scale * self.size;
                    }
                }
                result.x += size.x;
                result.x += spaceSize;
            }
            result.y += self.size * params.scale;
            result.x = @max(maxx, result.x);

            return result;
        }

        for (params.text) |ach| {
            if (ach & 0xF0 == 0xF0) {
                continue;
            }

            if (ach == '\n') {
                maxx = @max(result.x, maxx);
                result.y += self.size * params.scale;
                result.x = 0;
                continue;
            }

            const char = self.chars[ach];
            result.x += char.ax * params.scale;
        }

        result.y += self.size * params.scale;
        result.x = @max(result.x, maxx);

        return result;
    }
};
