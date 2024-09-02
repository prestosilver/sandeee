const std = @import("std");

const DOC_HEADER: []const u8 =
    \\#Style @/style.eds
    \\:logo: [@/logo.eia]
    \\
    \\
;

const DOC_FOOTER =
    \\
    \\:center: --- EEE Sees all ---
;

pub const DocStep = struct {
    step: std.Build.Step,
    input: []const u8,
    output: []const u8,
    root: []const u8,
    alloc: std.mem.Allocator,

    pub fn create(b: *std.Build, input: []const u8, output: []const u8, root: []const u8) !*DocStep {
        const self = try b.allocator.create(DocStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "ChangeLog {s}", .{output}),
                .makeFn = DocStep.doStep,
                .owner = b,
            }),
            .root = root,
            .input = input,
            .output = output,
            .alloc = b.allocator,
        };
        return self;
    }

    fn doStep(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *DocStep = @fieldParentPtr("step", step);
        const b = step.owner;

        std.fs.cwd().deleteTree(self.output) catch {};
        try std.fs.cwd().makePath(self.output);

        var walker = try std.fs.cwd().openDir(self.input, .{
            .iterate = true,
        });

        var iter = try walker.walk(b.allocator);

        while (try iter.next()) |path| {
            switch (path.kind) {
                .directory => {
                    const dir_path = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ self.output, path.path });
                    defer b.allocator.free(dir_path);
                    try std.fs.cwd().makePath(dir_path);
                },
                .file => {
                    const input_file_path = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ self.input, path.path });
                    defer b.allocator.free(input_file_path);

                    const output_file_path = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ self.output, path.path });
                    defer b.allocator.free(output_file_path);

                    const input_file = try std.fs.cwd().openFile(input_file_path, .{ .mode = .read_only });
                    defer input_file.close();
                    const output_file = try std.fs.cwd().createFile(output_file_path, .{});
                    defer output_file.close();

                    var reader = input_file.reader();

                    _ = try output_file.write(DOC_HEADER);

                    while (try reader.readUntilDelimiterOrEofAlloc(b.allocator, '\n', 1024)) |line| {
                        defer b.allocator.free(line);

                        if (std.mem.containsAtLeast(u8, line, 1, "> ")) {
                            const link_index = std.mem.indexOf(u8, line, "> ") orelse unreachable;
                            const index = link_index + 2 + (std.mem.indexOf(u8, line[link_index..], ": ") orelse 0);
                            _ = try output_file.write(line[0..index]);
                            _ = try output_file.write(self.root);
                            _ = try output_file.write(line[index..]);
                        } else {
                            _ = try output_file.write(line);
                        }

                        _ = try output_file.write("\n");
                    }

                    _ = try output_file.write(DOC_FOOTER);
                },
                else => {
                    continue;
                },
            }
        }
    }
};
