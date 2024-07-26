const std = @import("std");
const fm = @import("../util/files.zig");
const files = @import("files.zig");
const shell = @import("shell.zig");
const allocator = @import("../util/allocator.zig");
const vmManager = @import("../system/vmmanager.zig");

const DISK = "headless.eee";

pub fn headlessMain(cmd: ?[]const u8, comptime exitFail: bool, logging: ?std.fs.File) anyerror!void {
    const diskpath = try fm.getContentPath("disks/headless.eee");
    defer diskpath.deinit();

    std.fs.cwd().access(diskpath.items, .{}) catch {
        try files.Folder.setupDisk(DISK, "");
    };

    try files.Folder.init(DISK);

    defer files.deinit();

    var mainShell = shell.Shell{ .root = files.home };

    const stdin = std.io.getStdIn().reader();
    const stdout = logging orelse std.io.getStdOut();
    var buffer: [512]u8 = undefined;

    _ = try stdout.write("Welcome To ShEEEl\n");

    var toRun = cmd;

    while (true) {
        if (mainShell.vm != null) {
            // setup vm data for update
            const result_data = try mainShell.getVMResult();
            if (result_data) |result| {
                _ = try stdout.write(result.data);
                allocator.alloc.free(result.data);
            } else {
                // TODO: fix writing
                _ = try stdout.write("");
            }

            try vmManager.VMManager.instance.update();

            if (mainShell.vm == null) {
                _ = try stdout.write("\n");
            }

            continue;
        }

        const prompt = mainShell.getPrompt();

        _ = try stdout.write(prompt);

        allocator.alloc.free(prompt);

        var data: []const u8 = undefined;

        if (toRun) |command| {
            const idx = std.mem.indexOf(u8, command, "\n");
            if (idx) |index| {
                data = command[0..index];
                toRun = command[index + 1 ..];
            } else {
                data = command;
                toRun = null;
            }
            _ = try stdout.write(data);
            _ = try stdout.write("\n");
        } else {
            data = try stdin.readUntilDelimiter(&buffer, '\n');
        }

        const command = std.mem.trim(u8, data, "\r\n ");

        const result = mainShell.run(command) catch |err| {
            const msg = @errorName(err);

            _ = try stdout.write("Error: ");
            _ = try stdout.write(msg);
            _ = try stdout.write("\n");

            if (exitFail) {
                return err;
            }

            continue;
        };

        defer allocator.alloc.free(result.data);

        if (result.exit) {
            break;
        } else {
            if (result.data.len != 0) {
                _ = try stdout.write(result.data);
                if (result.data[result.data.len - 1] != '\n')
                    _ = try stdout.write("\n");
            }
        }
    }

    return;
}

test "Headless scripts" {
    vmManager.VMManager.init();
    defer vmManager.VMManager.deinit();

    vmManager.VMManager.vm_time = 1.0;
    vmManager.VMManager.last_frame_time = 10.0;

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
