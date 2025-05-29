const std = @import("std");
const www = @import("www.zig");

pub const DownloadPageStep = struct {
    step: std.Build.Step,
    output: std.Build.LazyPath,
    sections: []const www.WWWSection,
    alloc: std.mem.Allocator,

    pub fn create(b: *std.Build, data: []const www.WWWSection, output: std.Build.LazyPath) !*DownloadPageStep {
        const self = try b.allocator.create(DownloadPageStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = try std.fmt.allocPrint(b.allocator, "DownloadPage {s}", .{output.getDisplayName()}),
                .makeFn = DownloadPageStep.doStep,
                .owner = b,
            }),
            .sections = data,
            .output = output,
            .alloc = b.allocator,
        };

        return self;
    }

    pub fn doStep(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *DownloadPageStep = @fieldParentPtr("step", step);
        const b = step.owner;

        const tmp_path = self.output.getPath(b);
        var out_file = try std.fs.createFileAbsolute(tmp_path, .{});
        defer out_file.close();

        const writer = out_file.writer();

        try writer.writeAll("#Style @/style.eds\n\n");
        try writer.writeAll(":logo: [@/logo.eia]\n\n");
        try writer.writeAll(":center: -- Downloads --\n\n");

        for (self.sections) |section| {
            try writer.writeAll(b.fmt(":hs: {s}\n\n", .{section.label}));
            for (section.files) |file| {
                try writer.writeAll(b.fmt(":biglink: > {s}: @/downloads/{s}/{s}\n", .{ file.label, section.folder, file.file }));
            }
            try writer.writeAll("\n");
        }

        try writer.writeAll(":center: --- EEE Sees all ---");
    }
};
