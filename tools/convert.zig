const std = @import("std");
const files = @import("../src/system/files.zig");

pub const ConvertStep = struct {
    step: std.build.Step,
    output: []const u8,
    input: []const u8,
    alloc: std.mem.Allocator,
    func: *const fn ([]const u8, std.mem.Allocator) anyerror!std.ArrayList(u8),

    pub fn create(b: *std.Build, func: anytype, input: []const u8, output: []const u8) *ConvertStep {
        const self = b.allocator.create(ConvertStep) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.{
                .id = .run,
                .name = std.fmt.allocPrint(b.allocator, "BuildFile {s} -> {s}", .{ input, output }) catch "BuildDisk",
                .makeFn = ConvertStep.doStep,
                .owner = b,
            }),
            .input = input,
            .output = output,
            .alloc = b.allocator,
            .func = func,
        };
        return self;
    }

    fn doStep(step: *std.build.Step, _: *std.Progress.Node) !void {
        const self = @fieldParentPtr(ConvertStep, "step", step);
        var cont = try self.func(self.input, self.alloc);

        try std.fs.cwd().writeFile(self.output, cont.items);
    }
};
