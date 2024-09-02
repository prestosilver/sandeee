const std = @import("std");
const files = @import("../src/system/files.zig");

pub const ConvertStep = struct {
    step: std.Build.Step,
    output: std.Build.LazyPath,
    input: []const std.Build.LazyPath,
    alloc: std.mem.Allocator,
    func: *const fn (*std.Build, []const std.Build.LazyPath) anyerror!std.ArrayList(u8),

    pub fn create(b: *std.Build, func: anytype, input: std.Build.LazyPath, output: std.Build.LazyPath) !*ConvertStep {
        const in = try b.allocator.alloc(std.Build.LazyPath, 1);
        in[0] = input;
        const self = try b.allocator.create(ConvertStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "BuildFile {s} {s}", .{ input.getDisplayName(), output.getDisplayName() }),
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

    pub fn createMulti(b: *std.Build, func: anytype, input: []const std.Build.LazyPath, output: []const u8) !*ConvertStep {
        const self = try b.allocator.create(ConvertStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "BuildFile {s}", .{ input, output }),
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

    fn doStep(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *ConvertStep = @fieldParentPtr("step", step);

        const b = step.owner;

        if (std.fs.path.dirname(self.output.getPath3(b, null).sub_path)) |dir|
            std.fs.cwd().makeDir(dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };

        const file = try std.fs.cwd().createFile(self.output.getPath3(b, null).sub_path, .{});
        defer file.close();

        const cont = try self.func(b, self.input);
        defer cont.deinit();

        _ = try file.writeAll(cont.items);

        try file.sync();
    }
};
