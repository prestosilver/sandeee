const std = @import("std");
const files = @import("../src/system/files.zig");

pub const DiskStep = struct {
    step: std.build.Step,
    output: []const u8,
    input: []const u8,
    alloc: std.mem.Allocator,

    pub fn create(b: *std.Build, input: []const u8, output: []const u8) *DiskStep {
        const self = b.allocator.create(DiskStep) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.{
                .id = .run,
                .name = std.fmt.allocPrint(b.allocator, "BuildDisk {s} -> {s}", .{ input, output }) catch "BuildDisk",
                .makeFn = DiskStep.doStep,
                .owner = b,
            }),
            .input = input,
            .output = output,
            .alloc = b.allocator,
        };
        return self;
    }

    fn doStep(step: *std.build.Step, _: *std.Progress.Node) !void {
        const self = @fieldParentPtr(DiskStep, "step", step);

        var root = std.fs.cwd().openDir(self.input, .{ .access_sub_paths = true }) catch null;

        var dir = std.fs.cwd().openIterableDir(self.input, .{ .access_sub_paths = true }) catch null;

        var walker = dir.?.walk(self.alloc) catch null;

        var entry = walker.?.next() catch null;
        files.root = self.alloc.create(files.Folder) catch undefined;

        files.root.* = .{
            .parent = undefined,
            .name = files.ROOT_NAME,
            .subfolders = std.ArrayList(*files.Folder).init(self.alloc),
            .contents = std.ArrayList(*files.File).init(self.alloc),
        };

        var count: usize = 0;

        while (entry) |file| : (entry = walker.?.next() catch null) {
            switch (file.kind) {
                .directory => {
                    try files.root.newFolder(file.path);
                },
                else => {},
            }
        }

        walker = dir.?.walk(self.alloc) catch null;

        entry = walker.?.next() catch null;
        while (entry) |file| : (entry = walker.?.next() catch null) {
            switch (file.kind) {
                .file => {
                    try files.root.newFile(file.path);
                    var contents = root.?.readFileAlloc(self.alloc, file.path, 100000000) catch null;
                    if (contents == null) {
                        continue;
                    }

                    try files.root.writeFile(file.path, contents.?, null);
                    count += 1;
                },
                else => {},
            }
        }

        // std.log.info("packed {} files", .{count});

        try std.fs.cwd().writeFile(self.output, (try files.toStr()).items);
    }
};
