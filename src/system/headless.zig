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

const root_prefix = if (builtin.is_test)
    "zig-out/bin/"
else
    "";

pub fn write_console(stdout: *std.fs.File.Writer, input: []const u8) !void {
    const text = try sandeee_data.strings.eeeCHToANSI(input);
    defer allocator.free(text);

    try stdout.interface.writeAll(text);
}

pub var is_headless = false;

pub var input_mutex: std.Thread.Mutex = .{};
pub var input_queue: std.array_list.Managed(u8) = .init(allocator);
pub var last_input: usize = 0;
pub var last_processed_input: usize = 0;
pub var disk: []const u8 = "headless.eee";

pub fn pushInput(input: u8) !void {
    input_mutex.lock();
    defer input_mutex.unlock();

    try input_queue.append(input);
}

pub fn popInput() ?u8 {
    input_mutex.lock();
    defer input_mutex.unlock();

    return input_queue.pop();
}

fn inputLoop() void {
    var stdin_file = std.fs.File.stdin();
    var t: [1]u8 = undefined;

    while (true) {
        const c = stdin_file.read(&t) catch break;
        if (c == 0) {
            std.Thread.sleep(100);
            continue;
        }

        if (t[0] == '\x7f')
            t[0] = strings.UNDO[0];

        pushInput(t[0]) catch @panic("bad input");
    }
}

pub fn main(cmd: []const u8, comptime exit_fail: bool, logging: ?*std.fs.File.Writer) anyerror!void {
    if (!USE_POSIX) {
        const c = @cImport({
            @cInclude("windows.h");
            @cInclude("winuser.h"); // for ShowWindow and GetConsoleWindow
        });

        // Try to attach to parent console; if that fails, allocate a new one.
        if (c.AttachConsole(c.ATTACH_PARENT_PROCESS) == 0) {
            _ = c.AllocConsole();
        }

        // Enable ANSI and UTF-8
        const STD_OUTPUT_HANDLE: c.DWORD = @bitCast(@as(c_long, -11));
        const STD_INPUT_HANDLE: c.DWORD = @bitCast(@as(c_long, -10));

        const out_handle = c.GetStdHandle(STD_OUTPUT_HANDLE);
        const in_handle = c.GetStdHandle(STD_INPUT_HANDLE);

        var mode: c.DWORD = 0;
        if (c.GetConsoleMode(out_handle, &mode) != 0) {
            // Enable virtual terminal sequences (ANSI escapes)
            const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
            const DISABLE_NEWLINE_AUTO_RETURN = 0x0008;
            _ = c.SetConsoleMode(out_handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING | DISABLE_NEWLINE_AUTO_RETURN);
        }

        if (c.GetConsoleMode(in_handle, &mode) != 0) {
            const ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200;
            const ENABLE_LINE_INPUT = 0x0002;
            const ENABLE_ECHO_INPUT = 0x0004;

            // disable line buffering and echo
            _ = c.SetConsoleMode(in_handle, (mode | ENABLE_VIRTUAL_TERMINAL_INPUT) &
                ~@as(c.DWORD, (ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)));
        }

        // Set UTF-8 code pages
        const CP_UTF8: c.UINT = 65001;
        _ = c.SetConsoleOutputCP(CP_UTF8);
        _ = c.SetConsoleCP(CP_UTF8);

        _ = c.SetConsoleTitleA("SandEEE Console");
        _ = c.ShowWindow(c.GetConsoleWindow(), c.SW_SHOW);
    }

    // no input thread on test builds
    if (!builtin.is_test)
        _ = try std.Thread.spawn(.{}, inputLoop, .{});

    const alloc_path = try std.fmt.allocPrint(allocator, root_prefix ++ "disks/{s}", .{disk});
    defer allocator.free(alloc_path);

    const diskpath = try storage.getContentPath(alloc_path);
    defer diskpath.deinit();

    std.fs.cwd().access(diskpath.items, .{}) catch {
        try files.Folder.setupDisk(disk, "");
    };

    try files.Folder.init(disk);

    defer files.deinit();

    var main_shell = Shell{ .root = .home, .headless = true };
    defer main_shell.deinit();

    var stdout_file: std.fs.File = .stdout();
    var stdout_file_writer = stdout_file.writer(&.{});

    const stdout: *std.fs.File.Writer = logging orelse &stdout_file_writer;

    const stdin_file: std.fs.File = .stdin();

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
                    std.Thread.sleep(100);
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
    std.fs.cwd().access("zig-out/bin/disks", .{}) catch
        std.fs.cwd().makeDir("zig-out/bin/disks") catch
        @panic("Cannot make disks directory.");

    Vm.Manager.vm_time = 1.0;
    Vm.Manager.last_frame_time = 10.0;

    var logging_file = try std.fs.cwd().createFile("zig-out/test_output.md", .{});
    defer logging_file.close();

    var logging = logging_file.writer(&.{});

    var start_cwd = try std.fs.cwd().openDir("tests", .{
        .iterate = true,
    });
    defer start_cwd.close();

    var iter = try start_cwd.walk(std.testing.allocator);
    defer iter.deinit();

    var err: ?anyerror = null;

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        try Vm.Manager.instance.runGc();

        std.fs.cwd().deleteFile("zig-out/bin/disks/headless.eee") catch {};

        // deinit vm manager

        try logging.interface.writeAll("# ");
        try logging.interface.writeAll(entry.path);
        try logging.interface.writeAll("\n```\n");

        var file = try start_cwd.openFile(entry.path, .{});
        defer file.close();

        var reader = file.reader(&.{});

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
