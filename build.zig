const std = @import("std");
const freetype = @import("deps/zig-freetype/build.zig");
const files = @import("src/system/files.zig");

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const alloc = gpa.allocator();

pub fn disk(b: *std.build.Builder, path: []const u8) []const u8 {
    var root = std.fs.openDirAbsolute(b.pathFromRoot(path), .{ .access_sub_paths = true }) catch null;

    var dir = std.fs.openIterableDirAbsolute(b.pathFromRoot(path), .{ .access_sub_paths = true }) catch null;

    var walker = dir.?.walk(alloc) catch null;

    var entry = walker.?.next() catch null;
    files.root = alloc.create(files.Folder) catch undefined;

    files.root.name = files.ROOT_NAME;
    files.root.subfolders = std.ArrayList(files.Folder).init(alloc);
    files.root.contents = std.ArrayList(files.File).init(alloc);

    while (entry) |file| : (entry = walker.?.next() catch null) {
        switch (file.kind) {
            std.fs.IterableDir.Entry.Kind.File => {
                std.debug.assert(files.newFile(file.path));
                var contents = root.?.readFileAlloc(alloc, file.path, 100000) catch "";

                std.debug.assert(files.writeFile(file.path, contents));
            },
            else => {},
        }
    }

    std.log.info("generated disk", .{});

    return files.toStr().items;
}

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("programming-sim", "src/main.zig");

    // Includes
    exe.addIncludePath("deps/include");
    exe.addLibraryPath("deps/lib");

    freetype.addFreetype(exe) catch {};

    // Sources
    exe.addCSourceFile("deps/src/stb_image_impl.c", &[_][]const u8{"-std=c99"});
    exe.addCSourceFile("deps/src/glad.c", &[_][]const u8{"-std=c99"});

    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("c");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    var write_step = b.addWriteFile(b.pathFromRoot("content/default.eee"), disk(b, b.pathFromRoot("content/disk/")));

    exe.step.dependOn(&write_step.step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    b.installFile("content/images/window.png", "bin/content/window.png");
    b.installFile("content/images/bar.png", "bin/content/bar.png");
    b.installFile("content/images/email.png", "bin/content/email.png");
    b.installFile("content/images/editor.png", "bin/content/editor.png");
    b.installFile("content/fonts/scientifica.ttf", "bin/content/font.ttf");
    b.installFile("content/default.eee", "bin/content/default.eee");

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const vm_tests = b.addTest("src/system/vm.zig");
    vm_tests.setTarget(target);
    vm_tests.setBuildMode(mode);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
    test_step.dependOn(&vm_tests.step);
}
