const std = @import("std");
const allocator = @import("allocator.zig");

pub var log_file: ?std.fs.File = null;

pub const log = std.log.scoped(.SandEEE);

const LogData = struct {
    level: std.log.Level,
    data: []const u8,
};

const HIST_LEN = 1000;
pub var logs: [HIST_LEN]LogData = undefined;
pub var last_log: usize = 0;
pub var total_logs: usize = 0;

pub var stop_logs: bool = false;

pub fn sandEEELogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@import("builtin").is_test) {
        return;
    }

    const scope_prefix = "(" ++ switch (scope) {
        .SandEEE, .Steam, std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
            @tagName(scope)
        else
            return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    const color = switch (level) {
        .err => "\x1b[31m",
        .warn => "\x1b[93m",
        .info => "\x1b[97m",
        .debug => "\x1b[90m",
    };

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    // Print the message to stderr, silently ignoring any errors
    if (@import("builtin").mode == .Debug) {
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(color ++ prefix ++ format ++ "\x1b[m\n", args) catch return;
    }

    if (log_file) |file| {
        const writer = file.writer();
        nosuspend writer.print(prefix ++ format ++ "\n", args) catch return;
    }

    if (stop_logs)
        return;

    if (total_logs < HIST_LEN) {
        logs[last_log] = .{
            .level = level,
            .data = std.fmt.allocPrint(allocator.alloc, prefix ++ format ++ "\n", args) catch return,
        };

        last_log += 1;
        total_logs += 1;
    } else {
        allocator.alloc.free(logs[last_log].data);

        logs[last_log] = .{
            .level = level,
            .data = std.fmt.allocPrint(allocator.alloc, prefix ++ format ++ "\n", args) catch return,
        };

        last_log += 1;
    }

    last_log = last_log % HIST_LEN;
}

pub fn getLogs() [2][]const LogData {
    if (total_logs < HIST_LEN) {
        return .{ logs[0..last_log], &.{} };
    } else {
        return .{ logs[last_log..], logs[0..last_log] };
    }
}
