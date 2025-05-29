const std = @import("std");
const files = @import("../src/system/files.zig");

pub fn copy(
    b: *std.Build,
    paths: []const std.Build.LazyPath,
    output: std.Build.LazyPath,
) anyerror!void {
    if (paths.len != 1) return error.BadPaths;

    const in_path = paths[0].getPath(b);
    var in_file = try std.fs.openFileAbsolute(in_path, .{});
    defer in_file.close();

    const out_path = output.getPath(b);
    var out_file = try std.fs.createFileAbsolute(out_path, .{});
    defer out_file.close();

    var tmp: std.ArrayList(u8) = .init(b.allocator);
    defer tmp.deinit();

    try in_file.reader().readAllArrayList(&tmp, 1000000000);

    try out_file.writeAll(tmp.items);
}

pub const ConvertStep = struct {
    step: std.Build.Step,
    output: std.Build.LazyPath,
    input: []const std.Build.LazyPath,
    alloc: std.mem.Allocator,
    func: *const fn (
        *std.Build,
        []const std.Build.LazyPath,
        std.Build.LazyPath,
    ) anyerror!void,

    pub fn create(b: *std.Build, func: anytype, in: []const std.Build.LazyPath, output: std.Build.LazyPath) !*ConvertStep {
        var input = try b.allocator.dupe(std.Build.LazyPath, in);

        const self = try b.allocator.create(ConvertStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "BuildFile {s} from {s}", .{ output.getDisplayName(), input[0].getDisplayName() }),
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

    // pub fn createMulti(b: *std.Build, func: anytype, input: []const std.Build.LazyPath, output: []const u8) !*ConvertStep {
    //     const self = try b.allocator.create(ConvertStep);
    //     self.* = .{
    //         .step = std.Build.Step.init(.{
    //             .id = .run,
    //             .name = try std.fmt.allocPrint(b.allocator, "BuildFile {s}", .{ input, output }),
    //             .makeFn = ConvertStep.doStep,
    //             .owner = b,
    //         }),
    //         .input = input,
    //         .output = output,
    //         .alloc = b.allocator,
    //         .func = func,
    //     };

    //     return self;
    // }

    fn doStep(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *ConvertStep = @fieldParentPtr("step", step);

        const b = step.owner;

        if (std.fs.path.dirname(self.output.getPath(b))) |dir|
            std.fs.cwd().makePath(dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };

        try self.func(b, self.input, self.output);
    }
};
