const std = @import("std");
const zgl = @import("zgl");

const util = @import("../util.zig");

const system = @import("../system.zig");
const math = @import("../math.zig");
const sandeee_data = @import("../data.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Texture = util.Texture;
const Shader = util.Shader;
const allocator = util.allocator;

const files = system.files;

const colors = sandeee_data.colors;

const Font = @This();

tex: Texture,
size: f32,
chars: [256]Char,

setup: bool,

pub const Char = struct {
    tx: f32,
    ty: f32,
    tw: f32,
    th: f32,
    bearing: Vec2,
    ax: f32,
    ay: f32,
    size: Vec2,
};

pub fn init(path: []const u8) !Font {
    const folder = try files.FolderLink.resolve(.root);
    const file = try folder.getFile(path);

    return initMem(try file.read(null));
}

pub fn deinit(self: *Font) void {
    if (!self.setup) return;

    self.tex.deinit();
}

pub fn initMem(data: []const u8) !Font {
    if (!std.mem.eql(u8, data[0..4], "efnt")) return error.BadFile;

    const char_width: usize = @intCast(data[4]);
    const char_height: usize = @intCast(data[5]);

    const atlas_size = Vec2{ .x = 128 * @as(f32, @floatFromInt(char_width)), .y = 2 * @as(f32, @floatFromInt(char_height)) };

    var chars: [256]Char = std.mem.zeroes([256]Char);

    const texture = zgl.genTexture();

    // bind and size image
    texture.bind(.@"2d");
    zgl.pixelStore(.unpack_alignment, 1);
    zgl.textureImage2D(.@"2d", 0, .red, @intFromFloat(atlas_size.x), @intFromFloat(atlas_size.y), .rgba, .unsigned_byte, null);

    // set some params for the fonts texture
    texture.parameter(.min_filter, .nearest);
    texture.parameter(.mag_filter, .nearest);

    var x: usize = 0;

    for (0..128) |i| {
        var char_start = 4 + 3 + (char_width * char_height * i);

        texture.subImage2D(0, x, 0, char_width, char_height, .red, .unsigned_byte, data[char_start..].ptr);

        chars[i + 128] = Char{
            .size = .{
                .x = @floatFromInt(char_width * 2),
                .y = @floatFromInt(char_height * 2),
            },
            .bearing = .{
                .y = @floatFromInt(data[6] * 2),
            },
            .ax = @floatFromInt(char_width * 2 - 4),
            .ay = 0,
            .tx = @as(f32, @floatFromInt(x)) / atlas_size.x,
            .ty = 0.5,
            .tw = @as(f32, @floatFromInt(char_width)) / atlas_size.x,
            .th = @as(f32, @floatFromInt(char_height)) / atlas_size.y,
        };

        char_start = 4 + 3 + (char_width * char_height * (i + 128));

        texture.subImage2D(0, x, char_height, char_width, char_height, .red, .unsigned_byte, data[char_start..].ptr);

        chars[i] = Char{
            .size = .{
                .x = @floatFromInt(char_width * 2),
                .y = @floatFromInt(char_height * 2),
            },
            .bearing = .{
                .y = @floatFromInt(data[6] * 2),
            },
            .ax = @floatFromInt(char_width * 2 - 4),
            .ay = 0,
            .tx = @as(f32, @floatFromInt(x)) / atlas_size.x,
            .ty = 0,
            .tw = @as(f32, @floatFromInt(char_width)) / atlas_size.x,
            .th = @as(f32, @floatFromInt(char_height)) / atlas_size.y,
        };

        x += char_width;
    }

    return .{
        .chars = chars,
        .tex = .{
            .tex = texture,
            .size = atlas_size,
            .buffer = &.{},
        },
        .setup = true,
        .size = @floatFromInt(char_height * 2),
    };
}

pub const drawParams = struct {
    shader: *Shader,
    pos: Vec2,
    text: []const u8,
    batch: ?*SpriteBatch = null,
    origin: ?*Vec2 = null,
    scale: f32 = 1,
    color: Color = .{ .r = 0, .g = 0, .b = 0 },
    wrap: ?f32 = null,
    maxlines: ?usize = null,
    newlines: bool = true,
};

pub fn draw(self: *Font, params: drawParams) !void {
    const batch = params.batch orelse &SpriteBatch.global;

    var pos = if (params.origin) |orig| orig.* else params.pos;
    var srect = Rect{ .w = 1, .h = 1 };
    var color = params.color;

    pos.x = @round(pos.x);
    pos.y = @round(pos.y);

    var start = params.pos;
    start.x = @round(start.x);
    start.y = @round(start.y);

    const startscissor = batch.scissor;
    defer batch.scissor = startscissor;

    if (batch.scissor) |*scissor| {
        if (params.wrap) |wrap|
            scissor.w =
                @max(@as(f32, 0), @min(scissor.w, params.pos.x + wrap - scissor.x));

        if (params.maxlines) |max_lines|
            scissor.h =
                @max(@as(f32, 0), @min(scissor.h, params.pos.y + ((@as(f32, @floatFromInt(max_lines))) * self.size) - scissor.y));
    }

    var vert_array = try VertArray.init(params.text.len * 6);

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
            color = colors.FONT_COLORS[@intCast(ach & 0x0F)];
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
                vert_array.setQuadLen(vert_array.quads().len - 1);
                xpos -= char.ax;
            } else if (std.mem.containsAtLeast(u8, params.text[last_line_idx..idx], 1, " ")) {
                vert_array.setQuadLen(last_space);
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
            try vert_array.appendQuad(
                .{
                    .x = xpos,
                    .y = ypos,
                    .w = w,
                    .h = h,
                },
                srect,
                .{ .color = color },
            );
        } else {
            last_space = vert_array.quads().len;
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

    try batch.addEntry(&.{
        .texture = .{ .texture = self.tex },
        .verts = vert_array,
        .shader = params.shader.*,
    });
}

pub const sizeParams = struct {
    text: []const u8,
    scale: f32 = 1,
    wrap: ?f32 = null,
    cursor: bool = false,
    newlines: bool = true,
};

pub fn sizeText(self: *Font, params: sizeParams) Vec2 {
    var pos: Vec2 = .{
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

// TODO: fuzz
