const std = @import("std");
const mail = @import("src/system/mail.zig");
const comp = @import("tools/asm.zig");
const sound = @import("tools/sound.zig");
const image = @import("tools/textures.zig");
const diskStep = @import("tools/disk.zig");
const conv = @import("tools/convert.zig");
const font = @import("tools/fonts.zig");
const eon = @import("tools/eon.zig");
const butler = @import("tools/butler.zig");
const emails = @import("tools/mail.zig");

const asmTestsFiles = [_][]const u8{ "hello", "window", "texture", "fib", "arraytest", "audiotest", "tabletest" };
const eonTestsFiles = [_][]const u8{ "pong", "paint", "fib", "tabletest", "heaptest", "stringtest", "paren" };
const asmExecFiles = [_][]const u8{ "time", "dump", "echo", "aplay", "libdump" };
const eonExecFiles = [_][]const u8{ "eon", "stat", "player", "asm", "pix" };
const asmLibFiles = [_][]const u8{ "string", "window", "texture", "sound", "array" };
const eonLibFiles = [_][]const u8{ "heap", "table" };
const wavSoundFiles = [_][]const u8{ "login", "message", "track1" };
const pngImageFiles = [_][]const u8{ "notif", "bar", "editor", "email", "explorer", "window", "web", "wall", "barlogo", "cursor", "scroll", "connectris" };
const internalImageFiles = [_][]const u8{ "logo", "load", "sad", "bios", "error" };
const incLibsFiles = [_][]const u8{"libload"};
const mailDirs = [_][]const u8{ "inbox", "spam" };

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

    exe.addModule("network", networkModule);

    _ = b.exec(&[_][]const u8{ "rm", "-rf", "content/disk" });
    _ = b.exec(&[_][]const u8{ "cp", "-r", "content/rawdisk", "content/disk" });
    _ = b.exec(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/content" });
    _ = b.exec(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/disks" });
    if (exe.optimize == .Debug) {
        _ = b.exec(&[_][]const u8{ "cp", "-r", "content/disk_debug/prof", "content/disk" });
    }

    // Includes
    exe.addIncludePath("deps/include");
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
    exe.linkLibC();

    b.installArtifact(exe);

    var write_step = diskStep.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");
    var email_step = conv.ConvertStep.create(b, emails.emails, "content/mail/inbox/", "content/disk/cont/mail/inbox.eme");
    var email_spam_step = conv.ConvertStep.create(b, emails.emails, "content/mail/spam/", "content/disk/cont/mail/spam.eme");

    if (exe.optimize == .Debug) {
        for (asmTestsFiles) |file| {
            var asmf = std.fmt.allocPrint(b.allocator, "content/asm/tests/{s}.asm", .{file}) catch "";
            var eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/asm/{s}.eep", .{file}) catch "";

            var step = conv.ConvertStep.create(b, comp.compile, asmf, eepf);
            write_step.step.dependOn(&step.step);
        }

        for (eonTestsFiles) |file| {
            var eonf = std.fmt.allocPrint(b.allocator, "content/eon/tests/{s}.eon", .{file}) catch "";
            var asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/{s}.asm", .{file}) catch "";
            var eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/eon/{s}.eep", .{file}) catch "";

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

    var fontStep = conv.ConvertStep.create(b, font.convert, "content/images/font.png", "content/disk/cont/fnts/main.eff");
    var biosFontStep = conv.ConvertStep.create(b, font.convert, "content/images/bios_font.png", "src/images/main.eff");

    write_step.step.dependOn(&fontStep.step);
    write_step.step.dependOn(&biosFontStep.step);
    write_step.step.dependOn(&email_step.step);

    email_step.step.dependOn(&email_spam_step.step);

    exe.step.dependOn(&write_step.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addArgs(&[_][]const u8{ "--cwd", "./zig-out/bin" });
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const headless_cmd = b.addRunArtifact(exe);
    headless_cmd.step.dependOn(b.getInstallStep());
    headless_cmd.addArgs(&[_][]const u8{ "--cwd", "./zig-out/bin", "--headless" });
    if (b.args) |args| {
        headless_cmd.addArgs(args);
    }

    if (exe.target.os_tag != null and exe.target.os_tag.? == .windows) {
        b.installFile("deps/dll/glfw3.dll", "bin/glfw3.dll");
        b.installFile("deps/dll/libgcc_s_seh-1.dll", "bin/libgcc_s_seh-1.dll");
        b.installFile("deps/dll/libstdc++-6.dll", "bin/libstdc++-6.dll");
        b.installFile("deps/dll/OpenAL32.dll", "bin/OpenAL32.dll");
        b.installFile("deps/dll/libssp-0.dll", "bin/libssp-0.dll");
        b.installFile("deps/dll/libwinpthread-1.dll", "bin/libwinpthread-1.dll");
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const headless_step = b.step("headless", "Run the app headless");
    headless_step.dependOn(&headless_cmd.step);

    const exe_tests = b.addTest(.{
        .name = "main-test",
        .root_source_file = .{
            .path = "src/main.zig",
        },
    });

    exe_tests.step.dependOn(&write_step.step);

    const platform = if (exe.target.os_tag) |tag|
        switch (tag) {
            .windows => "win",
            .linux => "linux",
            else => "",
        }
    else
        "linux";

    const suffix = switch (exe.optimize) {
        .Debug => "-dbg",
        else => "",
    };

    const branch = std.fmt.allocPrint(b.allocator, "prestosilver/sandeee-os:{s}{s}", .{ platform, suffix }) catch "";

    const butler_step = butler.ButlerStep.create(b, "zig-out/bin", branch);
    butler_step.step.dependOn(&exe.step);
    butler_step.step.dependOn(b.getInstallStep());

    const upload_step = b.step("upload", "Upload to itch");
    upload_step.dependOn(&butler_step.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
