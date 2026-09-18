const std = @import("std");
const builtin = @import("builtin");

const util = @import("../util.zig");
const system = @import("../system.zig");
const sandeee_data = @import("../data.zig");

const storage = util.storage;
const allocator = util.allocator;

const Shell = system.Shell;
const Vm = system.Vm;
const files = system.files;

const strings = sandeee_data.strings;

const USE_POSIX = builtin.os.tag == .linux;

// TODO: Should not use std.Io.File.Writer here rather Std.Io.Terminal

const root_prefix = if (builtin.is_test)
    "zig-out/bin/"
else
    "";

pub fn write_console(stdout: *std.Io.File.Writer, input: []const u8) !void {
    const text = try sandeee_data.strings.encode(input, .eeech, .ansi);
    defer allocator.free(text);

    try stdout.interface.writeAll(text);
}

pub var is_headless = false;

pub var input_mutex: std.Io.Mutex = .init;
pub var input_queue: std.array_list.Managed(u8) = .init(allocator);
pub var last_input: usize = 0;
pub var last_processed_input: usize = 0;
pub var disk: []const u8 = "headless.eee";

pub fn pushInput(input: u8) !void {
    try input_mutex.lock(util.io);
    defer input_mutex.unlock(util.io);

    try input_queue.append(input);
}

pub fn popInput() ?u8 {
    input_mutex.lock(util.io) catch unreachable;
    defer input_mutex.unlock(util.io);

    return input_queue.pop();
}

fn inputLoop() noreturn {
    var stdin_file: std.Io.File = .stdin();
    var t: [1]u8 = undefined;

    var reader = stdin_file.reader(util.io, &.{});

    while (true) {
        const c = reader.interface.takeByte() catch unreachable;
        if (c == 0) {
            std.Io.sleep(util.io, .fromMilliseconds(100), .real) catch unreachable;
            continue;
        }

        if (t[0] == '\x7f')
            t[0] = strings.UNDO[0];

        pushInput(t[0]) catch @panic("bad input");
    }
}

pub fn main(cmd: []const u8, comptime exit_fail: bool, logging: ?*std.Io.File.Writer) anyerror!void {
    if (!USE_POSIX) {
        const windows = @import("win32");

        // Try to attach to parent console; if that fails, allocate a new one.
        if (windows.kernel32.AttachConsole(windows.system.console.ATTACH_PARENT_PROCESS) == 0) {
            _ = windows.kernel32.AllocConsole();
        }

        // Enable ANSI and UTF-8
        const out_handle = windows.kernel32.GetStdHandle(windows.system.console.STD_OUTPUT_HANDLE);
        const in_handle = windows.kernel32.GetStdHandle(windows.system.console.STD_INPUT_HANDLE);

        var mode: windows.system.console.CONSOLE_MODE = undefined;
        if (windows.kernel32.GetConsoleMode(out_handle, &mode) != 0) {
            mode.ENABLE_ECHO_INPUT = 1;
            mode.ENABLE_WINDOW_INPUT = 1;

            _ = windows.kernel32.SetConsoleMode(out_handle, mode);
        }

        if (windows.kernel32.GetConsoleMode(in_handle, &mode) != 0) {
            mode.ENABLE_VIRTUAL_TERMINAL_INPUT = 1;
            mode.ENABLE_LINE_INPUT = 0;
            mode.ENABLE_ECHO_INPUT = 0;

            // disable line buffering and echo
            _ = windows.kernel32.SetConsoleMode(in_handle, mode);
        }

        // Set UTF-8 code pages
        const CP_UTF8: u32 = 65001;
        _ = windows.kernel32.SetConsoleOutputCP(CP_UTF8);
        _ = windows.kernel32.SetConsoleCP(CP_UTF8);

        _ = windows.kernel32.SetConsoleTitleA("SandEEE Console");
        _ = windows.user32.ShowWindow(windows.kernel32.GetConsoleWindow(), windows.ui.windows_and_messaging.SW_SHOW);
    }

    // no input thread on test builds
    if (!builtin.is_test)
        _ = try std.Thread.spawn(.{}, inputLoop, .{});

    const alloc_path = try std.fmt.allocPrint(allocator, root_prefix ++ "disks/{s}", .{disk});
    defer allocator.free(alloc_path);

    const diskpath = try storage.getContentPath(alloc_path);
    defer diskpath.deinit();

    std.Io.Dir.cwd().access(util.io, diskpath.items, .{}) catch {
        try files.Folder.setupDisk(disk, "");
    };

    try files.Folder.init(disk);

    defer files.deinit();

    var main_shell = Shell{ .root = .home, .headless = true };
    defer main_shell.deinit();

    var stdout_file: std.Io.File = .stdout();
    var stdout_file_writer = stdout_file.writer(util.io, &.{});

    const stdout: *std.Io.File.Writer = logging orelse &stdout_file_writer;

    const stdin_file: std.Io.File = .stdin();

    const original = if (USE_POSIX and !builtin.is_test) try std.posix.tcgetattr(stdin_file.handle) else undefined;
    defer if (USE_POSIX and !builtin.is_test)
        std.posix.tcsetattr(stdin_file.handle, .NOW, original) catch {};

    if (!builtin.is_test) {
        // set terminal attribs

        if (USE_POSIX) {
            var raw = original;

            if (USE_POSIX) {
                raw.lflag.ECHO = false;
                raw.lflag.ICANON = false;

                raw.cc[@intFromEnum(std.posix.system.V.TIME)] = 0;
                raw.cc[@intFromEnum(std.posix.system.V.MIN)] = 1;
            }

            try std.posix.tcsetattr(stdin_file.handle, .NOW, raw);
        }
    }

    var input_buffer = std.array_list.Managed(u8).init(allocator);
    try input_buffer.appendSlice(cmd);
    defer input_buffer.clearAndFree();

    try write_console(stdout, strings.CLEAR ++ "Welcome To Sh" ++ strings.EEE ++ "l\n");

    var done = false;
    var got_input = false;

    while (!done) {
        Vm.Manager.last_frame_time = 0.1;

        if (main_shell.vm != null) {
            try Vm.Manager.instance.update();

            // setup vm data for update
            const result_data = try main_shell.getVMResult();
            if (result_data) |result| {
                try write_console(stdout, result.data);
                result.deinit();

                if (main_shell.vm == null)
                    try write_console(stdout, "\n");

                if (result.failure)
                    return error.VMError;
            }

            if (main_shell.vm == null)
                try write_console(stdout, "\n");

            if (result_data) |result|
                if (result.failure)
                    return error.VMError;

            continue;
        }

        // print the prompt
        {
            const prompt = try main_shell.getPrompt();
            defer allocator.free(prompt);

            try write_console(stdout, strings.COLOR_WHITE);
            try write_console(stdout, prompt);
        }

        if (input_buffer.items.len == 0) {
            got_input = true;

            while (true) {
                const ch = blk: {
                    break :blk popInput();
                } orelse {
                    try std.Io.sleep(util.io, .fromMilliseconds(100), .real);
                    continue;
                };

                switch (ch) {
                    '\t' => {
                        continue;
                    },
                    '\r' => {
                        try write_console(stdout, "\n");
                        break;
                    },
                    '\n' => {
                        try write_console(stdout, "\n");
                        break;
                    },
                    '\x1b' => {
                        try write_console(stdout, "\x1b");
                        try input_buffer.append(ch);
                    },
                    '\x08' => {
                        if (input_buffer.pop()) |_|
                            try write_console(stdout, strings.UNDO);
                    },
                    else => {
                        if (std.ascii.isControl(ch)) {
                            try stdout.interface.print("\\X{X:02}", .{ch});
                            try input_buffer.append(ch);
                        } else {
                            try write_console(stdout, &.{ch});
                            try stdout.interface.print("{c}", .{ch});
                            try input_buffer.append(ch);
                        }
                    },
                }
            }
        }

        var iter = std.mem.splitScalar(u8, input_buffer.items, '\n');

        const first = iter.next() orelse "";
        const rest = try allocator.dupe(u8, iter.rest());
        defer allocator.free(rest);

        const command = std.mem.trim(u8, first, &std.ascii.whitespace);

        if (command.len != 0) {
            if (!got_input)
                try stdout.interface.print("{s}\n", .{command});

            const result = main_shell.run(command) catch |err| {
                try stdout.interface.print("Error: {s}\n", .{@errorName(err)});
                try stdout.interface.print("In {s}\n", .{command});

                if (exit_fail) return err;

                continue;
            };

            defer allocator.free(result.data);

            if (result.data.len != 0) {
                try write_console(stdout, result.data);

                if (result.data[result.data.len - 1] != '\n')
                    try write_console(stdout, "\n");
            }

            if (result.clear)
                try write_console(stdout, strings.CLEAR);

            if (result.exit)
                done = true;
        }

        input_buffer.clearAndFree();
        try input_buffer.appendSlice(rest);
    }

    return;
}

test "Headless scripts" {
    std.Io.Dir.cwd().access(std.testing.io, "zig-out/bin/disks", .{}) catch
        std.Io.Dir.cwd().createDir(std.testing.io, "zig-out/bin/disks", .default_dir) catch
        @panic("Cannot make disks directory.");

    Vm.Manager.vm_time = 1.0;
    Vm.Manager.last_frame_time = 10.0;

    var logging_file = try std.Io.Dir.cwd().createFile(std.testing.io, "zig-out/test_output.md", .{});
    defer logging_file.close(std.testing.io);

    var logging = logging_file.writer(std.testing.io, &.{});

    var start_cwd = try std.Io.Dir.cwd().openDir(std.testing.io, "tests", .{
        .iterate = true,
    });
    defer start_cwd.close(std.testing.io);

    var iter = try start_cwd.walk(std.testing.allocator);
    defer iter.deinit();

    var err: ?anyerror = null;

    while (try iter.next(std.testing.io)) |entry| {
        if (entry.kind != .file) continue;

        try Vm.Manager.instance.runGc();

        std.Io.Dir.cwd().deleteFile(std.testing.io, "zig-out/bin/disks/headless.eee") catch {};

        // deinit vm manager

        try logging.interface.writeAll("# ");
        try logging.interface.writeAll(entry.path);
        try logging.interface.writeAll("\n```\n");

        var file = try start_cwd.openFile(std.testing.io, entry.path, .{});
        defer file.close(std.testing.io);

        var reader = file.reader(std.testing.io, &.{});

        const conts = try reader.interface.allocRemaining(std.testing.allocator, .unlimited);
        defer std.testing.allocator.free(conts);

        var success = true;

        main(conts, true, &logging) catch |res| {
            err = res;

            try logging.interface.writeAll("```\n\n");
            try logging.interface.writeAll(@errorName(res));
            try logging.interface.writeAll("\n\n");
            success = false;
        };

        if (success) {
            try logging.interface.writeAll("```\n\n");
            try logging.interface.writeAll("Success!\n\n");
        }

        try Vm.Manager.instance.runGc();
    }

    try Vm.Manager.instance.runGc();
    Vm.Manager.instance.deinit();

    if (err) |result_err| {
        return result_err;
    }
}
