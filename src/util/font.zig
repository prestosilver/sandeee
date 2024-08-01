const std = @import("std");
const vec = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const col = @import("../math/colors.zig");
const allocator = @import("allocator.zig");
const batch = @import("spritebatch.zig");
const texture_manager = @import("texmanager.zig");
const shd = @import("shader.zig");
const va = @import("vertArray.zig");
const tex = @import("texture.zig");
const files = @import("../system/files.zig");
const c = @import("../c.zig");

var font_id: u8 = 0;

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

pub const BULLET = "\x80";
pub const LEFT = "\x81";
pub const E = "\x82";
pub const CHECK = "\x83";
pub const NOTEQUAL = "\x84";
pub const META = "\x85";
pub const FRAME = "\x86";
pub const DOWN = "\x87";
pub const BLOCK_ZERO = "\x88";

pub fn BLOCK(comptime id: u8) u8 {
    if (id > 7) @compileError("Bad Block char");

    return id + BLOCK_ZERO;
}

pub const DOTS = "\x90";
pub const RIGHT = "\x91";
pub const SMILE = "\x92";
pub const STRAIGHT = "\x93";
pub const SAD = "\x94";
pub const UP = "\x97";

pub const COLOR_BLACK = "\xF0";
pub const COLOR_GRAY = "\xF1";
pub const COLOR_DARK_RED = "\xF2";
pub const COLOR_DARK_YELLOW = "\xF3";
pub const COLOR_DARK_GREEN = "\xF4";
pub const COLOR_DARK_CYAN = "\xF5";
pub const COLOR_DARK_BLUE = "\xF6";
pub const COLOR_DARK_MAGENTA = "\xF7";

pub const COLOR_WHITE = "\xF9";
pub const COLOR_RED = "\xFA";
pub const COLOR_YELLOW = "\xFB";
pub const COLOR_GREEN = "\xFC";
pub const COLOR_CYAN = "\xFD";
pub const COLOR_BLUE = "\xFE";
pub const COLOR_MAGENTA = "\xFF";

pub const EEE = E ** 3;

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

    pub fn deinit(self: *Font) void {
        if (!self.setup) return;

        allocator.alloc.free(self.tex);
    }

    pub fn initMem(data: []const u8) !Font {
        if (font_id == 255) @panic("Max Fonts Reached");

        if (!std.mem.eql(u8, data[0..4], "efnt")) return error.BadFile;

        const char_width = @as(c_uint, @intCast(data[4]));
        const char_height = @as(c_uint, @intCast(data[5]));

        const atlas_size = vec.Vector2{ .x = 128 * @as(f32, @floatFromInt(char_width)), .y = 2 * @as(f32, @floatFromInt(char_height)) };

        var result: Font = undefined;
        var texture: c.GLuint = undefined;

        c.glGenTextures(1, &texture);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, @as(c_int, @intFromFloat(atlas_size.x)), @as(c_int, @intFromFloat(atlas_size.y)), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, null);

        var x: c_uint = 0;

        for (0..128) |i| {
            var char_start = 4 + 3 + (char_width * char_height * i);

            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, @as(c_int, @intCast(x)), 0, @as(c_int, @intCast(char_width)), @as(c_int, @intCast(char_height)), c.GL_RED, c.GL_UNSIGNED_BYTE, &data[char_start]);

            result.chars[i + 128] = Char{
                .size = .{
                    .x = @as(f32, @floatFromInt(char_width)) * 2,
                    .y = @as(f32, @floatFromInt(char_height)) * 2,
                },
                .bearing = .{
                    .y = @as(f32, @floatFromInt(data[6])) * 2,
                },
                .ax = @as(f32, @floatFromInt(char_width)) * 2 - 4,
                .ay = 0,
                .tx = @as(f32, @floatFromInt(x)) / atlas_size.x,
                .ty = 0.5,
                .tw = @as(f32, @floatFromInt(char_width)) / atlas_size.x,
                .th = @as(f32, @floatFromInt(char_height)) / atlas_size.y,
            };

            char_start = 4 + 3 + (char_width * char_height * (i + 128));

            c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, @as(c_int, @intCast(x)), @as(c_int, @intCast(char_height)), @as(c_int, @intCast(char_width)), @as(c_int, @intCast(char_height)), c.GL_RED, c.GL_UNSIGNED_BYTE, &data[char_start]);

            result.chars[i] = Char{
                .size = .{
                    .x = @as(f32, @floatFromInt(char_width)) * 2,
                    .y = @as(f32, @floatFromInt(char_height)) * 2,
                },
                .bearing = .{
                    .y = @as(f32, @floatFromInt(data[6])) * 2,
                },
                .ax = @as(f32, @floatFromInt(char_width)) * 2 - 4,
                .ay = 0,
                .tx = @as(f32, @floatFromInt(x)) / atlas_size.x,
                .ty = 0,
                .tw = @as(f32, @floatFromInt(char_width)) / atlas_size.x,
                .th = @as(f32, @floatFromInt(char_height)) / atlas_size.y,
            };

            x += char_width;
        }

        result.size = @as(f32, @floatFromInt(char_height * 2));

        result.tex = try std.fmt.allocPrint(allocator.alloc, "font{}", .{font_id});

        try texture_manager.TextureManager.instance.put(result.tex, .{
            .tex = texture,
            .size = atlas_size,
            .buffer = try allocator.alloc.alloc([4]u8, 0),
        });

        font_id += 1;

        result.setup = true;

        return result;
    }

    pub const drawParams = struct {
        shader: *shd.Shader,
        pos: vec.Vector2,
        text: []const u8,
        origin: ?*vec.Vector2 = null,
        scale: f32 = 1,
        color: col.Color = .{ .r = 0, .g = 0, .b = 0 },
        wrap: ?f32 = null,
        maxlines: ?usize = null,
        newlines: bool = true,
    };

    pub fn draw(self: *Font, params: drawParams) !void {
        var pos = if (params.origin) |orig| orig.* else params.pos;
        var srect = rect.Rectangle{ .w = 1, .h = 1 };
        var color = params.color;

        pos.x = @round(pos.x);
        pos.y = @round(pos.y);

        var start = params.pos;
        start.x = @round(start.x);
        start.y = @round(start.y);

        const startscissor = batch.SpriteBatch.instance.scissor;
        defer batch.SpriteBatch.instance.scissor = startscissor;

        if (batch.SpriteBatch.instance.scissor) |*scissor| {
            if (params.wrap) |wrap|
                scissor.w =
                    @max(@as(f32, 0), @min(scissor.w, params.pos.x + wrap - scissor.x));

            if (params.maxlines) |max_lines|
                scissor.h =
                    @max(@as(f32, 0), @min(scissor.h, params.pos.y + ((@as(f32, @floatFromInt(max_lines))) * self.size) - scissor.y));
        }

        var vert_array = try va.VertArray.init(params.text.len * 6);

        var current_line: usize = 0;
        var last_space: usize = 0;
        var last_space_idx: usize = 0;
        var last_line_idx: usize = 0;
        var idx: usize = 0;

        while (params.text.len > idx) : (idx += 1) {
            const ach = params.text[idx];

            if (ach == '\n' and params.newlines) {
                pos.y += self.size * params.scale;
                pos.x = start.x;

                current_line += 1;

                last_line_idx = idx + 1;

                continue;
            }

            if (ach >= 0xF0) {
                color = FONT_COLORS[@intCast(ach & 0x0F)];
                continue;
            }

            const char = if (ach >= 0x20)
                &self.chars[ach]
            else
                &self.chars[0x00];
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

                current_line += 1;

                if (params.maxlines != null and
                    current_line >= params.maxlines.?)
                {
                    vert_array.setLen(vert_array.items().len - 6);
                    xpos -= char.ax;
                } else if (std.mem.containsAtLeast(u8, params.text[last_line_idx..idx], 1, " ")) {
                    vert_array.setLen(last_space);
                    idx = last_space_idx - 1;

                    last_line_idx = idx + 1;
                    continue;
                }

                last_line_idx = idx + 1;
            }

            if (params.maxlines != null and
                current_line >= params.maxlines.?)
            {
                srect.x = self.chars[0x90].tx;
                srect.y = self.chars[0x90].ty;
                srect.w = self.chars[0x90].tw;
                srect.h = self.chars[0x90].th;
            }

            if (ach != ' ' or (params.maxlines != null and
                current_line >= params.maxlines.?))
            {
                try vert_array.append(.{ .x = xpos, .y = ypos }, .{ .x = srect.x, .y = srect.y }, color);
                try vert_array.append(.{ .x = xpos + w, .y = ypos + h }, .{ .x = srect.x + srect.w, .y = srect.y + srect.h }, color);
                try vert_array.append(.{ .x = xpos + w, .y = ypos }, .{ .x = srect.x + srect.w, .y = srect.y }, color);

                try vert_array.append(.{ .x = xpos, .y = ypos }, .{ .x = srect.x, .y = srect.y }, color);
                try vert_array.append(.{ .x = xpos + w, .y = ypos + h }, .{ .x = srect.x + srect.w, .y = srect.y + srect.h }, color);
                try vert_array.append(.{ .x = xpos, .y = ypos + h }, .{ .x = srect.x, .y = srect.y + srect.h }, color);
            } else {
                last_space = vert_array.items().len;
                last_space_idx = idx + 1;
            }

            if (params.maxlines != null and
                current_line >= params.maxlines.?)
                break;

            pos.x += char.ax * params.scale;
            pos.y += char.ay * params.scale;
        }

        if (params.origin) |*origin| {
            origin.*.* = pos;
        }

        const entry = .{
            .texture = self.tex,
            .verts = vert_array,
            .shader = params.shader.*,
        };

        try batch.SpriteBatch.instance.addEntry(&entry);
    }

    pub const sizeParams = struct {
        text: []const u8,
        scale: f32 = 1,
        wrap: ?f32 = null,
        cursor: bool = false,
        newlines: bool = true,
    };

    pub fn sizeText(self: *Font, params: sizeParams) vec.Vector2 {
        var pos: vec.Vector2 = .{
            .x = 0,
            .y = 0,
        };

        var maxx: f32 = 0;

        var current_line: usize = 0;
        var last_space_idx: usize = 0;
        var last_line_idx: usize = 0;
        var idx: usize = 0;

        while (params.text.len > idx) : (idx += 1) {
            const ach = params.text[idx];

            if (ach == '\n' and params.newlines) {
                maxx = @max(maxx, pos.x);
                pos.y += self.size * params.scale;
                pos.x = 0;

                current_line += 1;

                last_line_idx = idx + 1;

                continue;
            }

            if (ach >= 0xF0) {
                continue;
            }

            const char = if (ach >= 0x20)
                &self.chars[ach]
            else
                &self.chars[0x00];
            if (ach != ' ') {
                if (params.wrap != null and pos.x + char.ax >= params.wrap.?) {
                    maxx = @max(maxx, pos.x);
                    pos.y += self.size * params.scale;
                    pos.x = 0;

                    current_line += 1;

                    if (std.mem.containsAtLeast(u8, params.text[last_line_idx..idx], 1, " ")) {
                        idx = last_space_idx - 1;

                        last_line_idx = idx + 1;
                        continue;
                    }

                    last_line_idx = idx + 1;
                }
            } else {
                last_space_idx = idx + 1;
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
