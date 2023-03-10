const std = @import("std");
const files = @import("../src/system/files.zig");

pub const DiskStep = struct {
    step: std.build.Step,
    output: []const u8,
    input: []const u8,
    alloc: std.mem.Allocator,

    pub fn create(b: *std.build.Builder, input: []const u8, output: []const u8) *DiskStep {
        const self = b.allocator.create(DiskStep) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.run, "custom_step", b.allocator, DiskStep.doStep),
            .input = input,
            .output = output,
            .alloc = b.allocator,
        };
        return self;
    }

    fn doStep(step: *std.build.Step) !void {
        const self = @fieldParentPtr(DiskStep, "step", step);

        _ = self;
    }
};
