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

pub const WorkerContext = struct {
    queue: *std.atomic.Queue(WorkerQueueEntry(*void, *void)),
    total: usize = 0,

    pub fn WorkerQueueNode(comptime T: type, comptime U: type) type {
        return std.atomic.Queue(WorkerQueueEntry(T, U)).Node;
    }

    pub fn run(ctx: *WorkerContext, progress: *f32) anyerror!void {
        var prog: usize = 0;

        // run all the loader funcs
        while (ctx.queue.get()) |work_node| {
            if (!try work_node.data.loader(&work_node.data)) {
                return error.LoadError;
            }
            allocator.alloc.destroy(work_node);
            prog += 1;

            progress.* = @as(f32, @floatFromInt(prog)) / @as(f32, @floatFromInt(ctx.total));
        }

        progress.* = 1;

        ctx.total = 0;
    }

    pub fn enqueue(
        self: *WorkerContext,
        comptime T: type,
        comptime U: type,
        indata: T,
        outdata: U,
        loader: *const fn (*WorkerQueueEntry(T, U)) anyerror!bool,
    ) !void {
        const node = try allocator.alloc.create(WorkerQueueNode(T, U));

        node.* = .{
            .prev = undefined,
            .next = undefined,
            .data = .{
                .loader = loader,
                .indata = indata,
                .out = outdata,
            },
        };

        self.queue.put(@as(*WorkerQueueNode(*void, *void), @ptrCast(node)));
        self.total += 1;
    }
};
