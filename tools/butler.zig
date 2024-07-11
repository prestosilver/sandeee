const std = @import("std");

pub const ButlerStep = struct {
    step: std.Build.Step,
    branch: []const u8,
    directory: []const u8,

    pub fn create(b: *std.Build, directory: []const u8, branch: []const u8) !*ButlerStep {
        const self = try b.allocator.create(ButlerStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "UploadButler {s} -> {s}", .{ directory, branch }),
                .makeFn = ButlerStep.doStep,
                .owner = b,
            }),
            .directory = directory,
            .branch = branch,
        };
        return self;
    }

    fn doStep(step: *std.Build.Step, _: *std.Progress.Node) !void {
        const self: *ButlerStep = @fieldParentPtr("step", step);

        _ = step.owner.run(&[_][]const u8{ "butler", "push", "--userversion-file=IVERSION", self.directory, self.branch });
    }
};
