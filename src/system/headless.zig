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

    defer files.deinit();

    var mainShell = shell.Shell{ .root = files.home };

    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut();
    var buffer: [512]u8 = undefined;

    if (!exitFail)
        _ = try stdout.write("Welcome To ShEEEl\n");

    var toRun = cmd;

    while (true) {
        if (mainShell.vm != null) {
            var result = try mainShell.updateVM();
            if (result != null) {
                if (!exitFail)
                    _ = try stdout.write(result.?.data.items);
                result.?.data.deinit();
                if (!exitFail)
                    _ = try stdout.write("\n");
            } else {
                if (!exitFail)
                    _ = try stdout.write(mainShell.vm.?.out.items);
                mainShell.vm.?.out.clearAndFree();
            }

            continue;
        }

        var prompt = mainShell.getPrompt();

        if (!exitFail)
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
            if (!exitFail)
                _ = try stdout.write(data);
            if (!exitFail)
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

            if (exitFail) {
                return err;
            }

            _ = try stdout.write("Error: ");
            _ = try stdout.write(msg);
            _ = try stdout.write("\n");
            continue;
        };

        if (result.exit) {
            break;
        } else {
            if (result.data.items.len != 0) {
                if (!exitFail) {
                    _ = try stdout.write(result.data.items);
                    _ = try stdout.write("\n");
                }
            }
        }

        result.data.deinit();
    }

    return;
}

test "Headless scripts" {
    var dir = try std.fs.cwd().openIterableDir("/home/john/doc/rep/github.com/sandeee/tests", .{});
    var start_cwd = try std.fs.cwd().openDir("/home/john/doc/rep/github.com/sandeee/tests", .{});

    var iter = try dir.walk(std.testing.allocator);
    defer iter.deinit();

    try std.process.changeCurDir("/home/john/doc/rep/github.com/sandeee/zig-out/bin/");

    std.log.info("fdsafdsa", .{});
    while (try iter.next()) |entry| {
        if (entry.kind != .File) continue;

        var file = try start_cwd.openFile(entry.path, .{});

        var conts = try file.readToEndAlloc(std.testing.allocator, 10000);
        defer std.testing.allocator.free(conts);

        try headlessMain(conts, true);
    }
}
