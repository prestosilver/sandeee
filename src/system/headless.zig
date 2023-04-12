const std = @import("std");
const fm = @import("../util/files.zig");
const files = @import("files.zig");
const shell = @import("shell.zig");
const network = @import("network.zig");
const allocator = @import("../util/allocator.zig");

const DISK = "headless.eee";

pub fn headlessMain(cmd: ?[]const u8, comptime exitFail: bool) anyerror!void {
    var diskpath = fm.getContentPath("disks/headless.eee");
    defer diskpath.deinit();

    if (std.fs.cwd().access(diskpath.items, .{}) catch null == null) {
        try files.Folder.setupDisk(DISK);
    }

    if (!@import("builtin").is_test) {
        network.server = try network.Server.init();
        _ = try std.Thread.spawn(.{}, network.Server.serve, .{});
    }

    try files.Folder.init(DISK);

    var mainShell = shell.Shell{ .root = files.home };
    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut();
    var buffer: [512]u8 = undefined;

    _ = try stdout.write("Welcome To ShEEEl\n");

    var toRun = cmd;

    while (true) {
        if (mainShell.vm != null) {
            var result = try mainShell.updateVM();
            if (result != null) {
                _ = try stdout.write(result.?.data.items);
                result.?.data.deinit();
                _ = try stdout.write("\n");
            } else {
                _ = try stdout.write(mainShell.vm.?.out.items);
                mainShell.vm.?.out.clearAndFree();
            }

            continue;
        }

        var prompt = mainShell.getPrompt();

        _ = try stdout.write(prompt);

        allocator.alloc.free(prompt);

        var data: []const u8 = undefined;

        if (toRun != null) {
            var idx = std.mem.indexOf(u8, toRun.?, "\n");
            if (idx) |index| {
                data = toRun.?[0..index];
                toRun = toRun.?[index + 1 ..];
            } else {
                data = toRun.?;
                toRun = null;
            }
            _ = try stdout.write(data);
            _ = try stdout.write("\n");
        } else {
            data = try stdin.readUntilDelimiter(&buffer, '\n');
        }

        var command = std.mem.trim(u8, data, "\r\n ");
        if (std.mem.indexOf(u8, command, " ")) |idx| {
            command.len = idx;
        }

        var result = mainShell.run(command, data) catch |err| {
            const msg = @errorName(err);

            _ = try stdout.write("Error: ");
            _ = try stdout.write(msg);
            _ = try stdout.write("\n");

            if (exitFail) {
                return err;
            }
            continue;
        };

        if (result.exit) {
            break;
        } else {
            if (result.data.items.len != 0) {
                _ = try stdout.write(result.data.items);
                _ = try stdout.write("\n");
            }
        }

        result.data.deinit();
    }

    return;
}

test "Headless scripts" {
    var dir = try std.fs.cwd().openIterableDir("tests", .{});
    var start_cwd = try std.fs.cwd().openDir("tests", .{});

    var iter = dir.iterate();

    try std.process.changeCurDir("zig-out/bin/");

    while (try iter.next()) |path| {
        var file = try start_cwd.openFile(path.name, .{});

        var conts = try file.readToEndAlloc(std.testing.allocator, 1000000);
        defer std.testing.allocator.free(conts);

        try headlessMain(conts, true);
    }
}
