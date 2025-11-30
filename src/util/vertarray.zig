const std = @import("std");
const c = @import("../c.zig");

const system = @import("mod.zig");

const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");

const Border = math.Border;
const Color = math.Color;
const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const allocator = util.allocator;

pub const Vert = struct {
    x: c.GLfloat,
    y: c.GLfloat,
    z: c.GLfloat,
    u: c.GLfloat,
    v: c.GLfloat,
    r: c.GLfloat,
    g: c.GLfloat,
    b: c.GLfloat,
    a: c.GLfloat,

    pub inline fn array(v: Vert) [9]f32 {
        return [_]f32{ v.x, v.y, v.z, v.u, v.v, v.r, v.g, v.b, v.a };
    }

    pub inline fn getHash(v: Vert) u8 {
        const casted = std.mem.asBytes(&[_]f32{ v.x, v.y, v.u, v.v, v.r, v.g, v.b });
        var hash: u8 = 128;
        for (casted) |ch| {
            hash = ((hash << 5) +% hash) +% ch;
        }

        return hash;
    }
};

pub const Quad = struct {
    sxo: c.GLfloat,
    syo: c.GLfloat,
    sxs: c.GLfloat,
    sys: c.GLfloat,

    dxo: c.GLfloat,
    dyo: c.GLfloat,
    dxs: c.GLfloat,
    dys: c.GLfloat,

    r: c.GLfloat,
    g: c.GLfloat,
    b: c.GLfloat,
    a: c.GLfloat,
};

const VertArray = @This();

array: std.ArrayList(Vert),
qarray: std.ArrayList(Quad),

pub const none: VertArray = .{ .array = .init(allocator.alloc), .qarray = .init(allocator.alloc) };

pub inline fn init(cap: usize) !VertArray {
    return VertArray{
        .array = try .initCapacity(allocator.alloc, cap),
        .qarray = try .initCapacity(allocator.alloc, cap),
    };
}

pub inline fn deinit(va: *const VertArray) void {
    va.array.deinit();
    va.qarray.deinit();
}

pub inline fn items(va: *const VertArray) []const Vert {
    return va.array.items;
}

pub inline fn quads(va: *const VertArray) []const Quad {
    return va.qarray.items;
}

pub inline fn hashLen(va: *const VertArray) usize {
    return va.array.items.len / 6;
}

pub inline fn setLen(va: *VertArray, len: usize) void {
    va.array.shrinkRetainingCapacity(len);
}

pub inline fn setQuadLen(va: *VertArray, len: usize) void {
    va.qarray.shrinkRetainingCapacity(len);
}

const UiQuadParams = struct {
    color: Color = .{ .r = 1, .g = 1, .b = 1 },
    sheet_size: Vec2 = .{ .x = 1, .y = 1 },
    sprite_size: Vec2 = .{ .x = 1, .y = 1 },
    sprite: Vec2 = .{},
    draw_scale: f32 = 1.0,
    borders: Border = .{},
};

pub inline fn appendUiQuad(va: *VertArray, pos: Rect, params: UiQuadParams) !void {
    const starts = .{
        .x = [3]f32{ pos.x, pos.x + params.draw_scale * params.borders.l, pos.x + pos.w - params.draw_scale * params.borders.r },
        .y = [3]f32{ pos.y, pos.y + params.draw_scale * params.borders.t, pos.y + pos.h - params.draw_scale * params.borders.b },
        .u = [3]f32{ 0.0, params.borders.l / params.sprite_size.x, (params.sprite_size.x - params.borders.r) / params.sprite_size.x },
        .v = [3]f32{ 0.0, params.borders.t / params.sprite_size.y, (params.sprite_size.y - params.borders.b) / params.sprite_size.y },
    };

    const sizes = .{
        .x = [3]f32{ params.draw_scale * params.borders.l, pos.w - params.draw_scale * (params.borders.l + params.borders.r), params.draw_scale * params.borders.r },
        .y = [3]f32{ params.draw_scale * params.borders.t, pos.h - params.draw_scale * (params.borders.t + params.borders.b), params.draw_scale * params.borders.b },
        .u = [3]f32{ params.borders.l / params.sprite_size.x, (params.sprite_size.x - params.borders.l - params.borders.r) / params.sprite_size.x, params.borders.r / params.sprite_size.x },
        .v = [3]f32{ params.borders.t / params.sprite_size.y, (params.sprite_size.y - params.borders.t - params.borders.b) / params.sprite_size.y, params.borders.b / params.sprite_size.y },
    };

    for (0..3) |x| {
        for (0..3) |y| {
            try va.appendQuad(
                .{
                    .x = starts.x[x],
                    .y = starts.y[y],
                    .w = sizes.x[x],
                    .h = sizes.y[y],
                },
                .{
                    .x = (starts.u[x] + params.sprite.x) / params.sheet_size.x,
                    .y = (starts.v[y] + params.sprite.y) / params.sheet_size.y,
                    .w = sizes.u[x] / params.sheet_size.x,
                    .h = sizes.v[y] / params.sheet_size.y,
                },
                .{},
            );
        }
    }
}

const QuadParams = struct {
    color: Color = .{ .r = 1, .g = 1, .b = 1 },
    flip_x: bool = false,
    flip_y: bool = false,
};

pub inline fn appendQuad(va: *VertArray, dest: Rect, src: Rect, params: QuadParams) !void {
    // TODO: reimplement
    // var corners = [_]Rect.Corner{
    //     .BotLeft,
    //     .BotRight,
    //     .TopLeft,
    //     .TopRight,
    // };
    // if (params.flip_x) {
    //     const tmp = .{
    //         corners[1],
    //         corners[0],
    //         corners[3],
    //         corners[2],
    //     };
    //     corners = tmp;
    // }
    // if (params.flip_y) {
    //     const tmp = .{
    //         corners[2],
    //         corners[3],
    //         corners[0],
    //         corners[1],
    //     };
    //     corners = tmp;
    // }

    try va.qarray.append(.{
        .sxo = src.x,
        .syo = src.y,
        .sxs = src.w - 1.0,
        .sys = src.h - 1.0,

        .dxo = dest.x,
        .dyo = dest.y,
        .dxs = dest.w - 1.0,
        .dys = dest.h - 1.0,

        .r = params.color.r,
        .g = params.color.g,
        .b = params.color.b,
        .a = params.color.a,
    });

    // try va.append(dest.getCorner(.BotLeft).toVector3(), src.getCorner(corners[0]), params.color);
    // try va.append(dest.getCorner(.BotRight).toVector3(), src.getCorner(corners[1]), params.color);
    // try va.append(dest.getCorner(.TopRight).toVector3(), src.getCorner(corners[3]), params.color);

    // try va.append(dest.getCorner(.BotLeft).toVector3(), src.getCorner(corners[0]), params.color);
    // try va.append(dest.getCorner(.TopLeft).toVector3(), src.getCorner(corners[2]), params.color);
    // try va.append(dest.getCorner(.TopRight).toVector3(), src.getCorner(corners[3]), params.color);
}

pub inline fn append(va: *VertArray, pos: Vec3, uv: Vec2, color: Color) !void {
    try va.array.append(Vert{
        .x = pos.x,
        .y = pos.y,
        .z = pos.z,
        .u = uv.x,
        .v = uv.y,
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    });
}
