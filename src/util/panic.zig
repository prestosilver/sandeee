const std = @import("std");
const builtin = @import("builtin");

const util = @import("../util.zig");
const sandeee_data = @import("../data.zig");

const strings = sandeee_data.strings;

// TODO: fix display in game, shouldnt conver to eeech
var panic_stage: u32 = 0;
var panicking = std.atomic.Value(u8).init(0);

pub fn log(msg: []const u8, first_trace_addr: ?usize) []const u8 {
    @branchHint(.cold);

    var alloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = alloc.allocator();

    var writer_alloc: std.Io.Writer.Allocating = .init(allocator);
    const writer = &writer_alloc.writer;

    // There is very similar logic to the following in `handleSegfault`.
    switch (panic_stage) {
        0 => {
            panic_stage = 1;
            _ = panicking.fetchAdd(1, .seq_cst);

            trace: {
                if (builtin.single_threaded) {
                    writer.print("panic: ", .{}) catch break :trace;
                } else {
                    const current_thread_id = std.Thread.getCurrentId();
                    writer.print("thread {d} panic: ", .{current_thread_id}) catch break :trace;
                }
                writer.print("{s}\n", .{msg}) catch break :trace;

                const debug_info = std.debug.getSelfDebugInfo() catch |err| {
                    writer.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch break :trace;
                    break :trace;
                };
                if (@errorReturnTrace()) |t| if (t.index > 0) {
                    writer.writeAll("error return context:\n") catch break :trace;
                    std.debug.writeStackTrace(t.*, writer, debug_info, .no_color) catch break :trace;
                    writer.writeAll("\nstack trace:\n") catch break :trace;
                };
                std.debug.writeCurrentStackTrace(
                    writer,
                    debug_info,
                    .no_color,
                    first_trace_addr orelse @returnAddress(),
                ) catch break :trace;
            }
        },
        1 => {
            panic_stage = 2;
            // A panic happened while trying to print a previous panic message.
            // We're still holding the mutex but that's fine as we're going to
            // call abort().
            std.fs.File.stderr().writeAll("aborting due to recursive panic :()\n") catch {};
        },
        else => {}, // Panicked while printing the recursive panic message.
    }

    return writer_alloc.toArrayList().items;
}
