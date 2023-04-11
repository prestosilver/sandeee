const std = @import("std");

pub const ButlerStep = struct {
    step: std.build.Step,
    branch: []const u8,
    directory: []const u8,

    pub fn create(b: *std.Build, directory: []const u8, branch: []const u8) *ButlerStep {
        const self = b.allocator.create(ButlerStep) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.{
                .id = .run,
                .name = std.fmt.allocPrint(b.allocator, "UploadButler {s} -> {s}", .{ directory, branch }) catch "UploadButler",
                .makeFn = ButlerStep.doStep,
                .owner = b,
            }),
            .directory = directory,
            .branch = branch,
        };
        return self;
    }

    fn doStep(step: *std.build.Step, _: *std.Progress.Node) !void {
        const self = @fieldParentPtr(ButlerStep, "step", step);
        _ = step.owner.exec(&[_][]const u8{ "butler", "push", self.directory, self.branch });
    }
};
