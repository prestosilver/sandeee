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

        pub inline fn getVerts(self: *const Self, pos: vecs.Vector3) !va.VertArray {
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
    shader: shd.Shader,
    texture: []const u8,
    verts: va.VertArray,
    scissor: ?rect.Rectangle = null,
    hash: ?u32 = null,
    clear: ?col.Color = null,

    pub fn GetHash(entry: *QueueEntry) void {
        if (entry.hash != null) return;

        var hash: u8 = 128;

        var casted: []const u8 = std.mem.asBytes(&entry.scissor);
        for (casted) |ch|
            hash = ((hash << 5) +% hash) +% ch;

        for (0..entry.verts.hashLen()) |idx| {
            hash = ((hash << 5) +% hash) +% entry.verts.array.items[idx * 6].getHash();
            hash = ((hash << 5) +% hash) +% entry.verts.array.items[idx * 6 + 1].getHash();
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

    pub fn draw(sb: *SpriteBatch, comptime T: type, drawer: *const T, shader: *shd.Shader, pos: vecs.Vector3) !void {
        var entry = QueueEntry{
            .texture = drawer.texture,
            .verts = try drawer.getVerts(pos),
            .shader = shader.*,
        };

        try sb.addEntry(&entry);
    }

    pub fn addEntry(sb: *SpriteBatch, entry: *const QueueEntry) !void {
        sb.queueLock.lock();
        defer sb.queueLock.unlock();
        var newEntry = entry.*;

        newEntry.scissor = sb.scissor;
        newEntry.texture = try allocator.alloc.dupe(u8, entry.texture);

        sb.queue = try allocator.alloc.realloc(sb.queue, sb.queue.len + 1);
        sb.queue[sb.queue.len - 1] = newEntry;
    }

    pub fn render(sb: *SpriteBatch) !void {
        sb.queueLock.lock();
        defer sb.queueLock.unlock();

        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        if (sb.buffers.len != sb.queue.len) {
            var target = sb.queue.len;

            if (target < sb.buffers.len) {
                c.glDeleteBuffers(@as(c.GLint, @intCast(sb.buffers.len - target)), &sb.buffers[target]);
                sb.buffers = try allocator.alloc.realloc(sb.buffers, target);
            } else if (target > sb.buffers.len) {
                var old = sb.buffers.len;

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

            if (uscissor and entry.scissor != null) {
                c.glEnable(c.GL_SCISSOR_TEST);
                c.glScissor(
                    @as(c_int, @intFromFloat(@round(entry.scissor.?.x))),
                    @as(c_int, @intFromFloat(@round(sb.size.y - entry.scissor.?.y - entry.scissor.?.h))),
                    @as(c_int, @intFromFloat(@round(entry.scissor.?.w))),
                    @as(c_int, @intFromFloat(@round(entry.scissor.?.h))),
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

            var targTex = if (!std.mem.eql(u8, entry.texture, "none"))
                textureManager.get(entry.texture) orelse
                    textureManager.get("error") orelse {
                    sb.queueLock.unlock();
                    @panic("texture not found");
                }
            else
                &tex.Texture{ .tex = 0, .size = vecs.newVec2(0, 0), .buffer = undefined };

            if (ctex != targTex.tex)
                c.glBindTexture(c.GL_TEXTURE_2D, targTex.tex);

            if (cshader != entry.shader.id)
                c.glUseProgram(entry.shader.id);

            c.glBindBuffer(c.GL_ARRAY_BUFFER, sb.buffers[idx]);

            ctex = targTex.tex;
            cshader = entry.shader.id;

            if (entry.verts.items().len != 0) {
                c.glBufferData(c.GL_ARRAY_BUFFER, @as(c.GLsizeiptr, @intCast(entry.verts.items().len * @sizeOf(va.Vert))), entry.verts.items().ptr, c.GL_STREAM_DRAW);
            }

            c.glVertexAttribPointer(0, 3, c.GL_FLOAT, 0, 9 * @sizeOf(f32), null);
            c.glVertexAttribPointer(1, 2, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @as(*anyopaque, @ptrFromInt(3 * @sizeOf(f32))));
            c.glVertexAttribPointer(2, 4, c.GL_FLOAT, 0, 9 * @sizeOf(f32), @as(*anyopaque, @ptrFromInt(5 * @sizeOf(f32))));
            c.glEnableVertexAttribArray(0);
            c.glEnableVertexAttribArray(1);
            c.glEnableVertexAttribArray(2);

            c.glDrawArrays(c.GL_TRIANGLES, 0, @as(c.GLsizei, @intCast(entry.verts.items().len)));
        }
        if (cscissor != null)
            c.glDisable(c.GL_SCISSOR_TEST);

        try sb.clear();
    }

    pub fn clear(sb: *SpriteBatch) !void {
        for (sb.prevQueue, 0..) |_, idx| {
            var e = sb.prevQueue[idx];
            e.verts.deinit();
            allocator.alloc.free(e.texture);
        }

        allocator.alloc.free(sb.prevQueue);
        sb.prevQueue = sb.queue;
        sb.queue = try allocator.alloc.alloc(QueueEntry, 0);
    }

    pub fn deinit(sb: SpriteBatch) void {
        for (sb.prevQueue, 0..) |_, idx| {
            var e = sb.prevQueue[idx];
            e.verts.deinit();
            allocator.alloc.free(e.texture);
        }
        for (sb.queue, 0..) |_, idx| {
            var e = sb.queue[idx];
            e.verts.deinit();
            allocator.alloc.free(e.texture);
        }

        allocator.alloc.free(sb.buffers);
        allocator.alloc.free(sb.queue);
        allocator.alloc.free(sb.prevQueue);
    }

    pub fn init(size: *vecs.Vector2) !SpriteBatch {
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
};
