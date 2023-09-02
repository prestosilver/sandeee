const std = @import("std");
const mail = @import("src/system/mail.zig");
const comp = @import("tools/asm.zig");
const epk = @import("tools/epk.zig");
const sound = @import("tools/sound.zig");
const image = @import("tools/textures.zig");
const diskStep = @import("tools/disk.zig");
const conv = @import("tools/convert.zig");
const font = @import("tools/fonts.zig");
const eon = @import("tools/eon.zig");
const butler = @import("tools/butler.zig");
const emails = @import("tools/mail.zig");
const rand = @import("tools/random.zig");

// debug only
const asmTestsFiles = [_][]const u8{ "hello", "window", "texture", "fib", "arraytest", "audiotest", "tabletest" };
const eonTestsFiles = [_][]const u8{ "input", "color", "bugs", "tabletest", "heaptest", "stringtest", "paren" };
const eonTestSrcs = [_][]const u8{ "eon", "pix", "fib" };

// demo overrides
const mailDirsDemo = [_][]const u8{"inbox"};

// all builds
const asmExecFiles = [_][]const u8{ "time", "dump", "echo", "aplay", "libdump" };
const eonExecFiles = [_][]const u8{ "epkman", "eon", "stat", "player", "asm", "pix", "elib", "alib" };
const asmLibFiles = [_][]const u8{ "string", "window", "texture", "sound", "array" };
const eonLibFiles = [_][]const u8{ "ui", "heap", "table", "asm", "eon" };
const wavSoundFiles = [_][]const u8{ "login", "logout", "message" };
const pngImageFiles = [_][]const u8{ "icons", "ui", "notif", "bar", "iconsBig", "window", "wall", "barlogo", "cursor" };
const internalImageFiles = [_][]const u8{ "logo", "load", "sad", "bios", "error" };
const internalSoundFiles = [_][]const u8{ "bg", "bios-blip", "bios-select" };
const incLibsFiles = [_][]const u8{ "libload", "sys" };
const mailDirs = [_][]const u8{ "inbox", "spam", "private" };

// the website
const wwwFiles = [_]WWWStepData{
    .{
        .inputFiles = "content/eon/exec/pong.eon:/exec/pong.eep;" ++
            "content/images/pong.png:/cont/imgs/pong.eia;" ++
            "content/audio/pong-blip.wav:/cont/snds/pong-blip.era;" ++
            "content/elns/Pong.eln:/conf/apps/Pong.eln",
        .outputFile = "www/downloads/games/pong.epk",
        .converter = epk.convert,
    },
    .{
        .inputFiles = "content/eon/exec/connectris.eon:/exec/connectris.eep;" ++
            "content/images/connectris.png:/cont/imgs/connectris.eia;" ++
            "content/elns/Connectris.eln:/conf/apps/Connectris.eln",
        .outputFile = "www/downloads/games/connectris.epk",
        .converter = epk.convert,
    },
    .{
        .inputFiles = "content/eon/exec/paint.eon:/exec/paint.eep;" ++
            "content/images/transparent.png:/cont/imgs/transparent.eia;" ++
            "content/elns/Paint.eln:/conf/apps/Paint.eln",
        .outputFile = "www/downloads/tools/paint.epk",
        .converter = epk.convert,
    },
};

// www data
const WWWStepData = struct {
    inputFiles: []const u8,
    outputFile: []const u8,

    converter: *const fn ([]const u8, std.mem.Allocator) anyerror!std.ArrayList(u8),
};

var Version: std.SemanticVersion = .{
    .major = 0,
    .minor = 4,
    .patch = 1,
    .build = null,
};

pub fn build(b: *std.build.Builder) !void {
    const exe = b.addExecutable(.{
        .name = "SandEEE",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    var commit = b.exec(&.{ "git", "rev-list", "HEAD", "--count" });

    var isDemo = b.option(bool, "demo", "Makes SandEEE build a demo build") orelse false;
    var isSteam = b.option(bool, "steam", "Makes SandEEE build a steam build") orelse false;

    var randomTests = b.option(bool, "random", "Makes SandEEE write some random files") orelse false;

    const versionSuffix = switch (exe.optimize) {
        .Debug => if (isDemo) "D0DE" else "00DE",
        else => if (isDemo) "D000" else "0000",
    };

    std.fs.cwd().writeFile("VERSION", std.fmt.allocPrint(b.allocator, "{}", .{Version}) catch return) catch return;

    Version.build = b.fmt("{s}-{X:0>4}", .{ versionSuffix, std.fmt.parseInt(u64, commit[0 .. commit.len - 1], 0) catch 0 });

    std.fs.cwd().writeFile("IVERSION", std.fmt.allocPrint(b.allocator, "{}", .{Version}) catch return) catch return;

    const networkModule = b.createModule(.{
        .source_file = .{ .path = "deps/zig-network/network.zig" },
    });

    const steamModule = b.createModule(.{
        .source_file = .{ .path = "steam/steam.zig" },
    });

    const options = b.addOptions();

    var versionText = std.fmt.allocPrint(b.allocator, "V_{{}}", .{}) catch return;

    options.addOption(std.SemanticVersion, "SandEEEVersion", Version);
    options.addOption([]const u8, "VersionText", versionText);
    options.addOption(bool, "IsDemo", isDemo);
    options.addOption(bool, "IsSteam", isSteam);

    exe.addModule("network", networkModule);
    exe.addModule("steam", steamModule);
    exe.addModule("options", options.createModule());

    _ = b.exec(&[_][]const u8{ "rm", "-rf", "content/disk" });
    _ = b.exec(&[_][]const u8{ "cp", "-r", "content/rawdisk", "content/disk" });
    _ = b.exec(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/content" });
    _ = b.exec(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/disks" });
    if (exe.optimize == .Debug) {
        _ = b.exec(&[_][]const u8{ "cp", "-r", "content/disk_debug/prof", "content/disk" });
    }

    for (incLibsFiles) |file| {
        var eonf = std.fmt.allocPrint(b.allocator, "content/eon/libs/{s}.eon", .{file}) catch "";
        var libf = std.fmt.allocPrint(b.allocator, "content/disk/libs/inc/{s}.eon", .{file}) catch "";
        _ = b.exec(&.{ "cp", eonf, libf });
    }

    // Includes
    exe.addIncludePath(.{ .path = "deps/include" });
    exe.addIncludePath(.{ .path = "deps/steam_sdk/public/" });
    if (exe.target.os_tag != null and exe.target.os_tag.? == .windows) {
        exe.addObjectFile(.{ .path = "content/app.res.obj" });
        exe.addLibraryPath(.{ .path = "deps/lib" });
        exe.addLibraryPath(.{ .path = "deps/steam_sdk/redistributable_bin/win64" });
        exe.subsystem = .Windows;
    } else {
        exe.addLibraryPath(.{ .path = "deps/steam_sdk/redistributable_bin/linux64" });
    }

    // Sources
    exe.addCSourceFile(
        .{
            .file = .{
                .path = "deps/src/glad.c",
            },
            .flags = &[_][]const u8{"-std=c99"},
        },
    );

    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("OpenAL");
    exe.linkSystemLibrary("c");
    if (isSteam) {
        exe.linkSystemLibrary("steam_api");
    }
    exe.linkLibC();

    b.installArtifact(exe);

    var write_step = diskStep.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");

    for (if (isDemo) &mailDirsDemo else &mailDirs) |folder| {
        var input = std.fmt.allocPrint(b.allocator, "content/mail/{s}/", .{folder}) catch "";
        var output = std.fmt.allocPrint(b.allocator, "content/disk/cont/mail/{s}.eme", .{folder}) catch "";

        var step = conv.ConvertStep.create(b, emails.emails, input, output);
        write_step.step.dependOn(&step.step);
    }

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

        for (eonTestSrcs) |file| {
            var eonf = std.fmt.allocPrint(b.allocator, "content/eon/exec/{s}.eon", .{file}) catch "";
            var libf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/src/eon/{s}.eon", .{file}) catch "";
            _ = b.exec(&.{ "cp", eonf, libf });
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

    for (internalSoundFiles) |file| {
        var wavf = std.fmt.allocPrint(b.allocator, "content/audio/{s}.wav", .{file}) catch "";
        var eraf = std.fmt.allocPrint(b.allocator, "src/sounds/{s}.era", .{file}) catch "";

        var step = conv.ConvertStep.create(b, sound.convert, wavf, eraf);

        write_step.step.dependOn(&step.step);
    }

    if (randomTests) {
        for (0..100) |idx| {
            const filename = b.fmt("content/disk/prof/tests/rand/{}.eep", .{idx});

            var step = conv.ConvertStep.create(b, rand.create, "", filename);

            write_step.step.dependOn(&step.step);
        }
    }

    var fontStep = conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans.png", "content/disk/cont/fnts/SandEEESans.eff");
    var font2xStep = conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans2x.png", "content/disk/cont/fnts/SandEEESans2x.eff");
    var biosFontStep = conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans2x.png", "src/images/main.eff");

    write_step.step.dependOn(&fontStep.step);
    write_step.step.dependOn(&font2xStep.step);
    write_step.step.dependOn(&biosFontStep.step);

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
        if (isSteam)
            b.installFile("deps/steam_sdk/redistributable_bin/win64/steam_api64.dll", "bin/steam_api64.dll");
    } else if (exe.target.os_tag == null or exe.target.os_tag.? == .linux) {
        _ = b.exec(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/lib/" });
        b.installFile("runSandEEE", "bin/runSandEEE");
        b.installFile("deps/lib/libglfw.so.3", "bin/lib/libglfw.so.3");
        b.installFile("deps/lib/libopenal.so.1", "bin/lib/libopenal.so.1");
        if (isSteam)
            b.installFile("deps/steam_sdk/redistributable_bin/linux64/libsteam_api.so", "bin/lib/libsteam_api.so");
    }
    if (isSteam and exe.optimize == .Debug)
        b.installFile("steam_appid.txt", "bin/steam_appid.txt");

    const www_step = b.step("www", "Build the website");

    for (wwwFiles) |file| {
        const step = conv.ConvertStep.create(b, file.converter, file.inputFiles, file.outputFile);
        step.step.dependOn(&write_step.step);

        www_step.dependOn(&step.step);
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

    const platform = if (exe.target.os_tag) |tag|
        switch (tag) {
            .windows => "win",
            .linux => "linux",
            else => "",
        }
    else
        "linux";

    const suffix = switch (exe.optimize) {
        .Debug => if (isDemo) "-dbg-new-demo" else "-dbg",
        else => if (isDemo) "-new-demo" else "",
    };

    exe_tests.step.dependOn(&write_step.step);
    exe_tests.addModule("network", networkModule);
    exe_tests.addModule("options", options.createModule());

    const branch = std.fmt.allocPrint(b.allocator, "prestosilver/sandeee-os:{s}{s}", .{ platform, suffix }) catch "";

    const butler_step = butler.ButlerStep.create(b, "zig-out/bin", branch);
    butler_step.step.dependOn(&exe.step);
    butler_step.step.dependOn(b.getInstallStep());

    const upload_step = b.step("upload", "Upload to itch");
    upload_step.dependOn(&butler_step.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
