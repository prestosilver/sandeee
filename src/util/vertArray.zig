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
};

pub const VertArray = struct {
    items: []Vert,

    pub fn init() !VertArray {
        var result = VertArray{
            .items = try allocator.alloc.alloc(Vert, 0),
        };
        return result;
    }

    pub fn deinit(va: *VertArray) void {
        allocator.alloc.free(va.items);
    }

    pub fn append(va: *VertArray, pos: vecs.Vector3, uv: vecs.Vector2, color: cols.Color) !void {
        va.items = try allocator.alloc.realloc(va.items, va.items.len + 1);

        va.items[va.items.len - 1] = Vert{
            .x = pos.x,
            .y = pos.y,
            .z = pos.z,
            .u = uv.x,
            .v = uv.y,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = color.a,
        };
    }
};
