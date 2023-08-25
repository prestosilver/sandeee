const std = @import("std");
const vec = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const col = @import("../math/colors.zig");
const allocator = @import("allocator.zig");
const batch = @import("spritebatch.zig");
const texMan = @import("texmanager.zig");
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

        try texMan.TextureManager.instance.put(result.tex, .{
            .tex = texture,
            .size = atlasSize,
            .buffer = try allocator.alloc.alloc([4]u8, 0),
        });

        fontId += 1;

        result.setup = true;

        return result;
    }

    pub const drawParams = struct {
        shader: *shd.Shader,
        pos: vec.Vector2,
        text: []const u8,
        origin: ?*vec.Vector2 = null,
        scale: f32 = 1,
        color: col.Color = col.newColor(0, 0, 0, 1),
        wrap: ?f32 = null,
        maxlines: ?usize = null,
        newLines: bool = true,
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

        const startscissor = batch.SpriteBatch.instance.scissor;
        defer batch.SpriteBatch.instance.scissor = startscissor;

        if (batch.SpriteBatch.instance.scissor != null) {
            if (params.wrap != null)
                batch.SpriteBatch.instance.scissor.?.w =
                    @max(@as(f32, 0), @min(batch.SpriteBatch.instance.scissor.?.w, params.pos.x + params.wrap.? - batch.SpriteBatch.instance.scissor.?.x));
            if (params.maxlines != null)
                batch.SpriteBatch.instance.scissor.?.h =
                    @max(@as(f32, 0), @min(batch.SpriteBatch.instance.scissor.?.h, params.pos.y + ((@as(f32, @floatFromInt(params.maxlines.?))) * self.size) - batch.SpriteBatch.instance.scissor.?.y));
        }

        var vertarray = try va.VertArray.init(params.text.len * 6);

        var curLine: usize = 0;
        var lastspace: usize = 0;
        var lastspaceIdx: usize = 0;
        var lastLineIdx: usize = 0;
        var idx: usize = 0;

        while (params.text.len > idx) : (idx += 1) {
            const ach = params.text[idx];

            if (ach == '\n' and params.newLines) {
                pos.y += self.size * params.scale;
                pos.x = start.x;

                curLine += 1;

                lastLineIdx = idx + 1;

                continue;
            }

            if (ach >= 0xF0 or ach < 0x20) {
                color = FONT_COLORS[@intCast(ach & 0x0F)];
                continue;
            }

            const char = self.chars[ach];
            const w = char.size.x * params.scale;
            const h = char.size.y * params.scale;
            var xpos = pos.x + char.bearing.x * params.scale;
            const ypos = pos.y + char.bearing.y * params.scale;
            srect.x = char.tx;
            srect.y = char.ty;
            srect.w = char.tw;
            srect.h = char.th;

            if (params.wrap != null and (pos.x + char.ax) - start.x >= params.wrap.?) {
                pos.y += self.size * params.scale;
                pos.x = start.x;

                curLine += 1;

                if (params.maxlines != null and
                    curLine >= params.maxlines.?)
                {
                    vertarray.setLen(vertarray.items().len - 6);
                    xpos -= char.ax;
                } else if (std.mem.containsAtLeast(u8, params.text[lastLineIdx..idx], 1, " ")) {
                    vertarray.setLen(lastspace);
                    idx = lastspaceIdx - 1;

                    lastLineIdx = idx + 1;
                    continue;
                }

                lastLineIdx = idx + 1;
            }

            if (params.maxlines != null and
                curLine >= params.maxlines.?)
            {
                srect.x = self.chars[0x90].tx;
                srect.y = self.chars[0x90].ty;
                srect.w = self.chars[0x90].tw;
                srect.h = self.chars[0x90].th;
            }

            if (ach != ' ' or (params.maxlines != null and
                curLine >= params.maxlines.?))
            {
                try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), color);
                try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), color);
                try vertarray.append(vec.newVec3(xpos + w, ypos, 0), vec.newVec2(srect.x + srect.w, srect.y), color);

                try vertarray.append(vec.newVec3(xpos, ypos, 0), vec.newVec2(srect.x, srect.y), color);
                try vertarray.append(vec.newVec3(xpos + w, ypos + h, 0), vec.newVec2(srect.x + srect.w, srect.y + srect.h), color);
                try vertarray.append(vec.newVec3(xpos, ypos + h, 0), vec.newVec2(srect.x, srect.y + srect.h), color);
            } else {
                lastspace = vertarray.items().len;
                lastspaceIdx = idx + 1;
            }

            if (params.maxlines != null and
                curLine >= params.maxlines.?)
            {
                break;
            }

            pos.x += char.ax * params.scale;
            pos.y += char.ay * params.scale;
        }

        if (params.origin != null) {
            params.origin.?.* = pos;
        }

        const entry = .{
            .texture = self.tex,
            .verts = vertarray,
            .shader = params.shader.*,
        };

        try batch.SpriteBatch.instance.addEntry(&entry);
    }

    pub const sizeParams = struct {
        text: []const u8,
        scale: f32 = 1,
        wrap: ?f32 = null,
        cursor: bool = false,
        newLines: bool = true,
    };

    pub fn sizeText(self: *Font, params: sizeParams) vec.Vector2 {
        var pos: vec.Vector2 = .{
            .x = 0,
            .y = 0,
        };

        var maxx: f32 = 0;

        var curLine: usize = 0;
        var lastspaceIdx: usize = 0;
        var lastLineIdx: usize = 0;
        var idx: usize = 0;

        while (params.text.len > idx) : (idx += 1) {
            const ach = params.text[idx];

            if (ach == '\n' and params.newLines) {
                maxx = @max(maxx, pos.x);
                pos.y += self.size * params.scale;
                pos.x = 0;

                curLine += 1;

                lastLineIdx = idx + 1;

                continue;
            }

            if (ach >= 0xF0 or ach < 0x20) {
                continue;
            }

            const char = self.chars[ach];
            if (ach != ' ') {
                if (params.wrap != null and pos.x + char.ax >= params.wrap.?) {
                    maxx = @max(maxx, pos.x);
                    pos.y += self.size * params.scale;
                    pos.x = 0;

                    curLine += 1;

                    if (std.mem.containsAtLeast(u8, params.text[lastLineIdx..idx], 1, " ")) {
                        idx = lastspaceIdx - 1;

                        lastLineIdx = idx + 1;
                        continue;
                    }

                    lastLineIdx = idx + 1;
                }
            } else {
                lastspaceIdx = idx + 1;
            }

            pos.x += char.ax * params.scale;
            pos.y += char.ay * params.scale;
        }

        maxx = @max(maxx, pos.x);
        pos.y += self.size * params.scale;

        return .{
            .x = @min(maxx, params.wrap orelse maxx),
            .y = pos.y,
        };
    }
};
