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

        texture: tex.Texture,
        data: T,

        pub fn getVerts(self: *Self, pos: vecs.Vector3) va.VertArray {
            return self.data.getVerts(pos);
        }

        pub fn new(texture: tex.Texture, self: T) Drawer(T) {
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
    texture: tex.Texture,
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

        for (entry.verts.data.items) |_, idx| {
            var castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].x);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].y);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].z);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].u);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].v);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].r);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].g);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].b);
            hash.update(castedItem);
            castedItem = @ptrCast(*[4]u8, &entry.verts.data.items[idx].a);
            hash.update(castedItem);
        }

        return hash.final();
    }
};

pub const SpriteBatch = struct {
    prevQueue: std.ArrayList(QueueEntry),
    queue: std.ArrayList(QueueEntry),
    buffers: std.ArrayList(c.GLuint),
    scissor: ?rect.Rectangle = null,
    size: vecs.Vector2 = vecs.newVec2(640, 480),

    pub fn draw(sb: *SpriteBatch, comptime T: type, drawer: *T, shader: shd.Shader, pos: vecs.Vector3) void {
        var entry = QueueEntry{
            .update = true,
            .texture = drawer.texture,
            .verts = drawer.getVerts(pos),
            .shader = shader,
        };

        sb.addEntry(&entry);
    }

    pub fn addEntry(sb: *SpriteBatch, entry: *QueueEntry) void {
        entry.scissor = sb.scissor;

        if (sb.queue.items.len == 0) {
            sb.queue.append(entry.*) catch {};
        } else {
            var last = &sb.queue.items[sb.queue.items.len - 1];
            if (last.texture.tex == entry.texture.tex and
                last.shader.id == entry.shader.id and
                entry.scissor != null and last.scissor != null and
                rect.Rectangle.equal(last.scissor.?, entry.scissor.?))
            {
                std.ArrayList(va.Vert).appendSlice(&last.verts.data, entry.verts.data.items) catch {};
                entry.verts.data.deinit();
            } else {
                sb.queue.append(entry.*) catch {};
            }
        }
    }

    pub fn render(sb: *SpriteBatch) void {
        if (sb.queue.items.len != 0) {
            for (sb.queue.items) |_, idx| {
                if (idx >= sb.prevQueue.items.len) break;
                sb.queue.items[idx].hash = (&sb.queue.items[idx]).GetHash();
                sb.queue.items[idx].update = (sb.queue.items[idx].hash != sb.prevQueue.items[idx].hash);
            }
        }

        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        if (sb.buffers.items.len != sb.queue.items.len) {
            var target = sb.queue.items.len;

            if (target < sb.buffers.items.len) {
                c.glDeleteBuffers(@intCast(c.GLint, sb.buffers.items.len - target), &sb.buffers.items[target]);
                sb.buffers.shrinkAndFree(target);
            } else if (target > sb.buffers.items.len) {
                var old = sb.buffers.items.len;

                sb.buffers.resize(target) catch {};

                c.glGenBuffers(@intCast(c.GLint, target - old), &sb.buffers.items[old]);
            }
        }

        var ctex: c.GLuint = 0;
        var cshader: c.GLuint = 0;
        var cscissor: ?rect.Rectangle = null;

        for (sb.queue.items) |entry, idx| {
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

            c.glBindBuffer(c.GL_ARRAY_BUFFER, sb.buffers.items[idx]);

            ctex = entry.texture.tex;
            cshader = entry.shader.id;
            cscissor = entry.scissor;

            if (entry.update and entry.verts.data.items.len != 0) {
                var data = std.ArrayList(c.GLfloat).init(allocator.alloc);

                for (entry.verts.data.items) |verts| {
                    var a = verts.array();
                    data.appendSlice(&a) catch {};
                }

                c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c.GLsizeiptr, data.items.len * @sizeOf(f32)), &(data.items[0]), c.GL_STREAM_DRAW);

                data.deinit();
            }

            c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 9 * @sizeOf(f32), null);
            c.glEnableVertexAttribArray(0);
            c.glVertexAttribPointer(1, 2, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @intToPtr(*anyopaque, 3 * @sizeOf(f32)));
            c.glEnableVertexAttribArray(1);
            c.glVertexAttribPointer(2, 4, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @intToPtr(*anyopaque, 5 * @sizeOf(f32)));
            c.glEnableVertexAttribArray(2);

            c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c.GLsizei, entry.verts.data.items.len));
        }
        if (cscissor != null)
            c.glDisable(c.GL_SCISSOR_TEST);

        for (sb.prevQueue.items) |_, idx| {
            var e = sb.prevQueue.items[idx];
            e.verts.data.deinit();
        }

        sb.prevQueue.clearAndFree();
        std.ArrayList(QueueEntry).appendSlice(&sb.prevQueue, sb.queue.items) catch {};
        for (sb.queue.items) |_, idx| {
            var e = sb.queue.items[idx];
            e.verts.data.deinit();
        }
        sb.queue.clearAndFree();
    }

    pub fn deinit(sb: SpriteBatch) void {
        for (sb.prevQueue.items) |_, idx| {
            var e = sb.prevQueue.items[idx];
            e.verts.data.deinit();
        }
        for (sb.queue.items) |_, idx| {
            var e = sb.queue.items[idx];
            e.verts.data.deinit();
        }

        sb.buffers.deinit();
        sb.queue.deinit();
        sb.prevQueue.deinit();
    }
};

pub fn newSpritebatch() SpriteBatch {
    var buffer = std.ArrayList(c.GLuint).init(allocator.alloc);
    var q = std.ArrayList(QueueEntry).init(allocator.alloc);
    var pq = std.ArrayList(QueueEntry).init(allocator.alloc);

    return SpriteBatch{ .prevQueue = pq, .queue = q, .buffers = buffer };
}
