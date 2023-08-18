const std = @import("std");

const vecs = @import("vecs.zig");

pub const Mat4 = struct {
    data: [16]f32,

    pub fn lookAt(eye: vecs.Vector3, center: vecs.Vector3, up: vecs.Vector3) Mat4 {
        const f = (center - eye).normalize();
        const s = vecs.Vector3.cross(f, up).normalize();
        const u = vecs.Vector3.cross(s, f);

        return Mat4{
            .data = .{
                s.x,                       s.y,                       s.z,                      0,
                u.x,                       u.y,                       u.z,                      0,
                f.x,                       f.y,                       f.z,                      0,
                -vecs.Vector3.dot(s, eye), -vecs.Vector3.dot(u, eye), vecs.Vector3.dot(f, eye), 1,
            },
        };
    }

    pub fn perspective(fovy: f32, aspect: f32, n: f32, f: f32) !Mat4 {
        const thFov = @tan(fovy / 2);

        return .{
            .data = .{
                1.0 / (aspect * thFov), 0,             0,                      0,
                0,                      1.0 / (thFov), 0,                      0,
                0,                      0,             (f + n) / (f - n),      1,
                0,                      0,             -(2 * f + n) / (f - n), 0,
            },
        };
    }

    pub fn ortho(l: f32, r: f32, b: f32, t: f32, n: f32, f: f32) !Mat4 {
        return .{
            .data = .{
                2 / (r - l),        0,                  0,                  0,
                0,                  2 / (t - b),        0,                  0,
                0,                  0,                  2 / (n - f),        0,
                -(r + l) / (r - l), -(t + b) / (t - b), -(f + n) / (f - n), 1,
            },
        };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;

        for (0..4) |i| {
            for (0..4) |j| {
                result.data[i + j * 4] = 0;
                for (0..4) |k| {
                    result.data[i + j * 4] += a.data[i + k * 4] * b.data[k + j * 4];
                }
            }
        }

        return result;
    }
};
