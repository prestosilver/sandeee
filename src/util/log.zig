const std = @import("std");

pub var logFile: ?std.fs.File = null;

pub const log = std.log.scoped(.SandEEE);

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
        .info => "\x1b[90m",
        .debug => "\x1b[37m",
    };

    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();

    // Print the message to stderr, silently ignoring any errors
    if (@import("builtin").mode == .Debug) {
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(color ++ prefix ++ format ++ "\x1b[m\n", args) catch return;
    }

    if (logFile) |file| {
        const writer = file.writer();
        nosuspend writer.print(prefix ++ format ++ "\n", args) catch return;
    }
}
