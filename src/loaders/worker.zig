const std = @import("std");
const allocator = @import("../util/allocator.zig");
const gfx = @import("../util/graphics.zig");
const c = @import("../c.zig");

pub const shader = @import("shader.zig");
pub const texture = @import("texture.zig");
pub const font = @import("font.zig");
pub const sound = @import("sound.zig");
pub const files = @import("files.zig");
pub const settings = @import("settings.zig");
pub const mail = @import("mail.zig");
pub const delay = @import("delay.zig");

pub fn WorkerQueueEntry(comptime T: type, comptime U: type) type {
    return struct {
        const Self = @This();

        indata: T,
        out: U,

        loader: *const fn (*Self) anyerror!bool,
    };
}

pub const fdsa = error{
    LoadError,
};

pub const WorkerContext = struct {
    queue: *std.atomic.Queue(WorkerQueueEntry(*void, *void)),
    total: usize = 0,

    pub fn WorkerQueueNode(comptime T: type, comptime U: type) type {
        return std.atomic.Queue(WorkerQueueEntry(T, U)).Node;
    }

    pub fn run(ctx: *WorkerContext, progress: *f32) !void {
        var prog: usize = 0;

        // run all the loader funcs
        while (ctx.queue.get()) |work_node| {
            if (!try work_node.data.loader(&work_node.data)) {
                return error.LoadError;
            }
            allocator.alloc.destroy(work_node);
            prog += 1;

            progress.* = @intToFloat(f32, prog) / @intToFloat(f32, ctx.total);
        }

        progress.* = 1;

        ctx.total = 0;
    }

    pub fn enqueue(self: *WorkerContext, indata: anytype, outdata: anytype, loader: *const fn (*WorkerQueueEntry(@TypeOf(indata), @TypeOf(outdata))) anyerror!bool) !void {
        const node = try allocator.alloc.create(WorkerQueueNode(@TypeOf(indata), @TypeOf(outdata)));

        node.* = .{
            .prev = undefined,
            .next = undefined,
            .data = .{
                .loader = loader,
                .indata = indata,
                .out = outdata,
            },
        };

        self.queue.put(@ptrCast(*WorkerQueueNode(*void, *void), node));
        self.total += 1;
    }
};
