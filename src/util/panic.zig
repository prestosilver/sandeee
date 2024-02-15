const std = @import("std");
const builtin = @import("builtin");
const allocator = @import("allocator.zig");

const NO_INFO: []const u8 = "Stacktrace unavailable\n";

pub fn log() []const u8 {
    // Try to run a backtrace to get where the log message originated from
    if (builtin.mode != .Debug) return NO_INFO;

    var result = allocator.alloc.alloc(u8, 0) catch return NO_INFO;
    const debug_info = std.debug.getSelfDebugInfo() catch return NO_INFO;
    var address: usize = 0;
    if (builtin.os.tag == .windows) {
        return NO_INFO;
    }
    var it = std.debug.StackIterator.init(null, null);
    while (it.next()) |return_address| {
        address = if (return_address == 0) return_address else return_address - 1;
        const module = debug_info.getModuleForAddress(address - 1) catch return result;
        const symbol_info = module.getSymbolAtAddress(debug_info.allocator, address) catch return result;
        defer symbol_info.deinit(debug_info.allocator);
        const li = symbol_info.line_info.?;

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
