const std = @import("std");
const conv = @import("convert.zig");

pub const DiskFileInputType = enum {
    Local,
    Temp,
};

pub const DiskFileInputData = union(DiskFileInputType) {
    Local: []const u8,
    Temp: *const DiskFileInput,

    pub fn local(path: []const u8) DiskFileInputData {
        return .{
            .Local = path,
        };
    }

    pub fn converter(
        conve: *const fn (*std.Build, []const std.Build.LazyPath, std.Build.LazyPath) anyerror!void,
        child: DiskFileInputData,
    ) DiskFileInputData {
        return .{
            .Temp = &.{
                .input = &.{child},
                .converter = conve,
            },
        };
    }
};

pub const DiskFileInput = struct {
    input: []const DiskFileInputData,

    converter: *const fn (*std.Build, []const std.Build.LazyPath, std.Build.LazyPath) anyerror!void,

    fn getStep(
        self: DiskFileInput,
        b: *std.Build,
        content: std.Build.LazyPath,
        output: std.Build.LazyPath,
        outer_depend: *std.Build.Step,
    ) !*std.Build.Step {
        const temp_path = content.path(b, ".tmp");

        var child_steps: std.ArrayList(*std.Build.Step) = .init(b.allocator);

        const files = try b.allocator.alloc(std.Build.LazyPath, self.input.len);
        for (self.input, files) |input, *file| {
            switch (input) {
                .Local => |l| {
                    file.* = content.path(b, l);
                },
                .Temp => |t| {
                    const last_slash = if (std.mem.lastIndexOf(u8, output.getPath(b), "/")) |x| x + 1 else 0;

                    const temp_file = temp_path.path(b, b.fmt("{s}.tmp", .{output.getPath(b)[last_slash..]}));
                    file.* = temp_file;

                    const child_step = try t.getStep(b, content, file.*, outer_depend);

                    try child_steps.append(child_step);
                },
            }
        }

        const out_step = try conv.ConvertStep.create(b, self.converter, files, output);

        for (child_steps.items) |child|
            out_step.step.dependOn(child);

        out_step.step.dependOn(outer_depend);

        return &out_step.step;
    }
};

pub const DiskFile = struct {
    file: DiskFileInput,
    output: []const u8,

    pub fn getStep(
        self: *const DiskFile,
        b: *std.Build,
        content_path: std.Build.LazyPath,
        output_root: std.Build.LazyPath,
        outer_depend: *std.Build.Step,
    ) !*std.Build.Step {
        return self.file.getStep(
            b,
            content_path,
            output_root.path(b, self.output),
            outer_depend,
        );
    }
};

pub const EpkFileStep = struct {
    step: std.Build.Step,

    files: std.ArrayList(struct { name: []const u8, path: std.Build.LazyPath }),
    content_path: std.Build.LazyPath,
    tmp_path: std.Build.LazyPath,
    output: std.Build.LazyPath,
    alloc: std.mem.Allocator,

    fn doStep(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *EpkFileStep = @fieldParentPtr("step", step);
        const b = step.owner;

        defer self.files.deinit();

        const path = self.output.getPath(b);
        const file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();

        const writer_buffer: [1024]u8 = undefined;
        const writer = file.writer(&writer_buffer);

        try writer.writeAll("epak");

        for (self.files.items) |child_file| {
            const name = child_file.name;
            const name_len: u16 = @intCast(name.len);

            try writer.writeAll(&.{
                std.mem.asBytes(&name_len)[1],
                std.mem.asBytes(&name_len)[0],
            });
            try writer.writeAll(name);

            var data: std.ArrayList(u8) = .init(b.allocator);
            defer data.deinit();

            const pack_path = child_file.path.getPath(b);
            const input_file = try std.fs.openFileAbsolute(pack_path, .{});
            defer input_file.close();

            try input_file.reader().readAllArrayList(&data, 100000000);

            const data_len: u16 = @intCast(data.items.len);
            try writer.writeAll(&.{
                std.mem.asBytes(&data_len)[1],
                std.mem.asBytes(&data_len)[0],
            });
            try writer.writeAll(data.items);
        }
    }

    pub fn create(
        b: *std.Build,
        content_path: std.Build.LazyPath,
        output: std.Build.LazyPath,
    ) !*EpkFileStep {
        const last_slash = if (std.mem.lastIndexOf(u8, output.getPath(b), "/")) |x| x + 1 else 0;

        const self = try b.allocator.create(EpkFileStep);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .run,
                .name = b.fmt("Epk File {s}", .{output.getDisplayName()}),
                .makeFn = EpkFileStep.doStep,
                .owner = b,
            }),
            .alloc = b.allocator,
            .content_path = content_path,
            .output = output,
            .files = .init(b.allocator),
            .tmp_path = b.path(b.fmt("content/.tmp/{s}.tmp", .{output.getPath(b)[last_slash..]})),
        };

        return self;
    }

    pub fn addFile(
        self: *EpkFileStep,
        b: *std.Build,
        file: DiskFile,
        outer_depend: *std.Build.Step,
    ) !void {
        const tmp_file = self.tmp_path.path(b, file.output[1..]);
        try self.files.append(.{ .name = file.output, .path = tmp_file });

        const step = try file.file.getStep(b, self.content_path, tmp_file, outer_depend);

        self.step.dependOn(outer_depend);
        self.step.dependOn(step);
    }
};

pub const WWWFileType = enum {
    epk,
    file,
};

pub const WWWSection = struct {
    label: []const u8,
    folder: []const u8,
    files: []const struct {
        label: []const u8,
        file: []const u8,

        data: union(WWWFileType) {
            epk: []const DiskFile,
            file: DiskFileInput,
        },
    },

    fn emptyStep(_: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {}

    pub fn getStep(
        self: *const WWWSection,
        b: *std.Build,
        content_path: std.Build.LazyPath,
        www_path: std.Build.LazyPath,
        outer_depend: *std.Build.Step,
    ) !*std.Build.Step {
        const step = try b.allocator.create(std.Build.Step);
        step.* = std.Build.Step.init(.{
            .id = .run,
            .name = b.fmt("DownloadPage {s}", .{self.label}),
            .makeFn = emptyStep,
            .owner = b,
        });

        const output = www_path.path(b, self.folder);

        for (self.files) |file| {
            switch (file.data) {
                .epk => |epk| {
                    const epk_step = try EpkFileStep.create(b, content_path, output.path(b, file.file));
                    for (epk) |p| {
                        try epk_step.addFile(b, p, outer_depend);
                    }

                    step.dependOn(&epk_step.step);
                },
                .file => |f| {
                    const file_step = try f.getStep(b, content_path, output.path(b, file.file), outer_depend);
                    step.dependOn(file_step);
                },
            }
        }

        step.dependOn(outer_depend);

        return step;
    }
};
