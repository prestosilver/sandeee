const std = @import("std");
const builtin = @import("builtin");
const allocator = @import("allocator.zig");

pub fn log() []const u8 {
    var result = allocator.alloc.alloc(u8, 0) catch return "";

    // Try to run a backtrace to get where the log message originated from
    if (!builtin.strip_debug_info) {
        const debug_info = std.debug.getSelfDebugInfo() catch return "";
        var address: usize = 0;
        if (builtin.os.tag == .windows) {
            var addr_buf: [4]usize = undefined;
            _ = std.os.windows.ntdll.RtlCaptureStackBackTrace(0, addr_buf.len, @ptrCast(**anyopaque, &addr_buf), null);
            // Windows seems to be one line off?
            address = if (addr_buf[3] == 0) addr_buf[3] else addr_buf[3] - 1;
        }
        var it = std.debug.StackIterator.init(null, null);
        _ = it.next(); // idc abt this & main
        _ = it.next();
        while (it.next()) |return_address| {
            address = if (return_address == 0) return_address else return_address - 1;
            const module = debug_info.getModuleForAddress(address - 1) catch return result;
            const symbol_info = module.getSymbolAtAddress(debug_info.allocator, address) catch return result;
            defer symbol_info.deinit(debug_info.allocator);
            const li = symbol_info.line_info.?;

            const index = std.mem.indexOf(u8, li.file_name, "sandeee/") orelse 0;
            // Good backtrace, print with the source location of the log
            var adds = std.fmt.allocPrint(allocator.alloc, "{s}:{d}\n", .{ li.file_name[index..], li.line }) catch return result;
            defer allocator.alloc.free(adds);
            var start = result.len;
            result = allocator.alloc.realloc(result, result.len + adds.len) catch return result;
            std.mem.copy(u8, result[start..], adds);
        }

        return result;
    }

    // Backtrace failed somehow, just print the message
    return std.fmt.allocPrint(allocator.alloc, "Debug Info Missing\n", .{}) catch return result;
}
