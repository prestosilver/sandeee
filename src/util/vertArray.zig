const std = @import("std");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const c = @import("../c.zig");
const allocator = @import("allocator.zig");

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

    pub fn array(v: Vert) [9]f32 {
        return [9]f32{
            v.x,
            v.y,
            v.z,
            v.u,
            v.v,
            v.r,
            v.g,
            v.b,
            v.a,
        };
    }

    pub fn getHash(v: Vert) u32 {
        var casted = std.mem.asBytes(&[_]f32{ v.x, v.y, v.u, v.v, v.r, v.g, v.b });
        var hash: u32 = 1235;
        for (casted) |ch|
            hash = ((hash << 5) +% hash) +% ch;

        return hash;
    }
};

pub const VertArray = struct {
    array: std.ArrayList(Vert),

    pub fn init() !VertArray {
        var result = VertArray{
            .array = std.ArrayList(Vert).init(allocator.alloc),
        };
        return result;
    }

    pub fn deinit(va: *VertArray) void {
        va.array.deinit();
    }

    pub fn items(va: VertArray) []const Vert {
        return va.array.items;
    }

    pub fn append(va: *VertArray, pos: vecs.Vector3, uv: vecs.Vector2, color: cols.Color) !void {
        try va.array.append(Vert{
            .x = @round(pos.x),
            .y = @round(pos.y),
            .z = pos.z,
            .u = uv.x,
            .v = uv.y,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = color.a,
        });
    }
};
