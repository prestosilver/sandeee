const std = @import("std");
const builtin = @import("builtin");
const allocator = @import("allocator.zig");

const NO_INFO: []const u8 = "Stacktrace Unavailable\n";

pub fn log(trace: ?*std.builtin.StackTrace) []const u8 {
    // Try to run a backtrace to get where the log message originated from
    if (builtin.strip_debug_info) return NO_INFO;
    const stack_trace = trace orelse return NO_INFO;
    const debug_info = std.debug.getSelfDebugInfo() catch return NO_INFO;

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
    // var result: []u8 = &.{};
    // const debug_info = std.debug.getSelfDebugInfo() catch return NO_INFO;
    // if (builtin.os.tag == .windows) {
    //     for (debug_info.modules.items) |m| {
    //         std.debug.print("module: {s}\t{x:0>16}-{x:0>16}\n", .{ m.name, m.base_address, m.base_address + m.size });
    //     }

    //     var context: std.debug.ThreadContext = undefined;
    //     std.debug.assert(std.debug.getContext(&context));
    //     var addr_buf: [1024]usize = undefined;
    //     const n = std.debug.walkStackWindows(addr_buf[0..], &context);
    //     const addrs = addr_buf[0..n];
    //     for (addrs) |return_address| {
    //         std.debug.print("trace: {x:0>16}\n", .{return_address});
    //         const module = debug_info.getModuleForAddress(return_address - 1) catch |err| {
    //             std.debug.print("error: {s}\n", .{@errorName(err)});
    //             continue;
    //         };

    //         std.debug.print("good module\n", .{});

    //         const symbol_info = module.getSymbolAtAddress(debug_info.allocator, return_address - 1) catch continue;
    //         const li = symbol_info.source_location.?;

    //         const index = std.mem.indexOf(u8, li.file_name, "sandeee/") orelse 0;
    //         // Good backtrace, print with the source location of the log
    //         const adds = std.fmt.allocPrint(allocator.alloc, "{s}:{d}\n", .{ li.file_name[index..], li.line }) catch return result;
    //         defer allocator.alloc.free(adds);
    //         const start = result.len;
    //         result = allocator.alloc.realloc(result, result.len + adds.len) catch return result;
    //         @memcpy(result[start..], adds);
    //     }

    //     return result;
    // } else {
    //     var address: usize = 0;
    //     var it = std.debug.StackIterator.init(null, null);
    //     while (it.next()) |return_address| {
    //         address = if (return_address == 0) return_address else return_address - 1;
    //         const module = debug_info.getModuleForAddress(address - 1) catch return result;
    //         const symbol_info = module.getSymbolAtAddress(debug_info.allocator, address) catch return result;
    //         const li = symbol_info.source_location.?;

    //         const index = std.mem.indexOf(u8, li.file_name, "sandeee/") orelse 0;
    //         // Good backtrace, print with the source location of the log
    //         const adds = std.fmt.allocPrint(allocator.alloc, "{s}:{d}\n", .{ li.file_name[index..], li.line }) catch return result;
    //         defer allocator.alloc.free(adds);
    //         const start = result.len;
    //         result = allocator.alloc.realloc(result, result.len + adds.len) catch return result;
    //         @memcpy(result[start..], adds);
    //     }

    //     return result;
    // }
}
