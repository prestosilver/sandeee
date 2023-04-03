const std = @import("std");
const freetype = @import("deps/mach-freetype/build.zig");
const mail = @import("src/system/mail.zig");
const comp = @import("tools/asm.zig");
const sound = @import("tools/sound.zig");
const image = @import("tools/textures.zig");
const diskStep = @import("tools/disk.zig");
const conv = @import("tools/convert.zig");
const eon = @import("tools/eon.zig");

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
                }) catch {};
                count += 1;
            },
            else => {},
        }
    }

    std.log.info("packed {} emails", .{count});

    return mail.toStr() catch "";
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
    const exe = b.addExecutable(.{
        .name = "sandeee",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    const networkModule = b.createModule(.{
        .source_file = .{ .path = "deps/zig-network/network.zig" },
    });

    const freetypeModule = b.createModule(freetype.module);

    exe.addModule("network", networkModule);
    exe.addModule("freetype", freetypeModule);

    _ = b.exec(&[_][]const u8{ "rm", "-r", "content/disk" });
    _ = b.exec(&[_][]const u8{ "cp", "-r", "content/rawdisk", "content/disk" });
    if (exe.optimize == .Debug) {
        _ = b.exec(&[_][]const u8{ "cp", "-r", "content/disk_debug/prof", "content/disk" });
    }

    // Includes
    exe.addIncludePath("deps/include");
    exe.addIncludePath("deps/include/freetype2");
    if (exe.target.os_tag != null and exe.target.os_tag.? == .windows) {
        exe.addObjectFile("content/app.res.obj");
        exe.addLibraryPath("deps/lib");
        exe.subsystem = .Windows;
    }

    // Sources
    exe.addCSourceFile("deps/src/glad.c", &[_][]const u8{"-std=c99"});

    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("OpenAL");
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("freetype");
    exe.linkLibC();

    exe.install();

    var convert_steps = std.ArrayList(*conv.ConvertStep).init(b.allocator);

    var write_step = diskStep.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");
    var email_step = b.addWriteFile(b.pathFromRoot("content/emails.eme"), emails(b, b.pathFromRoot("content/mail/")));

    if (exe.optimize == .Debug) {
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/hello.asm", "content/disk/prof/tests/hello.eep")) catch {};
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/window.asm", "content/disk/prof/tests/window.eep")) catch {};
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/texture.asm", "content/disk/prof/tests/texture.eep")) catch {};
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/fib.asm", "content/disk/prof/tests/fib.eep")) catch {};
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/arraytest.asm", "content/disk/prof/tests/arraytest.eep")) catch {};
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/audiotest.asm", "content/disk/prof/tests/audiotest.eep")) catch {};
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/net.asm", "content/disk/prof/tests/send.eep")) catch {};
        convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/tests/recv.asm", "content/disk/prof/tests/recv.eep")) catch {};

        const eonFiles = [_][]const u8{ "test", "fib" };

        for (eonFiles) |file| {
            var eonf = std.fmt.allocPrint(b.allocator, "content/eon/{s}.eon", .{file}) catch "";
            var asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/{s}.asm", .{file}) catch "";
            var eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/eon/{s}.eep", .{file}) catch "";

            var compStep = conv.ConvertStep.create(b, eon.compileEon, eonf, asmf);

            var adds = conv.ConvertStep.create(b, comp.compile, asmf, eepf);

            adds.step.dependOn(&compStep.step);

            convert_steps.append(adds) catch {};
        }
    }

    convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/exec/asm.asm", "content/disk/exec/asm.eep")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/exec/eon.asm", "content/disk/exec/eon.eep")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/exec/dump.asm", "content/disk/exec/dump.eep")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/exec/echo.asm", "content/disk/exec/echo.eep")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/exec/aplay.asm", "content/disk/exec/aplay.eep")) catch {};

    convert_steps.append(conv.ConvertStep.create(b, comp.compile, "content/asm/libs/libload.asm", "content/disk/libs/libload.eep")) catch {};

    convert_steps.append(conv.ConvertStep.create(b, comp.compileLib, "content/asm/libs/string.asm", "content/disk/libs/string.ell")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compileLib, "content/asm/libs/window.asm", "content/disk/libs/window.ell")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compileLib, "content/asm/libs/sound.asm", "content/disk/libs/sound.ell")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compileLib, "content/asm/libs/array.asm", "content/disk/libs/array.ell")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, comp.compileLib, "content/asm/libs/table.asm", "content/disk/libs/table.ell")) catch {};

    convert_steps.append(conv.ConvertStep.create(b, sound.convert, "content/audio/login.wav", "content/disk/cont/snds/login.era")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, sound.convert, "content/audio/message.wav", "content/disk/cont/snds/message.era")) catch {};

    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/bar.png", "content/disk/cont/imgs/bar.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/editor.png", "content/disk/cont/imgs/editor.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/email.png", "content/disk/cont/imgs/email.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/explorer.png", "content/disk/cont/imgs/explorer.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/window.png", "content/disk/cont/imgs/window.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/web.png", "content/disk/cont/imgs/web.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/wall.png", "content/disk/cont/imgs/wall.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/barlogo.png", "content/disk/cont/imgs/barlogo.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/cursor.png", "content/disk/cont/imgs/cursor.eia")) catch {};

    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/logo.png", "src/images/logo.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/load.png", "src/images/load.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/sad.png", "src/images/sad.eia")) catch {};
    convert_steps.append(conv.ConvertStep.create(b, image.convert, "content/images/bios.png", "src/images/bios.eia")) catch {};

    for (convert_steps.items) |step| {
        write_step.step.dependOn(&step.step);
    }

    exe.step.dependOn(&write_step.step);
    exe.step.dependOn(&email_step.step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addArgs(&[_][]const u8{ "--cwd", "./zig-out/bin" });
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const headless_cmd = exe.run();
    headless_cmd.step.dependOn(b.getInstallStep());
    headless_cmd.addArgs(&[_][]const u8{ "--cwd", "./zig-out/bin", "--headless" });
    if (b.args) |args| {
        headless_cmd.addArgs(args);
    }

    b.installFile("content/fonts/scientifica.ttf", "bin/content/font.ttf");
    b.installFile("content/fonts/big.ttf", "bin/content/bios.ttf");
    b.installFile("content/emails.eme", "bin/content/emails.eme");

    b.installFile("deps/dll/glfw3.dll", "bin/glfw3.dll");
    b.installFile("deps/dll/libgcc_s_seh-1.dll", "bin/libgcc_s_seh-1.dll");
    b.installFile("deps/dll/libstdc++-6.dll", "bin/libstdc++-6.dll");
    b.installFile("deps/dll/OpenAL32.dll", "bin/OpenAL32.dll");
    b.installFile("deps/dll/libssp-0.dll", "bin/libssp-0.dllcd");
    b.installFile("deps/dll/libwinpthread-1.dll", "bin/libwinpthread-1.dll");
    b.installFile("deps/dll/libfreetype-6.dll", "bin/libfreetype-6.dll");
    b.installFile("deps/dll/libbz2-1.dll", "bin/libbz2-1.dll");
    b.installFile("deps/dll/libbrotlidec.dll", "bin/libbrotlidec.dll");
    b.installFile("deps/dll/libbrotlicommon.dll", "bin/libbrotlicommon.dll");
    b.installFile("deps/dll/zlib1.dll", "bin/zlib1.dll");

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const headless_step = b.step("headless", "Run the app headless");
    headless_step.dependOn(&headless_cmd.step);

    const exe_tests = b.addTest(.{
        .name = "sandeee",
        .root_source_file = .{
            .path = "src/main.zig",
        },
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
