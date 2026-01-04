const std = @import("std");
const zgl = @import("zgl");

const util = @import("../util.zig");

const math = @import("../math.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const TextureManager = util.TextureManager;
const VertArray = util.VertArray;
const Texture = util.Texture;
const Shader = util.Shader;
const allocator = util.allocator;
const graphics = util.Graphics;

const Self = @This();

const DrawerTextureKind = enum {
    none,
    atlas,
    texture,
};

const DrawerTexture = union(DrawerTextureKind) {
    none,
    atlas: []const u8,
    texture: Texture,

    pub fn equals(self: *DrawerTexture, other: DrawerTexture) bool {
        if (@as(DrawerTextureKind, self.*) != other) return false;

        return switch (self.*) {
            .none => true,
            .atlas => std.mem.eql(u8, self.atlas, other.atlas),
            .texture => self.texture.tex == other.texture.tex,
        };
    }

    pub fn dupe(self: *const DrawerTexture) !DrawerTexture {
        return switch (self.*) {
            .none => .none,
            .atlas => .{ .atlas = try allocator.dupe(u8, self.atlas) },
            .texture => .{ .texture = self.texture },
        };
    }

    pub fn deinit(self: *const DrawerTexture) void {
        return switch (self.*) {
            .atlas => allocator.free(self.atlas),
            .texture => {},
            .none => {},
        };
    }
};

pub fn Drawer(comptime T: type) type {
    return struct {
        const DrawerSelf = @This();

        pub const Data = T;

        texture: DrawerTexture,
        data: T,

        pub inline fn blank(data: T) DrawerSelf {
            return .{
                .texture = .none,
                .data = data,
            };
        }

        pub inline fn override(texture: Texture, data: T) DrawerSelf {
            return .{
                .texture = .{ .texture = texture },
                .data = data,
            };
        }

        pub inline fn atlas(texture: []const u8, data: T) DrawerSelf {
            return .{
                .texture = .{ .atlas = texture },
                .data = data,
            };
        }

        pub inline fn getVerts(self: *const DrawerSelf, pos: Vec3) !VertArray {
            return self.data.getVerts(pos);
        }
    };
}

pub const QueueEntry = struct {
    shader: Shader,
    texture: DrawerTexture,
    verts: VertArray,
    scissor: ?Rect = null,
    clear: ?Color = null,

    pub fn GetHash(entry: *QueueEntry) void {
        if (entry.hash != null) return;

        var hash: u8 = 128;

        const casted: []const u8 = std.mem.asBytes(&entry.scissor);
        for (casted) |ch|
            hash = ((hash << 5) +% hash) +% ch;

        for (0..entry.verts.hashLen()) |idx| {
            hash = ((hash << 5) +% hash) +% entry.verts.array.items[idx * 6].getHash();
            hash = ((hash << 5) +% hash) +% entry.verts.array.items[idx * 6 + 1].getHash();
        }

        entry.hash = hash;
    }
};

pub var global: Self = .{};

prev_queue: []QueueEntry = &.{},
queue: []QueueEntry = &.{},
buffers: []zgl.Buffer = &.{},
qbuffers: []zgl.Buffer = &.{},
scissor: ?Rect = null,
queue_lock: std.Thread.Mutex = .{},
quad: zgl.Buffer = .invalid,

size: *Vec2 = undefined,

const quadVerts = [_]zgl.Float{
    0.0, 1.0,
    1.0, 0.0,
    0.0, 0.0,
    0.0, 1.0,
    1.0, 0.0,
    1.0, 1.0,
};

pub fn draw(sb: *Self, comptime T: type, drawer: *const T, shader: *Shader, pos: Vec3) !void {
    const entry: QueueEntry = .{
        .texture = drawer.texture,
        .verts = try drawer.getVerts(pos),
        .shader = shader.*,
    };

    try sb.addEntry(&entry);
}

pub fn addEntry(sb: *Self, entry: *const QueueEntry) !void {
    var new_entry = entry.*;

    new_entry.scissor = sb.scissor;

    sb.queue_lock.lock();
    defer sb.queue_lock.unlock();

    if (sb.queue.len != 0 and sb.queue[sb.queue.len - 1].texture.equals(entry.texture) and
        sb.queue[sb.queue.len - 1].shader.program == new_entry.shader.program and
        std.meta.eql(new_entry.scissor, sb.queue[sb.queue.len - 1].scissor) and
        new_entry.clear == null and sb.queue[sb.queue.len - 1].clear == null)
    {
        try sb.queue[sb.queue.len - 1].verts.array.appendSlice(new_entry.verts.items());
        try sb.queue[sb.queue.len - 1].verts.qarray.appendSlice(new_entry.verts.quads());

        new_entry.verts.deinit();

        return;
    }

    new_entry.texture = try entry.texture.dupe();
    sb.queue = try allocator.realloc(sb.queue, sb.queue.len + 1);
    sb.queue[sb.queue.len - 1] = new_entry;
}

pub fn render(sb: *Self) !void {
    zgl.enable(.blend);
    zgl.blendFunc(.src_alpha, .one_minus_src_alpha);

    {
        sb.queue_lock.lock();
        defer sb.queue_lock.unlock();

        if (sb.qbuffers.len != sb.queue.len) {
            const target = sb.queue.len;

            if (target < sb.qbuffers.len) {
                zgl.deleteBuffers(sb.qbuffers[target + 1 ..]);
                sb.qbuffers = try allocator.realloc(sb.qbuffers, target);
            } else if (target > sb.qbuffers.len) {
                const old = sb.qbuffers.len;

                sb.qbuffers = try allocator.realloc(sb.qbuffers, target);
                zgl.genBuffers(sb.qbuffers[old..target]);
            }
        }

        if (sb.buffers.len != sb.queue.len) {
            const target = sb.queue.len;

            if (target < sb.buffers.len) {
                zgl.deleteBuffers(sb.buffers[target + 1 ..]);
                sb.buffers = try allocator.realloc(sb.buffers, target);
            } else if (target > sb.buffers.len) {
                const old = sb.buffers.len;

                sb.buffers = try allocator.realloc(sb.buffers, target);
                zgl.genBuffers(sb.buffers[old..target]);
            }
        }

        var ctex: zgl.Texture = .invalid;
        var cshader: zgl.Program = .invalid;
        var cscissor: ?Rect = null;

        for (sb.queue, 0..) |entry, idx| {
            var uscissor = false;

            if (((cscissor != null) != (entry.scissor != null))) {
                uscissor = true;
            } else if ((cscissor != null) and (entry.scissor != null)) {
                uscissor = !Rect.equal(cscissor.?, entry.scissor.?);
            }

            if (uscissor) {
                if (entry.scissor) |scissor| {
                    zgl.enable(.scissor_test);
                    zgl.scissor(
                        @intFromFloat(@round(scissor.x)),
                        @intFromFloat(@round(sb.size.y - scissor.y - scissor.h)),
                        @intFromFloat(@round(scissor.w)),
                        @intFromFloat(@round(scissor.h)),
                    );
                } else {
                    zgl.disable(.scissor_test);
                }
            }

            cscissor = entry.scissor;

            if (entry.clear) |clearColor| {
                zgl.clearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
                zgl.clear(.{ .color = true });
            }

            if (entry.verts.items().len == 0 and entry.verts.quads().len == 0) continue;

            const target_tex = switch (entry.texture) {
                .none => &Texture{ .tex = .invalid, .size = .{}, .buffer = &.{} },
                .atlas => |a| TextureManager.instance.get(a) orelse
                    TextureManager.instance.get("error") orelse
                    return error.TextureMissing,
                .texture => |t| &t,
            };

            if (ctex != target_tex.tex)
                target_tex.tex.bind(.@"2d");
            ctex = target_tex.tex;

            if (cshader != entry.shader.program)
                entry.shader.program.use();
            cshader = entry.shader.program;

            if (sb.quad == .invalid) {
                sb.quad = zgl.genBuffer();
                sb.quad.bind(.array_buffer);
                zgl.bufferData(.array_buffer, zgl.Float, &quadVerts, .stream_draw);
            }

            if (entry.verts.items().len > 0) {
                sb.buffers[idx].bind(.array_buffer);
                zgl.bufferData(.array_buffer, VertArray.Vert, entry.verts.items(), .stream_draw);

                zgl.vertexAttribPointer(0, 3, .float, false, @sizeOf(VertArray.Vert), @offsetOf(VertArray.Vert, "x"));
                zgl.vertexAttribPointer(1, 2, .float, false, @sizeOf(VertArray.Vert), @offsetOf(VertArray.Vert, "u"));
                zgl.vertexAttribPointer(2, 4, .float, false, @sizeOf(VertArray.Vert), @offsetOf(VertArray.Vert, "r"));
                zgl.enableVertexAttribArray(0);
                zgl.enableVertexAttribArray(1);
                zgl.enableVertexAttribArray(2);
                zgl.disableVertexAttribArray(3);
                zgl.disableVertexAttribArray(4);
                zgl.disableVertexAttribArray(5);
                zgl.disableVertexAttribArray(6);

                zgl.drawArrays(.triangles, 0, entry.verts.items().len);
            }

            if (entry.verts.quads().len > 0) {
                sb.quad.bind(.array_buffer);
                zgl.vertexAttribPointer(0, 2, .float, false, @sizeOf([2]zgl.Float), 0);
                zgl.vertexAttribPointer(1, 2, .float, false, @sizeOf([2]zgl.Float), 0);

                sb.qbuffers[idx].bind(.array_buffer);
                zgl.bufferData(.array_buffer, VertArray.Quad, entry.verts.quads(), .stream_draw);

                zgl.vertexAttribPointer(2, 4, .float, false, @sizeOf(VertArray.Quad), @offsetOf(VertArray.Quad, "r"));
                zgl.vertexAttribPointer(3, 2, .float, false, @sizeOf(VertArray.Quad), @offsetOf(VertArray.Quad, "sxo"));
                zgl.vertexAttribPointer(4, 2, .float, false, @sizeOf(VertArray.Quad), @offsetOf(VertArray.Quad, "sxs"));
                zgl.vertexAttribPointer(5, 2, .float, false, @sizeOf(VertArray.Quad), @offsetOf(VertArray.Quad, "dxo"));
                zgl.vertexAttribPointer(6, 2, .float, false, @sizeOf(VertArray.Quad), @offsetOf(VertArray.Quad, "dxs"));
                zgl.enableVertexAttribArray(0);
                zgl.enableVertexAttribArray(1);
                zgl.enableVertexAttribArray(2);
                zgl.enableVertexAttribArray(3);
                zgl.enableVertexAttribArray(4);
                zgl.enableVertexAttribArray(5);
                zgl.enableVertexAttribArray(6);
                zgl.vertexAttribDivisor(2, 1);
                zgl.vertexAttribDivisor(3, 1);
                zgl.vertexAttribDivisor(4, 1);
                zgl.vertexAttribDivisor(5, 1);
                zgl.vertexAttribDivisor(6, 1);

                zgl.drawArraysInstanced(.triangles, 0, 6, entry.verts.quads().len);

                zgl.vertexAttribDivisor(2, 0);
                zgl.vertexAttribDivisor(3, 0);
                zgl.vertexAttribDivisor(4, 0);
                zgl.vertexAttribDivisor(5, 0);
                zgl.vertexAttribDivisor(6, 0);
            }
        }

        if (cscissor != null) zgl.disable(.scissor_test);
    }

    try sb.clear();
}

pub fn clear(sb: *Self) !void {
    sb.queue_lock.lock();
    defer sb.queue_lock.unlock();

    for (sb.prev_queue) |*e| {
        e.verts.deinit();
        e.texture.deinit();
    }

    allocator.free(sb.prev_queue);
    sb.prev_queue = sb.queue;
    sb.queue = &.{};
}

pub fn deinit(self: *const Self) void {
    for (self.prev_queue) |*e| {
        e.verts.deinit();
        e.texture.deinit();
    }

    for (self.queue) |*e| {
        e.verts.deinit();
        e.texture.deinit();
    }

    allocator.free(self.qbuffers);
    allocator.free(self.buffers);
    allocator.free(self.queue);
    allocator.free(self.prev_queue);
}
