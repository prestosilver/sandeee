const std = @import("std");
const vecs = @import("math/vecs.zig");
const cols = @import("math/colors.zig");
const c = @import("c.zig");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

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
    data: std.ArrayList(Vert),

    pub fn init() VertArray {
        var result = VertArray{ .data = std.ArrayList(Vert).init(allocator) };
        return result;
    }

    pub fn deinit(va: *VertArray) void {
        va.data.deinit();
    }

    pub fn append(va: *VertArray, pos: vecs.Vector3, uv: vecs.Vector2, color: cols.Color) void {
        va.data.append(Vert{
            .x = pos.x,
            .y = pos.y,
            .z = pos.z,
            .u = uv.x,
            .v = uv.y,
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = color.a,
        }) catch {};
    }
};
