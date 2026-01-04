const std = @import("std");
const builtin = @import("builtin");

const util = @import("../util.zig");

const allocator = util.allocator;

var log_file: ?std.fs.File = null;
var log_file_writer: std.fs.File.Writer = undefined;
var log_lock: std.Thread.Mutex = .{};

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

pub var stop_logs: bool = true;

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

    // Print the message to stderr, silently ignoring any errors
    if (@import("builtin").mode == .Debug) {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();

        std.fs.File.stderr().writeAll(color ++ prefix ++ format ++ "\x1b[m\n") catch {};
    }

    if (log_file) |_| {
        log_lock.lock();
        defer log_lock.unlock();

        log_file_writer.interface.print(prefix ++ format ++ "\n", args) catch return;
    }

    if (stop_logs)
        return;

    if (logs[last_log].data) |log_data|
        allocator.free(log_data);

    if (total_logs < HIST_LEN) {
        logs[last_log] = .{
            .level = level,
            .data = std.fmt.allocPrint(allocator, prefix ++ format ++ "\n", args) catch return,
        };

        last_log += 1;
        total_logs += 1;
    } else {
        logs[last_log] = .{
            .level = level,
            .data = std.fmt.allocPrint(allocator, prefix ++ format ++ "\n", args) catch return,
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

pub fn setLogFile(file: []const u8) !void {
    log_file = try std.fs.cwd().createFile(file, .{});
    log_file_writer = log_file.?.writer(&.{});

    stop_logs = false;
}

pub fn deinit() void {
    if (stop_logs) return;

    log_file.?.close();
    log_file = null;

    stop_logs = true;
    for (&logs) |*log_item| {
        if (log_item.data) |data|
            allocator.free(data);
        log_item.data = null;
    }
}
