const std = @import("std");
const vma = @import("system/vm.zig");
const files = @import("system/files.zig");
const allocator = @import("util/allocator.zig");

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var args = std.process.args();

    _ = args.next();

    if (args.next()) |file| {
        var contents = try std.fs.cwd().readFileAlloc(allocator.alloc, file, 100000);

        var vm = try vma.VM.init(allocator.alloc, files.root, file);
        defer vm.destroy();

        std.log.info("loading", .{});

        try vm.loadString(contents[4..]);

        std.log.info("running...", .{});

        try vm.runAll();

        try stdout.print("{s}", .{vm.out.items});
    }
}
