const std = @import("std");
const allocator = @import("../util/allocator.zig");
pub const shader = @import("shader.zig");
pub const texture = @import("texture.zig");

pub fn WorkerQueueEntry(comptime T: type, comptime U: type) type {
    return struct {
        const Self = @This();

        indata: T,
        out: U,

        loader: *const fn (*Self) bool,
    };
}

pub const fdsa = error{
    LoadError,
};

pub const WorkerContext = struct {
    queue: *std.atomic.Queue(WorkerQueueEntry(*void, *void)),

    pub fn WorkerQueueNode(comptime T: type, comptime U: type) type {
        return std.atomic.Queue(WorkerQueueEntry(T, U)).Node;
    }

    pub fn run(ctx: *WorkerContext) !void {
        // run all the loader funcs
        while (ctx.queue.get()) |work_node| {
            if (!work_node.data.loader(&work_node.data)) {
                return error.LoadError;
            }
        }
    }

    pub fn enqueue(self: WorkerContext, indata: anytype, outdata: anytype, loader: *const fn(*WorkerQueueEntry(@TypeOf(indata), @TypeOf(outdata))) bool) !void {
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
    }
};
