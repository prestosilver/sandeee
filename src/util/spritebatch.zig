const std = @import("std");
const gfx = @import("graphics.zig");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const col = @import("../math/colors.zig");
const tex = @import("../util/texture.zig");
const texMan = @import("../util/texmanager.zig");
const shd = @import("../util/shader.zig");
const va = @import("../util/vertArray.zig");
const allocator = @import("allocator.zig");
const c = @import("../c.zig");

pub var textureManager: *texMan.TextureManager = undefined;

pub fn Drawer(comptime T: type) type {
    return struct {
        const Self = @This();

        texture: []const u8,
        data: T,

        pub fn getVerts(self: *Self, pos: vecs.Vector3) !va.VertArray {
            return self.data.getVerts(pos);
        }

        pub fn new(texture: []const u8, self: T) Drawer(T) {
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
    texture: []const u8,
    verts: va.VertArray,
    scissor: ?rect.Rectangle = null,
    hash: ?u32 = null,
    clear: ?col.Color = null,

    pub fn GetHash(entry: *QueueEntry) void {
        if (entry.hash != null) return;

        var hash: u32 = 1235;

        var casted: []const u8 = std.mem.asBytes(&entry.scissor);
        for (casted) |ch|
            hash = ((hash << 5) +% hash) +% ch;

        for (entry.verts.items()) |*item| {
            hash = ((hash << 5) +% hash) +% item.getHash();
        }

        entry.hash = hash;
    }
};

pub const SpriteBatch = struct {
    prevQueue: []QueueEntry,
    queue: []QueueEntry,
    queueLock: std.Thread.Mutex = .{},

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
        sb.queueLock.lock();
        defer sb.queueLock.unlock();

        entry.scissor = sb.scissor;
        if (sb.queue.len == 0) {
            sb.queue = try allocator.alloc.realloc(sb.queue, sb.queue.len + 1);
            sb.queue[sb.queue.len - 1] = entry.*;
        } else {
            var last = &sb.queue[sb.queue.len - 1];
            if (std.mem.eql(u8, last.texture, entry.texture) and
                last.shader.id == entry.shader.id and
                entry.scissor != null and last.scissor != null and
                rect.Rectangle.equal(last.scissor.?, entry.scissor.?))
            {
                try last.verts.array.appendSlice(entry.verts.items());
                entry.verts.deinit();
            } else {
                sb.queue = try allocator.alloc.realloc(sb.queue, sb.queue.len + 1);
                sb.queue[sb.queue.len - 1] = entry.*;
            }
        }
    }

    pub fn render(sb: *SpriteBatch) !void {
        sb.queueLock.lock();
        defer sb.queueLock.unlock();

        if (sb.queue.len != 0) {
            for (sb.queue, 0..) |_, idx| {
                if (idx >= sb.prevQueue.len) break;
                if (sb.queue[idx].verts.items().len == sb.prevQueue[idx].verts.items().len) {
                    sb.queue[idx].GetHash();
                    sb.prevQueue[idx].GetHash();
                    sb.queue[idx].update = (sb.queue[idx].hash != sb.prevQueue[idx].hash);
                } else {
                    sb.queue[idx].update = true;
                }
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

        for (sb.queue, 0..) |entry, idx| {
            var uscissor = false;

            if (((cscissor != null) != (entry.scissor != null))) {
                uscissor = true;
            } else if ((cscissor != null) and (entry.scissor != null)) {
                uscissor = !rect.Rectangle.equal(cscissor.?, entry.scissor.?);
            }

            if (uscissor and entry.scissor != null) {
                c.glEnable(c.GL_SCISSOR_TEST);
                c.glScissor(
                    @floatToInt(c_int, @round(entry.scissor.?.x)),
                    @floatToInt(c_int, @round(sb.size.y - entry.scissor.?.y - entry.scissor.?.h)),
                    @floatToInt(c_int, @round(entry.scissor.?.w)),
                    @floatToInt(c_int, @round(entry.scissor.?.h)),
                );
            } else if (uscissor) {
                c.glDisable(c.GL_SCISSOR_TEST);
            }

            if (entry.clear) |clearColor| {
                c.glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
                c.glClear(c.GL_COLOR_BUFFER_BIT);
            }

            cscissor = entry.scissor;

            if (entry.texture.len == 0) continue;

            var targTex = if (!std.mem.eql(u8, entry.texture, "none")) textureManager.get(entry.texture) orelse {
                std.log.info("{any}", .{entry.texture});
                @panic("Texture not found");
            } else &tex.Texture{ .tex = 0, .size = vecs.newVec2(0, 0) };

            if (ctex != targTex.tex)
                c.glBindTexture(c.GL_TEXTURE_2D, targTex.tex);

            if (cshader != entry.shader.id)
                c.glUseProgram(entry.shader.id);

            c.glBindBuffer(c.GL_ARRAY_BUFFER, sb.buffers[idx]);

            ctex = targTex.tex;
            cshader = entry.shader.id;

            if (entry.update and entry.verts.items().len != 0) {
                c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c.GLsizeiptr, entry.verts.items().len * @sizeOf(va.Vert)), entry.verts.items().ptr, c.GL_STREAM_DRAW);
            }

            c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 9 * @sizeOf(f32), null);
            c.glVertexAttribPointer(1, 2, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @intToPtr(*anyopaque, 3 * @sizeOf(f32)));
            c.glVertexAttribPointer(2, 4, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @intToPtr(*anyopaque, 5 * @sizeOf(f32)));
            c.glEnableVertexAttribArray(0);
            c.glEnableVertexAttribArray(1);
            c.glEnableVertexAttribArray(2);

            c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c.GLsizei, entry.verts.items().len));
        }
        if (cscissor != null)
            c.glDisable(c.GL_SCISSOR_TEST);

        try sb.clear();
    }

    pub fn clear(sb: *SpriteBatch) !void {
        for (sb.prevQueue, 0..) |_, idx| {
            var e = sb.prevQueue[idx];
            e.verts.deinit();
        }

        allocator.alloc.free(sb.prevQueue);
        sb.prevQueue = sb.queue;
        sb.queue = try allocator.alloc.alloc(QueueEntry, 0);
    }

    pub fn deinit(sb: SpriteBatch) void {
        for (sb.prevQueue, 0..) |_, idx| {
            var e = sb.prevQueue[idx];
            e.verts.deinit();
        }
        for (sb.queue, 0..) |_, idx| {
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
