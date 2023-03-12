const std = @import("std");
const freetype = @import("deps/mach-freetype/build.zig");
const mail = @import("src/system/mail.zig");
const comp = @import("tools/asm.zig");
const sound = @import("tools/sound.zig");
const image = @import("tools/textures.zig");
const diskStep = @import("tools/disk.zig");

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const alloc = gpa.allocator();

pub fn emails(b: *std.build.Builder, path: []const u8) []const u8 {
    var root = std.fs.openDirAbsolute(b.pathFromRoot(path), .{ .access_sub_paths = true }) catch null;
    var dir = std.fs.openIterableDirAbsolute(b.pathFromRoot(path), .{ .access_sub_paths = true }) catch null;
    var walker = dir.?.walk(alloc) catch null;
    var entry = walker.?.next() catch null;

    mail.init();
    defer mail.deinit();

    var count: usize = 0;

    while (entry) |file| : (entry = walker.?.next() catch null) {
        switch (file.kind) {
            std.fs.IterableDir.Entry.Kind.File => {
                var f = root.?.openFile(file.path, .{}) catch {
                    std.log.err("Failed to open {s}", .{file.path});
                    return "";
                };
                defer f.close();
                mail.append(mail.parseTxt(f) catch |err| {
                    std.log.err("Failed to parse {s} {}", .{ file.path, err });
                    return "";
                });
                count += 1;
            },
            else => {},
        }
    }

    std.log.info("packed {} emails", .{count});

    return mail.toStr().items;
}

pub fn convertStep(b: *std.build.Builder, converter: anytype, input: []const u8, diskpath: []const u8, inext: []const u8, outext: []const u8, file: []const u8) ?*std.build.WriteFileStep {
    var in = std.fmt.allocPrint(b.allocator, "content/{s}/{s}.{s}", .{ input, file, inext }) catch "";
    var out = std.fmt.allocPrint(b.allocator, "content/disk/{s}/{s}.{s}", .{ diskpath, file, outext }) catch "";

    var cont = converter(in, b.allocator) catch |err| {
        std.log.err("{}", .{err});
        return null;
    };

    return b.addWriteFile(b.pathFromRoot(out), cont.items);
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

    const exe = b.addExecutable("sandeee", "src/main.zig");
    const vm_exe = b.addExecutable("sandeee-vm", "src/main_vm.zig");

    _ = b.exec(&[_][]const u8{ "rm", "-r", "content/disk" }) catch "";
    _ = b.exec(&[_][]const u8{ "cp", "-r", "content/rawdisk", "content/disk" }) catch "";

    // Includes
    exe.addIncludePath("deps/include");
    if (target.os_tag != null and target.os_tag.? == .windows) {
        exe.addLibraryPath("deps/lib");
    }
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addPackage(freetype.pkg);
    freetype.link(b, exe, .{});

    // Sources
    exe.addCSourceFile("deps/src/glad.c", &[_][]const u8{"-std=c99"});

    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("OpenAL");
    exe.linkSystemLibrary("c");
    exe.linkLibC();

    exe.install();

    vm_exe.setTarget(target);
    vm_exe.setBuildMode(mode);
    vm_exe.install();

    var convert_steps = std.ArrayList(*std.build.WriteFileStep).init(b.allocator);

    var write_step = diskStep.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");
    var email_step = b.addWriteFile(b.pathFromRoot("content/emails.eme"), emails(b, b.pathFromRoot("content/mail/")));

    convert_steps.append(convertStep(b, comp.compile, "asm/tests", "prof/tests", "asm", "eep", "hello").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/tests", "prof/tests", "asm", "eep", "window").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/tests", "prof/tests", "asm", "eep", "texture").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/tests", "prof/tests", "asm", "eep", "fib").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/tests", "prof/tests", "asm", "eep", "arraytest").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/tests", "prof/tests", "asm", "eep", "audiotest").?) catch {};

    convert_steps.append(convertStep(b, comp.compile, "asm/exec", "exec", "asm", "eep", "asm").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/exec", "exec", "asm", "eep", "eon").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/exec", "exec", "asm", "eep", "dump").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/exec", "exec", "asm", "eep", "echo").?) catch {};
    convert_steps.append(convertStep(b, comp.compile, "asm/exec", "exec", "asm", "eep", "aplay").?) catch {};

    convert_steps.append(convertStep(b, comp.compile, "asm/libs", "libs", "asm", "eep", "libload").?) catch {};
    convert_steps.append(convertStep(b, comp.compileLib, "asm/libs", "libs", "asm", "ell", "string").?) catch {};
    convert_steps.append(convertStep(b, comp.compileLib, "asm/libs", "libs", "asm", "ell", "window").?) catch {};
    convert_steps.append(convertStep(b, comp.compileLib, "asm/libs", "libs", "asm", "ell", "sound").?) catch {};
    convert_steps.append(convertStep(b, comp.compileLib, "asm/libs", "libs", "asm", "ell", "array").?) catch {};
    convert_steps.append(convertStep(b, comp.compileLib, "asm/libs", "libs", "asm", "ell", "table").?) catch {};

    convert_steps.append(convertStep(b, sound.convert, "audio", "cont/snds", "wav", "era", "login").?) catch {};
    convert_steps.append(convertStep(b, sound.convert, "audio", "cont/snds", "wav", "era", "message").?) catch {};

    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "bar").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "editor").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "email").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "explorer").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "window").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "web").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "wall").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "barlogo").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "cont/imgs", "png", "eia", "cursor").?) catch {};

    convert_steps.append(convertStep(b, image.convert, "images", "../../src/images", "png", "eia", "logo").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "../../src/images", "png", "eia", "load").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "../../src/images", "png", "eia", "palette").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "../../src/images", "png", "eia", "sad").?) catch {};
    convert_steps.append(convertStep(b, image.convert, "images", "../../src/images", "png", "eia", "bios").?) catch {};

    for (convert_steps.items) |step| {
        write_step.step.dependOn(&step.step);
        exe.step.dependOn(&step.step);
    }

    exe.step.dependOn(&write_step.step);
    exe.step.dependOn(&email_step.step);

    const run_cmd = exe.run();
    const vm_run_cmd = vm_exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    vm_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    b.installFile("content/fonts/scientifica.ttf", "bin/content/font.ttf");
    b.installFile("content/fonts/big.ttf", "bin/content/bios.ttf");
    b.installFile("content/emails.eme", "bin/content/emails.eme");

    b.installFile("deps/dll/glfw3.dll", "bin/glfw3.dll");
    b.installFile("deps/dll/libgcc_s_seh-1.dll", "bin/libgcc_s_seh-1.dll");
    b.installFile("deps/dll/libstdc++-6.dll", "bin/libstdc++-6.dll");
    b.installFile("deps/dll/OpenAL32.dll", "bin/OpenAL32.dll");
    b.installFile("deps/dll/libssp-0.dll", "bin/libssp-0.dll");
    b.installFile("deps/dll/libwinpthread-1.dll", "bin/libwinpthread-1.dll");

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const run_vm = b.step("vm", "Run the app");
    run_vm.dependOn(&vm_run_cmd.step);

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
