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

const asmTestsFiles = [_][]const u8{ "hello", "window", "texture", "fib", "arraytest", "audiotest", "tabletest", "send", "recv" };
const eonTestsFiles = [_][]const u8{ "fib", "tabletest", "heaptest" };
const asmExecFiles = [_][]const u8{ "eon", "dump", "echo", "aplay", "libdump" };
const eonExecFiles = [_][]const u8{"asm"};
const asmLibFiles = [_][]const u8{ "string", "window", "sound", "array" };
const eonLibFiles = [_][]const u8{ "heap", "table" };
const wavSoundFiles = [_][]const u8{ "login", "message" };
const pngImageFiles = [_][]const u8{ "bar", "editor", "email", "explorer", "window", "web", "wall", "barlogo", "cursor", "scroll" };
const internalImageFiles = [_][]const u8{ "logo", "load", "sad", "bios" };

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

    _ = b.exec(&[_][]const u8{ "rm", "-rf", "content/disk" });
    _ = b.exec(&[_][]const u8{ "cp", "-r", "content/rawdisk", "content/disk" });
    _ = b.exec(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/content" });
    _ = b.exec(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/disks" });
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

    var write_step = diskStep.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");
    var email_step = b.addWriteFile(b.pathFromRoot("content/emails.eme"), emails(b, b.pathFromRoot("content/mail/")));

    if (exe.optimize == .Debug) {
        for (asmTestsFiles) |file| {
            var asmf = std.fmt.allocPrint(b.allocator, "content/asm/tests/{s}.asm", .{file}) catch "";
            var eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/Tests/asm/{s}.eep", .{file}) catch "";

            var step = conv.ConvertStep.create(b, comp.compile, asmf, eepf);
            write_step.step.dependOn(&step.step);
        }

        for (eonTestsFiles) |file| {
            var eonf = std.fmt.allocPrint(b.allocator, "content/eon/tests/{s}.eon", .{file}) catch "";
            var asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/{s}.asm", .{file}) catch "";
            var eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/Tests/eon/{s}.eep", .{file}) catch "";

            var step = conv.ConvertStep.create(b, comp.compile, asmf, eepf);
            var compStep = conv.ConvertStep.create(b, eon.compileEon, eonf, asmf);

            step.step.dependOn(&compStep.step);

            write_step.step.dependOn(&step.step);
        }
    }

    for (asmExecFiles) |file| {
        var asmf = std.fmt.allocPrint(b.allocator, "content/asm/exec/{s}.asm", .{file}) catch "";
        var eepf = std.fmt.allocPrint(b.allocator, "content/disk/exec/{s}.eep", .{file}) catch "";

        var step = conv.ConvertStep.create(b, comp.compile, asmf, eepf);

        write_step.step.dependOn(&step.step);
    }

    for (eonExecFiles) |file| {
        var eonf = std.fmt.allocPrint(b.allocator, "content/eon/exec/{s}.eon", .{file}) catch "";
        var asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/{s}.asm", .{file}) catch "";
        var eepf = std.fmt.allocPrint(b.allocator, "content/disk/exec/{s}.eep", .{file}) catch "";

        var compStep = conv.ConvertStep.create(b, eon.compileEon, eonf, asmf);

        var adds = conv.ConvertStep.create(b, comp.compile, asmf, eepf);

        adds.step.dependOn(&compStep.step);

        write_step.step.dependOn(&adds.step);
    }

    var libLoadStep = conv.ConvertStep.create(b, comp.compile, "content/asm/libs/libload.asm", "content/disk/libs/libload.eep");
    write_step.step.dependOn(&libLoadStep.step);

    for (asmLibFiles) |file| {
        var asmf = std.fmt.allocPrint(b.allocator, "content/asm/libs/{s}.asm", .{file}) catch "";
        var ellf = std.fmt.allocPrint(b.allocator, "content/disk/libs/{s}.ell", .{file}) catch "";

        var step = conv.ConvertStep.create(b, comp.compileLib, asmf, ellf);

        write_step.step.dependOn(&step.step);
    }

    for (eonLibFiles) |file| {
        var eonf = std.fmt.allocPrint(b.allocator, "content/eon/libs/{s}.eon", .{file}) catch "";
        var asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/{s}.asm", .{file}) catch "";
        var ellf = std.fmt.allocPrint(b.allocator, "content/disk/libs/{s}.ell", .{file}) catch "";

        var compStep = conv.ConvertStep.create(b, eon.compileEonLib, eonf, asmf);

        var adds = conv.ConvertStep.create(b, comp.compileLib, asmf, ellf);

        adds.step.dependOn(&compStep.step);

        write_step.step.dependOn(&adds.step);
    }

    for (wavSoundFiles) |file| {
        var wavf = std.fmt.allocPrint(b.allocator, "content/audio/{s}.wav", .{file}) catch "";
        var eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/snds/{s}.era", .{file}) catch "";

        var step = conv.ConvertStep.create(b, sound.convert, wavf, eraf);

        write_step.step.dependOn(&step.step);
    }

    for (pngImageFiles) |file| {
        var pngf = std.fmt.allocPrint(b.allocator, "content/images/{s}.png", .{file}) catch "";
        var eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/imgs/{s}.eia", .{file}) catch "";

        var step = conv.ConvertStep.create(b, image.convert, pngf, eraf);

        write_step.step.dependOn(&step.step);
    }

    for (internalImageFiles) |file| {
        var pngf = std.fmt.allocPrint(b.allocator, "content/images/{s}.png", .{file}) catch "";
        var eraf = std.fmt.allocPrint(b.allocator, "src/images/{s}.eia", .{file}) catch "";

        var step = conv.ConvertStep.create(b, image.convert, pngf, eraf);

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

    const test_cmd = exe.run();
    test_cmd.step.dependOn(b.getInstallStep());
    test_cmd.addArgs(&[_][]const u8{ "--headless-cmd", "tests/heap.esh", "--cwd", "./zig-out/bin" });
    if (b.args) |args| {
        test_cmd.addArgs(args);
    }

    b.installFile("content/fonts/scientifica.ttf", "bin/content/font.ttf");
    b.installFile("content/fonts/big.ttf", "bin/content/bios.ttf");
    b.installFile("content/emails.eme", "bin/content/emails.eme");

    if (exe.target.os_tag != null and exe.target.os_tag.? == .windows) {
        b.installFile("deps/dll/glfw3.dll", "bin/glfw3.dll");
        b.installFile("deps/dll/libgcc_s_seh-1.dll", "bin/libgcc_s_seh-1.dll");
        b.installFile("deps/dll/libstdc++-6.dll", "bin/libstdc++-6.dll");
        b.installFile("deps/dll/OpenAL32.dll", "bin/OpenAL32.dll");
        b.installFile("deps/dll/libssp-0.dll", "bin/libssp-0.dll");
        b.installFile("deps/dll/libwinpthread-1.dll", "bin/libwinpthread-1.dll");
        b.installFile("deps/dll/libfreetype-6.dll", "bin/libfreetype-6.dll");
        b.installFile("deps/dll/libbz2-1.dll", "bin/libbz2-1.dll");
        b.installFile("deps/dll/libbrotlidec.dll", "bin/libbrotlidec.dll");
        b.installFile("deps/dll/libbrotlicommon.dll", "bin/libbrotlicommon.dll");
        b.installFile("deps/dll/zlib1.dll", "bin/zlib1.dll");
    }

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
    test_step.dependOn(&test_cmd.step);
}
