const std = @import("std");
const files = @import("../src/system/files.zig");

pub const DiskStep = struct {
    step: std.Build.Step,
    output: []const u8,
    input: []const u8,
    alloc: std.mem.Allocator,

    pub fn create(b: *std.Build, input: []const u8, output: []const u8) !*DiskStep {
        const self = try b.allocator.create(DiskStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "BuildDisk {s} -> {s}", .{ input, output }),
                .makeFn = DiskStep.doStep,
                .owner = b,
            }),
            .input = input,
            .output = output,
            .alloc = b.allocator,
        };
        return self;
    }

    fn doStep(step: *std.Build.Step, _: *std.Progress.Node) !void {
        const self = @fieldParentPtr(DiskStep, "step", step);

        var root = try std.fs.cwd().openDir(self.input, .{ .access_sub_paths = true, .iterate = true });
        var walker = try root.walk(self.alloc);

        files.root = try self.alloc.create(files.Folder);

        files.root.* = .{
            .parent = undefined,
            .name = files.ROOT_NAME,
            .subfolders = std.ArrayList(*files.Folder).init(self.alloc),
            .contents = std.ArrayList(*files.File).init(self.alloc),
        };

        var count: usize = 0;

        while (try walker.next()) |file| {
            switch (file.kind) {
                .directory => {
                    try files.root.newFolder(file.path);
                },
                else => {},
            }
        }

        walker = try root.walk(self.alloc);

        while (try walker.next()) |file| {
            switch (file.kind) {
                .file => {
                    try files.root.newFile(file.path);
                    const contents = try root.readFileAlloc(self.alloc, file.path, 100000000);

                    try files.root.writeFile(file.path, contents, null);
                    count += 1;
                },
                else => {},
            }
        }

        // std.log.info("packed {} files", .{count});

        try std.fs.cwd().writeFile(self.output, (try files.toStr()).items);
    }
};
