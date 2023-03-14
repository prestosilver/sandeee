const std = @import("std");
const gfx = @import("graphics.zig");
const vecs = @import("math/vecs.zig");
const rect = @import("math/rects.zig");
const tex = @import("texture.zig");
const shd = @import("shader.zig");
const va = @import("vertArray.zig");
const allocator = @import("util/allocator.zig");
const c = @import("c.zig");

pub fn Drawer(comptime T: type) type {
    return struct {
        const Self = @This();

        texture: *tex.Texture,
        data: T,

        pub fn getVerts(self: *Self, pos: vecs.Vector3) !va.VertArray {
            return self.data.getVerts(pos);
        }

        pub fn new(texture: *tex.Texture, self: T) Drawer(T) {
            return Self{
                .texture = texture,
                .data = self,
            };
        }
    };
}

pub const QueueEntry = struct {
    update: bool,
    shader: shd.Shader,
    texture: *tex.Texture,
    verts: va.VertArray,
    scissor: ?rect.Rectangle = null,
    hash: u32 = 0,

    pub fn GetHash(entry: *QueueEntry) u32 {
        var hash = std.hash.Adler32.init();
        var casted = @ptrCast(*[4]u8, &entry.texture.tex);
        hash.update(casted);
        if (entry.scissor != null) {
            casted = @ptrCast(*[4]u8, &entry.scissor.?.x);
            hash.update(casted);
            casted = @ptrCast(*[4]u8, &entry.scissor.?.y);
            hash.update(casted);
            casted = @ptrCast(*[4]u8, &entry.scissor.?.w);
            hash.update(casted);
            casted = @ptrCast(*[4]u8, &entry.scissor.?.h);
            hash.update(casted);
        }

        for (entry.verts.data) |_, idx| {
            var castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].x);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].y);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].z);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].u);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].v);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].r);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].g);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].b);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data[idx].a);
            hash.update(castedItem);
        }

        return hash.final();
    }
};

pub const SpriteBatch = struct {
    prevQueue: []QueueEntry,
    queue: []QueueEntry,
    buffers: []c.GLuint,
    scissor: ?rect.Rectangle = null,
    size: *vecs.Vector2,

    pub fn draw(sb: *SpriteBatch, comptime T: type, drawer: *T, shader: *shd.Shader, pos: vecs.Vector3) !void {
        var entry = QueueEntry{
            .update = true,
            .texture = drawer.texture,
            .verts = try drawer.getVerts(pos),
            .shader = shader.*,
        };

        try sb.addEntry(&entry);
    }

    pub fn addEntry(sb: *SpriteBatch, entry: *QueueEntry) !void {
        entry.scissor = sb.scissor;

        if (sb.queue.len == 0) {
            sb.queue = try allocator.alloc.realloc(sb.queue, sb.queue.len + 1);
            sb.queue[sb.queue.len - 1] = entry.*;
        } else {
            var last = &sb.queue[sb.queue.len - 1];
            if (last.texture.tex == entry.texture.tex and
                last.shader.id == entry.shader.id and
                entry.scissor != null and last.scissor != null and
                rect.Rectangle.equal(last.scissor.?, entry.scissor.?))
            {
                var start = last.verts.data.len;
                last.verts.data = try allocator.alloc.realloc(last.verts.data, last.verts.data.len + entry.verts.data.len);
                std.mem.copy(va.Vert, last.verts.data[start..], entry.verts.data);
                entry.verts.deinit();
            } else {
                sb.queue = try allocator.alloc.realloc(sb.queue, sb.queue.len + 1);
                sb.queue[sb.queue.len - 1] = entry.*;
            }
        }
    }

    pub fn render(sb: *SpriteBatch) !void {
        if (sb.queue.len != 0) {
            for (sb.queue) |_, idx| {
                if (idx >= sb.prevQueue.len) break;
                sb.queue[idx].hash = (&sb.queue[idx]).GetHash();
                sb.queue[idx].update = (sb.queue[idx].hash != sb.prevQueue[idx].hash);
            }
        }

        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        if (sb.buffers.len != sb.queue.len) {
            var target = sb.queue.len;

            if (target < sb.buffers.len) {
                c.glDeleteBuffers(@intCast(c.GLint, sb.buffers.len - target), &sb.buffers[target]);
                sb.buffers = try allocator.alloc.realloc(sb.buffers, target);
            } else if (target > sb.buffers.len) {
                var old = sb.buffers.len;

                sb.buffers = try allocator.alloc.realloc(sb.buffers, target);

                c.glGenBuffers(@intCast(c.GLint, target - old), &sb.buffers[old]);
            }
        }

        var ctex: c.GLuint = 0;
        var cshader: c.GLuint = 0;
        var cscissor: ?rect.Rectangle = null;

        for (sb.queue) |entry, idx| {
            if (ctex != entry.texture.tex)
                c.glBindTexture(c.GL_TEXTURE_2D, entry.texture.tex);

            if (cshader != entry.shader.id)
                c.glUseProgram(entry.shader.id);

            var uscissor = false;

            if (((cscissor != null) != (entry.scissor != null))) {
                uscissor = true;
            } else if ((cscissor != null) and (entry.scissor != null)) {
                uscissor = !rect.Rectangle.equal(cscissor.?, entry.scissor.?);
            }

            if (uscissor and entry.scissor != null) {
                c.glEnable(c.GL_SCISSOR_TEST);
                c.glScissor(
                    @floatToInt(c_int, entry.scissor.?.x),
                    @floatToInt(c_int, sb.size.y - entry.scissor.?.y - entry.scissor.?.h),
                    @floatToInt(c_int, entry.scissor.?.w),
                    @floatToInt(c_int, entry.scissor.?.h),
                );
            } else if (uscissor) {
                c.glDisable(c.GL_SCISSOR_TEST);
            }

            c.glBindBuffer(c.GL_ARRAY_BUFFER, sb.buffers[idx]);

            ctex = entry.texture.tex;
            cshader = entry.shader.id;
            cscissor = entry.scissor;

            if (entry.update and entry.verts.data.len != 0) {
                var data = std.ArrayList(c.GLfloat).init(allocator.alloc);

                for (entry.verts.data) |verts| {
                    var a = verts.array();
                    try data.appendSlice(&a);
                }
                c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c.GLsizeiptr, data.items.len * @sizeOf(f32)), &(data.items[0]), c.GL_DYNAMIC_DRAW);

                data.deinit();
            }

            c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 9 * @sizeOf(f32), null);
            c.glVertexAttribPointer(1, 2, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @intToPtr(*anyopaque, 3 * @sizeOf(f32)));
            c.glVertexAttribPointer(2, 4, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @intToPtr(*anyopaque, 5 * @sizeOf(f32)));
            c.glEnableVertexAttribArray(0);
            c.glEnableVertexAttribArray(1);
            c.glEnableVertexAttribArray(2);

            c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c.GLsizei, entry.verts.data.len));
        }
        if (cscissor != null)
            c.glDisable(c.GL_SCISSOR_TEST);

        for (sb.prevQueue) |_, idx| {
            var e = sb.prevQueue[idx];
            e.verts.deinit();
        }

        allocator.alloc.free(sb.prevQueue);
        sb.prevQueue = sb.queue;
        sb.queue = try allocator.alloc.alloc(QueueEntry, 0);
    }

    pub fn deinit(sb: SpriteBatch) void {
        for (sb.prevQueue) |_, idx| {
            var e = sb.prevQueue[idx];
            e.verts.deinit();
        }
        for (sb.queue) |_, idx| {
            var e = sb.queue[idx];
            e.verts.deinit();
        }

        allocator.alloc.free(sb.buffers);
        allocator.alloc.free(sb.queue);
        allocator.alloc.free(sb.prevQueue);
    }
};

pub fn newSpritebatch(size: *vecs.Vector2) !SpriteBatch {
    var buffer = try allocator.alloc.alloc(c.GLuint, 0);
    var q = try allocator.alloc.alloc(QueueEntry, 0);
    var pq = try allocator.alloc.alloc(QueueEntry, 0);

    return SpriteBatch{
        .prevQueue = pq,
        .queue = q,
        .buffers = buffer,
        .size = size,
    };
}
