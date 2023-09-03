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

pub const VertArray = struct {
    array: std.ArrayList(Vert),

    pub inline fn init(cap: usize) !VertArray {
        return VertArray{
            .array = try std.ArrayList(Vert).initCapacity(allocator.alloc, cap),
        };
    }

    pub inline fn deinit(va: *const VertArray) void {
        va.array.deinit();
    }

    pub inline fn items(va: *const VertArray) []const Vert {
        return va.array.items;
    }

    pub inline fn hashLen(va: *const VertArray) usize {
        return va.array.items.len / 6;
    }

    pub inline fn setLen(va: *VertArray, len: usize) void {
        va.array.shrinkAndFree(len);
    }

    pub inline fn append(va: *VertArray, pos: vecs.Vector3, uv: vecs.Vector2, color: cols.Color) !void {
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
