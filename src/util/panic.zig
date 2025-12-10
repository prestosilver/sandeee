const std = @import("std");
const builtin = @import("builtin");

const util = @import("mod.zig");
const sandeee_data = @import("../data/mod.zig");

const allocator = util.allocator;

const strings = sandeee_data.strings;

// TODO: fix display in game, shouldnt conver to eeech

pub fn log(trace: ?*std.builtin.StackTrace) []const u8 {
    // Try to run a backtrace to get where the log message originated from
    if (builtin.strip_debug_info) return strings.NO_STACKTRACE_MESSAGE;
    const stack_trace = trace orelse return strings.NO_STACKTRACE_MESSAGE;
    const debug_info = std.debug.getSelfDebugInfo() catch return strings.NO_STACKTRACE_MESSAGE;

    var result: []u8 = &.{};
    var frame_index: usize = 0;
    var frames_left: usize = @min(stack_trace.index, stack_trace.instruction_addresses.len);
    while (frames_left != 0) : ({
        frames_left -= 1;
        frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
    }) {
        const return_address = stack_trace.instruction_addresses[frame_index];

        const module = debug_info.getModuleForAddress(return_address - 1) catch |err| {
            std.debug.print("error: {s}\n", .{@errorName(err)});
            continue;
        };
        const symbol_info = module.getSymbolAtAddress(debug_info.allocator, return_address - 1) catch continue;
        const li = symbol_info.source_location.?;

        const index = std.mem.indexOf(u8, li.file_name, "sandeee/") orelse 0;
        // Good backtrace, print with the source location of the log
        const adds = std.fmt.allocPrint(allocator.alloc, "{s}:{d}\n", .{ li.file_name[index..], li.line }) catch return result;
        defer allocator.alloc.free(adds);
        const start = result.len;
        result = allocator.alloc.realloc(result, result.len + adds.len) catch return result;
        @memcpy(result[start..], adds);
    }

    return result;
}
