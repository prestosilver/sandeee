const std = @import("std");

const util = @import("../util/mod.zig");
const system = @import("mod.zig");
const sandeee_data = @import("../data/mod.zig");

const storage = util.storage;
const allocator = util.allocator;

const VmManager = system.VmManager;
const Shell = system.Shell;
const files = system.files;

const strings = sandeee_data.strings;

// TODO: unhardcode
const DISK = "headless.eee";

const USE_POSIX = @import("builtin").os.tag == .linux;

pub fn write_console(stdout: std.fs.File.Writer, input: []const u8) !void {
    const text = try sandeee_data.strings.eeeCHToANSI(input);
    defer allocator.alloc.free(text);

    try stdout.writeAll(text);
}

pub var is_headless = false;

pub var input_mutex: std.Thread.Mutex = .{};
pub var input_queue = std.fifo.LinearFifo(u8, .Dynamic).init(allocator.alloc);

fn inputLoop() void {
    const stdin = std.io.getStdIn().reader();

    while (true) {
        var c = stdin.readByte() catch break;

        if (c == '\x7f')
            c = strings.UNDO[0];

        input_mutex.lock();
        defer input_mutex.unlock();

        input_queue.writeItem(c) catch break;
    }
}

pub fn main(cmd: []const u8, comptime exit_fail: bool, logging: ?std.fs.File) anyerror!void {
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

    _ = try std.Thread.spawn(.{}, inputLoop, .{});

    const diskpath = try storage.getContentPath("disks/headless.eee");
    defer diskpath.deinit();

    std.fs.cwd().access(diskpath.items, .{}) catch {
        try files.Folder.setupDisk(DISK, "");
    };

    try files.Folder.init(DISK);

    defer files.deinit();

    var main_shell = Shell{ .root = .home, .headless = true };

    const stdout_file = logging orelse std.io.getStdOut();
    const stdout = stdout_file.writer();

    const stdin_file = std.io.getStdIn();

    // set terminal attribs
    const original = if (USE_POSIX) try std.posix.tcgetattr(stdin_file.handle) else undefined;

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

    defer if (USE_POSIX)
        std.posix.tcsetattr(stdin_file.handle, .NOW, original) catch {};

    var input_buffer = std.ArrayList(u8).init(allocator.alloc);
    try input_buffer.appendSlice(cmd);

    _ = try write_console(stdout, strings.CLEAR ++ "Welcome To Sh" ++ strings.EEE ++ "l\n");

    var done = false;
    var got_input = false;

    while (!done) {
        VmManager.last_frame_time = 0.1;

        if (main_shell.vm != null) {
            try VmManager.instance.update();

            // setup vm data for update
            const result_data = try main_shell.getVMResult();
            if (result_data) |result|
                try write_console(stdout, result.data);

            if (main_shell.vm == null)
                try write_console(stdout, "\n");

            continue;
        }

        // print the prompt
        {
            const prompt = try main_shell.getPrompt();
            defer allocator.alloc.free(prompt);

            try write_console(stdout, strings.COLOR_WHITE);
            try write_console(stdout, prompt);
        }

        if (input_buffer.items.len == 0) {
            got_input = true;

            while (true) {
                const ch = blk: {
                    input_mutex.lock();
                    defer input_mutex.unlock();
                    break :blk input_queue.readItem();
                } orelse {
                    std.Thread.sleep(1000);
                    continue;
                };

                switch (ch) {
                    '\t' => {
                        continue;
                    },
                    '\r' => {
                        continue;
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
                            try stdout.print("\\X{X:02}", .{ch});
                            try input_buffer.append(ch);
                        } else {
                            try write_console(stdout, &.{ch});
                            try stdout.print("{c}", .{ch});
                            try input_buffer.append(ch);
                        }
                    },
                }
            }
        }

        var iter = std.mem.splitScalar(u8, input_buffer.items, '\n');

        const first = iter.next() orelse "";
        const rest = try allocator.alloc.dupe(u8, iter.rest());
        defer allocator.alloc.free(rest);

        const command = std.mem.trim(u8, first, &std.ascii.whitespace);

        if (command.len != 0) {
            if (!got_input)
                try stdout.print("{s}\n", .{command});

            const result = main_shell.run(command) catch |err| {
                try stdout.print("Error: {s}\n", .{@errorName(err)});
                try stdout.print("In {s}\n", .{command});

                if (exit_fail) return err;

                continue;
            };

            defer allocator.alloc.free(result.data);

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
    VmManager.vm_time = 1.0;
    VmManager.last_frame_time = 10.0;

    var logging = try std.fs.cwd().createFile("zig-out/test_output.md", .{ });
    defer logging.close();

    var start_cwd = try std.fs.cwd().openDir("tests", .{
        .iterate = true,
    });
    defer start_cwd.close();

    var iter = try start_cwd.walk(std.testing.allocator);
    defer iter.deinit();

    var err: ?anyerror!void = null;

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        _ = try logging.write("# ");
        _ = try logging.write(entry.path);
        _ = try logging.write("\n```\n");

        var file = try start_cwd.openFile(entry.path, .{});
        defer file.close();

        const conts = try file.readToEndAlloc(std.testing.allocator, 10000);
        defer std.testing.allocator.free(conts);

        var success = true;

        main(conts, true, logging) catch |res| {
            err = res;

            _ = try logging.write("```\n\n");

            _ = try logging.write(@errorName(res));
            _ = try logging.write("\n\n");
            success = false;
        };

        if (success) {
            _ = try logging.write("```\n\n");

            _ = try logging.write("Success!\n\n");
        }
    }

    if (err) |result_err| {
        return result_err;
    }
}
