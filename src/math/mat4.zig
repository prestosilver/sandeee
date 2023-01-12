const std = @import("std");

const vecs = @import("vecs.zig");

extern "c" fn tan(a: f32) f32;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

pub const Mat4 = struct {
    data: std.ArrayList(f32),

    pub fn lookAt(eye: vecs.Vector3, center: vecs.Vector3, up: vecs.Vector3) Mat4 {
        const f = (center - eye).normalize();
        const s = vecs.Vector3.cross(f, up).normalize();
        const u = vecs.Vector3.cross(s, f);

        var buffer = std.ArrayList(f32).init(allocator);
        buffer.resize(16);

        var result: Mat4 = Mat4{
            .data = buffer,
        };
        result.data[0] = s.x;
        result.data[1] = s.y;
        result.data[2] = s.z;
        result.data[3] = 0;

        result.data[4] = u.x;
        result.data[5] = u.y;
        result.data[6] = u.z;
        result.data[7] = 0;

        result.data[8] = f.x;
        result.data[9] = f.y;
        result.data[10] = f.z;
        result.data[11] = 0;

        result.data[12] = -vecs.Vector3.dot(s, eye);
        result.data[13] = -vecs.Vector3.dot(u, eye);
        result.data[14] = vecs.Vector3.dot(f, eye);
        result.data[15] = 1;

        return result;
    }

    pub fn perspective(fovy: f32, aspect: f32, n: f32, f: f32) Mat4 {
        var buffer = std.ArrayList(f32).init(allocator);
        buffer.resize(16) catch {};

        var result: Mat4 = Mat4{
            .data = buffer,
        };

        var thFov = tan(fovy / 2);

        result.data.items[0] = 1 / (aspect * thFov);
        result.data.items[1] = 0.0;
        result.data.items[2] = 0.0;
        result.data.items[3] = 0.0;

        result.data.items[4] = 0.0;
        result.data.items[5] = 1 / (thFov);
        result.data.items[6] = 0.0;
        result.data.items[7] = 0.0;

        result.data.items[8] = 0.0;
        result.data.items[9] = 0.0;
        result.data.items[10] = (f + n) / (f - n);
        result.data.items[11] = 1.0;

        result.data.items[12] = 0.0;
        result.data.items[13] = 0.0;
        result.data.items[14] = -(2 * f + n) / (f - n);
        result.data.items[15] = 0.0;

        return result;
    }

    pub fn ortho(l: f32, r: f32, b: f32, t: f32, n: f32, f: f32) Mat4 {
        var buffer = std.ArrayList(f32).init(allocator);
        buffer.resize(16) catch {};

        var result: Mat4 = Mat4{
            .data = buffer,
        };

        result.data.items[0] = 2 / (r - l);
        result.data.items[1] = 0.0;
        result.data.items[2] = 0.0;
        result.data.items[3] = 0.0;

        result.data.items[4] = 0.0;
        result.data.items[5] = 2 / (t - b);
        result.data.items[6] = 0.0;
        result.data.items[7] = 0.0;

        result.data.items[8] = 0.0;
        result.data.items[9] = 0.0;
        result.data.items[10] = -2 / (f - n);
        result.data.items[11] = 0.0;

        result.data.items[12] = -(r + l) / (r - l);
        result.data.items[13] = -(t + b) / (t - b);
        result.data.items[14] = -(f + n) / (f - n);
        result.data.items[15] = 1.0;

        return result;
    }

    fn range(len: usize) []const void {
        return @as([*]void, undefined)[0..len];
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;

        for (range(4)) |i| {
            for (range(4)) |j| {
                result.data[i + j * 4] = 0;
                for (range(4)) |k| {
                    result.data[i + j * 4] += a.data[i + k * 4] * b.data[k + j * 4];
                }
            }
        }

        return result;
    }
};
