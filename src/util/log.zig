// TODO: new imports
const std = @import("std");
const allocator = @import("allocator.zig");
const builtin = @import("builtin");

pub var log_file: ?std.fs.File = null;

pub const log = std.log.scoped(.SandEEE);

// TODO: unhardcode
const HIST_LEN = 1000;

const LogData = struct {
    level: std.log.Level = .debug,
    data: ?[]const u8 = null,
};

pub var logs: [HIST_LEN]LogData = .{LogData{}} ** HIST_LEN;
pub var last_log: usize = 0;
pub var total_logs: usize = 0;

pub var stop_logs: bool = false;

pub fn sandEEELogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (builtin.is_test) {
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
    if (builtin.mode == .Debug) {
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(color ++ prefix ++ format ++ "\x1b[m\n", args) catch return;
    }

    if (log_file) |file| {
        const writer = file.writer();
        nosuspend writer.print(prefix ++ format ++ "\n", args) catch return;
    }

    if (stop_logs)
        return;

    if (logs[last_log].data) |log_data|
        allocator.alloc.free(log_data);

    if (total_logs < HIST_LEN) {
        logs[last_log] = .{
            .level = level,
            .data = std.fmt.allocPrint(allocator.alloc, prefix ++ format ++ "\n", args) catch return,
        };

        last_log += 1;
        total_logs += 1;
    } else {
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

pub fn deinit() void {
    if (stop_logs) return;

    stop_logs = true;
    for (&logs) |*log_item| {
        if (log_item.data) |data|
            allocator.alloc.free(data);
        log_item.data = null;
    }
}
