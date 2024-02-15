const std = @import("std");
const files = @import("../src/system/files.zig");

pub const ConvertStep = struct {
    step: std.Build.Step,
    output: []const u8,
    input: []const []const u8,
    alloc: std.mem.Allocator,
    func: *const fn ([]const []const u8, std.mem.Allocator) anyerror!std.ArrayList(u8),

    pub fn create(b: *std.Build, func: anytype, input: []const u8, output: []const u8) !*ConvertStep {
        const in = try b.allocator.alloc([]const u8, 1);
        in[0] = input;
        const self = try b.allocator.create(ConvertStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "BuildFile {s} -> {s}", .{ input, output }),
                .makeFn = ConvertStep.doStep,
                .owner = b,
            }),
            .input = in,
            .output = output,
            .alloc = b.allocator,
            .func = func,
        };

        return self;
    }

    pub fn createMulti(b: *std.Build, func: anytype, input: []const []const u8, output: []const u8) !*ConvertStep {
        const self = try b.allocator.create(ConvertStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "BuildFile {s} -> {s}", .{ input, output }),
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

    fn doStep(step: *std.Build.Step, _: *std.Progress.Node) !void {
        const self = @fieldParentPtr(ConvertStep, "step", step);
        const cont = try self.func(self.input, self.alloc);

        try std.fs.cwd().writeFile(self.output, cont.items);
    }
};
