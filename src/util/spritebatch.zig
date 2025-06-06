const std = @import("std");
const gfx = @import("graphics.zig");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const col = @import("../math/colors.zig");
const tex = @import("../util/texture.zig");
const shd = @import("../util/shader.zig");
const va = @import("../util/vertArray.zig");
const allocator = @import("allocator.zig");
const c = @import("../c.zig");

const TextureManager = @import("../util/texmanager.zig");

const Self = @This();

const DrawerTextureKind = enum {
    none,
    atlas,
    texture,
};

const DrawerTexture = union(DrawerTextureKind) {
    none,
    atlas: []const u8,
    texture: tex.Texture,

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
            .atlas => .{ .atlas = try allocator.alloc.dupe(u8, self.atlas) },
            .texture => .{ .texture = self.texture },
        };
    }

    pub fn deinit(self: *const DrawerTexture) void {
        return switch (self.*) {
            .atlas => allocator.alloc.free(self.atlas),
            .texture => {},
            .none => {},
        };
    }
};

pub fn Drawer(comptime T: type) type {
    return struct {
        const DrawerSelf = @This();

        texture: DrawerTexture,
        data: T,

        pub inline fn blank(data: T) DrawerSelf {
            return .{
                .texture = .none,
                .data = data,
            };
        }

        pub inline fn override(texture: tex.Texture, data: T) DrawerSelf {
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

        pub inline fn getVerts(self: *const DrawerSelf, pos: vecs.Vector3) !va.VertArray {
            return self.data.getVerts(pos);
        }
    };
}

pub const QueueEntry = struct {
    shader: shd.Shader,
    texture: DrawerTexture,
    verts: va.VertArray,
    scissor: ?rect.Rectangle = null,
    clear: ?col.Color = null,

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
buffers: []c.GLuint = &.{},
scissor: ?rect.Rectangle = null,
queue_lock: std.Thread.Mutex = .{},

size: *vecs.Vector2 = undefined,

pub fn draw(sb: *Self, comptime T: type, drawer: *const T, shader: *shd.Shader, pos: vecs.Vector3) !void {
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
        sb.queue[sb.queue.len - 1].shader.id == new_entry.shader.id and
        new_entry.scissor == null and sb.queue[sb.queue.len - 1].scissor == null and
        new_entry.clear == null and sb.queue[sb.queue.len - 1].clear == null)
    {
        try sb.queue[sb.queue.len - 1].verts.array.appendSlice(new_entry.verts.items());

        new_entry.verts.deinit();

        return;
    }

    new_entry.texture = try entry.texture.dupe();
    sb.queue = try allocator.alloc.realloc(sb.queue, sb.queue.len + 1);
    sb.queue[sb.queue.len - 1] = new_entry;
}

pub fn render(sb: *Self) !void {
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    {
        sb.queue_lock.lock();
        defer sb.queue_lock.unlock();

        if (sb.buffers.len != sb.queue.len) {
            const target = sb.queue.len;

            if (target < sb.buffers.len) {
                c.glDeleteBuffers(@as(c.GLint, @intCast(sb.buffers.len - target)), &sb.buffers[target]);
                sb.buffers = try allocator.alloc.realloc(sb.buffers, target);
            } else if (target > sb.buffers.len) {
                const old = sb.buffers.len;

                sb.buffers = try allocator.alloc.realloc(sb.buffers, target);

                c.glGenBuffers(@as(c.GLint, @intCast(target - old)), &sb.buffers[old]);
            }
        }

        var ctex: c.GLuint = 0;
        var cshader: c.GLuint = 0;
        var cscissor: ?rect.Rectangle = null;

        for (sb.queue, 0..) |entry, idx| {
            var uscissor = false;

            if (((cscissor != null) != (entry.scissor != null))) {
                uscissor = true;
            } else if ((cscissor != null) and (entry.scissor != null)) {
                uscissor = !rect.Rectangle.equal(cscissor.?, entry.scissor.?);
            }

            if (uscissor) {
                if (entry.scissor) |scissor| {
                    c.glEnable(c.GL_SCISSOR_TEST);
                    c.glScissor(
                        @as(c_int, @intFromFloat(@round(scissor.x))),
                        @as(c_int, @intFromFloat(@round(sb.size.y - scissor.y - scissor.h))),
                        @as(c_int, @intFromFloat(@round(scissor.w))),
                        @as(c_int, @intFromFloat(@round(scissor.h))),
                    );
                } else {
                    c.glDisable(c.GL_SCISSOR_TEST);
                }
            }

            cscissor = entry.scissor;

            if (entry.clear) |clearColor| {
                c.glClearColor(clearColor.r, clearColor.g, clearColor.b, 1.0);
                c.glClear(c.GL_COLOR_BUFFER_BIT);
            }

            if (entry.verts.items().len == 0) continue;

            const target_tex = switch (entry.texture) {
                .none => &tex.Texture{ .tex = 0, .size = .{}, .buffer = &.{} },
                .atlas => |a| TextureManager.instance.get(a) orelse
                    TextureManager.instance.get("error") orelse
                    return error.TextureMissing,
                .texture => |t| &t,
            };

            if (ctex != target_tex.tex)
                c.glBindTexture(c.GL_TEXTURE_2D, target_tex.tex);

            if (cshader != entry.shader.id)
                c.glUseProgram(entry.shader.id);

            c.glBindBuffer(c.GL_ARRAY_BUFFER, sb.buffers[idx]);

            ctex = target_tex.tex;
            cshader = entry.shader.id;

            c.glBufferData(c.GL_ARRAY_BUFFER, @as(c.GLsizeiptr, @intCast(entry.verts.items().len * @sizeOf(va.Vert))), entry.verts.items().ptr, c.GL_STREAM_DRAW);

            c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 9 * @sizeOf(f32), null);
            c.glVertexAttribPointer(1, 2, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
            c.glVertexAttribPointer(2, 4, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @ptrFromInt(5 * @sizeOf(f32)));
            c.glEnableVertexAttribArray(0);
            c.glEnableVertexAttribArray(1);
            c.glEnableVertexAttribArray(2);

            c.glDrawArrays(c.GL_TRIANGLES, 0, @as(c.GLsizei, @intCast(entry.verts.items().len)));
        }

        if (cscissor != null)
            c.glDisable(c.GL_SCISSOR_TEST);
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

    allocator.alloc.free(sb.prev_queue);
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

    allocator.alloc.free(self.buffers);
    allocator.alloc.free(self.queue);
    allocator.alloc.free(self.prev_queue);
}
