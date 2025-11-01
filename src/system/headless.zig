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

const DISK = "headless.eee";

const USE_POSIX = @import("builtin").os.tag == .linux;

pub fn toANSI(input: []const u8) ![]const u8 {
    const buffer_len = std.mem.replacementSize(u8, input, strings.E, "Ⲉ");
    const buffer = try allocator.alloc.alloc(u8, buffer_len);
    _ = std.mem.replace(u8, input, strings.E, "Ⲉ", buffer);

    return buffer;
}

pub fn headlessMain(cmd: []const u8, comptime exit_fail: bool, logging: ?std.fs.File) anyerror!void {
    const diskpath = try storage.getContentPath("disks/headless.eee");
    defer diskpath.deinit();

    std.fs.cwd().access(diskpath.items, .{}) catch {
        try files.Folder.setupDisk(DISK, "");
    };

    try files.Folder.init(DISK);

    defer files.deinit();

    var main_shell = Shell{ .root = .home, .headless = true };

    const stdin_file = std.io.getStdIn();
    const stdin = stdin_file.reader();
    const stdout_file = logging orelse std.io.getStdOut();
    const stdout = stdout_file.writer();

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

    _ = try stdout.write("\x1b[2J\x1b[HWelcome To ShⲈⲈⲈl\n");

    var done = false;

    while (!done) {
        if (main_shell.vm != null) {
            // setup vm data for update
            const result_data = try main_shell.getVMResult();
            if (result_data) |result| {
                const output = try toANSI(result.data);
                defer allocator.alloc.free(output);

                _ = try stdout.write(output);

                allocator.alloc.free(result.data);
            }

            try VmManager.instance.update();

            if (main_shell.vm == null)
                _ = try stdout.write("\r\n");

            continue;
        }

        // print the prompt
        {
            const prompt = try main_shell.getPrompt();
            defer allocator.alloc.free(prompt);

            _ = try stdout.write(prompt);
        }

        if (input_buffer.items.len <= 0) {
            while (stdin.readByte() catch blk: {
                done = true;
                break :blk null;
            }) |ch| {
                switch (ch) {
                    '\n' => {
                        try stdout.print("\r\n", .{});
                        break;
                    },
                    '\x1b' => {
                        try stdout.print("^[", .{});
                        try input_buffer.append(ch);
                    },
                    '\x7F' => {
                        if (input_buffer.pop()) |_|
                            try stdout.print("\x1b[D \x1b[D", .{});
                    },
                    else => {
                        if (std.ascii.isControl(ch)) {
                            try stdout.print("\\x{x}", .{ch});
                            try input_buffer.append(ch);
                        } else {
                            try stdout.print("{c}", .{ch});
                            try input_buffer.append(ch);
                        }
                    },
                }
            }
        }

        var iter = std.mem.splitScalar(u8, input_buffer.items, '\n');

        while (iter.next()) |data| {
            const command = std.mem.trim(u8, data, "\r\n ");

            const result = main_shell.run(command) catch |err| {
                try stdout.print("Error: {s}\r\n", .{@errorName(err)});

                if (exit_fail) return err;

                continue;
            };

            defer allocator.alloc.free(result.data);

            if (result.data.len != 0) {
                const output = try toANSI(result.data);
                defer allocator.alloc.free(output);

                _ = try stdout.write(output);
                if (output[output.len - 1] != '\n')
                    _ = try stdout.write("\r\n");
            }

            if (result.clear)
                _ = try stdout.write("\x1b[2J\x1b[H");

            if (result.exit)
                done = true;
        }

        input_buffer.clearAndFree();
    }

    return;
}

test "Headless scripts" {
    VmManager.init();
    defer VmManager.instance.deinit();

    VmManager.vm_time = 1.0;
    VmManager.last_frame_time = 10.0;

    var logging = try std.fs.cwd().createFile("zig-out/test_output.md", .{});
    defer logging.close();

    var start_cwd = try std.fs.cwd().openDir("tests", .{
        .iterate = true,
    });

    var iter = try start_cwd.walk(std.testing.allocator);
    defer iter.deinit();

    try std.process.changeCurDir("zig-out/bin/");

    var err: ?anyerror!void = null;

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        _ = try logging.write("# ");
        _ = try logging.write(entry.path);
        _ = try logging.write("\n```\n");

        var file = try start_cwd.openFile(entry.path, .{});

        const conts = try file.readToEndAlloc(std.testing.allocator, 10000);
        defer std.testing.allocator.free(conts);

        var success = true;

        headlessMain(conts, true, logging) catch |res| {
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
