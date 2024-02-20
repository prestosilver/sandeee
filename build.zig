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
const dwns = @import("tools/downloadpage.zig");

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
const pngImageFiles = [_][]const u8{ "icons", "ui", "bar", "iconsBig", "window", "wall1", "wall2", "wall3", "barlogo", "cursor" };
const internalImageFiles = [_][]const u8{ "logo", "load", "sad", "bios", "error" };
const internalSoundFiles = [_][]const u8{ "bg", "bios-blip", "bios-select" };
const incLibsFiles = [_][]const u8{ "libload", "sys" };
const mailDirs = [_][]const u8{ "inbox", "spam", "private" };
const iconImageFiles = [_][]const u8{ "eeedt", "tasks", "cmd", "settings", "launch", "debug", "logout", "folder", "email", "web" };

// the website
const wwwFiles = [_]WWWStepData{
    .{
        // pong
        .inputFiles = &.{
            "content/eon/exec/pong.eon:/exec/pong.eep",
            "content/images/pong.png:/cont/imgs/pong.eia",
            "content/images/icons/pong.png:/cont/icns/pong.eia",
            "content/audio/pong-blip.wav:/cont/snds/pong-blip.era",
            "content/elns/Pong.eln:/conf/apps/Pong.eln",
        },
        .outputFile = "www/downloads/games/pong.epk",
        .converter = epk.convert,
        .downloadLabel = "Games",
    },
    .{
        // connectris
        .inputFiles = &.{
            "content/eon/exec/connectris.eon:/exec/connectris.eep",
            "content/images/connectris.png:/cont/imgs/connectris.eia",
            "content/images/icons/connectris.png:/cont/icns/connectris.eia",
            "content/elns/Connectris.eln:/conf/apps/Connectris.eln",
        },
        .outputFile = "www/downloads/games/connectris.epk",
        .converter = epk.convert,
        .downloadLabel = "Games",
    },
    .{
        // paint
        .inputFiles = &.{
            "content/eon/exec/paint.eon:/exec/paint.eep",
            "content/images/transparent.png:/cont/imgs/transparent.eia",
            "content/elns/Paint.eln:/conf/apps/Paint.eln",
            "content/images/icons/paint.png:/cont/icns/paint.eia",
        },
        .outputFile = "www/downloads/tools/paint.epk",
        .converter = epk.convert,
        .downloadLabel = "Tools",
    },
    .{
        // wallpaper wood
        .inputFiles = &.{"content/images/wood.png"},
        .outputFile = "www/downloads/wallpapers/wood.eia",
        .converter = image.convert,
        .downloadLabel = "Wallpapers",
    },
    .{
        // wallpaper wood
        .inputFiles = &.{"content/images/capy.png"},
        .outputFile = "www/downloads/wallpapers/capy.eia",
        .converter = image.convert,
        .downloadLabel = "Wallpapers",
    },
};

// www data
const WWWStepData = struct {
    inputFiles: []const []const u8,
    outputFile: []const u8,

    downloadLabel: ?[]const u8,

    converter: *const fn ([]const []const u8, std.mem.Allocator) anyerror!std.ArrayList(u8),
};

var Version: std.SemanticVersion = .{
    .major = 0,
    .minor = 4,
    .patch = 3,
    .build = null,
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "SandEEE",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    var commit = b.run(&.{ "git", "rev-list", "HEAD", "--count" });

    const isDemo = b.option(bool, "demo", "Makes SandEEE build a demo build") orelse false;
    const isSteam = b.option(bool, "steam", "Makes SandEEE build a steam build") orelse false;
    const randomTests = b.option(i32, "random", "Makes SandEEE write some random files") orelse 0;
    const versionSuffix = switch (optimize) {
        .Debug => if (isDemo) "D0DE" else "00DE",
        else => if (isDemo) "D000" else "0000",
    };

    std.fs.cwd().writeFile("VERSION", std.fmt.allocPrint(b.allocator, "{}", .{Version}) catch return) catch return;

    Version.build = b.fmt("{s}-{X:0>4}", .{ versionSuffix, std.fmt.parseInt(u64, commit[0 .. commit.len - 1], 0) catch 0 });

    std.fs.cwd().writeFile("IVERSION", std.fmt.allocPrint(b.allocator, "{}", .{Version}) catch return) catch return;

    const networkModule = b.addModule("network", .{
        .root_source_file = .{ .path = "deps/zig-network/network.zig" },
    });

    const steamModule = b.addModule("steam", .{
        .root_source_file = .{ .path = "steam/steam.zig" },
    });

    const options = b.addOptions();

    const versionText = std.fmt.allocPrint(b.allocator, "V_{{}}", .{}) catch return;

    options.addOption(std.SemanticVersion, "SandEEEVersion", Version);
    options.addOption([]const u8, "VersionText", versionText);
    options.addOption(bool, "IsDemo", isDemo);
    options.addOption(bool, "IsSteam", isSteam);

    exe.root_module.addImport("options", options.createModule());
    exe.root_module.addImport("steam", steamModule);
    exe.root_module.addImport("network", networkModule);

    const clean_step = b.step("clean", "cleans the build env");
    const content_step = b.step("content", "builds the content folder");

    // cleanup
    {
        const rm_disk_step = b.addSystemCommand(&.{ "rm", "-rf", "content/disk", "content/asm/eon" });
        clean_step.dependOn(&rm_disk_step.step);
    }

    var disk_step = try diskStep.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");
    const copy_disk = &b.addSystemCommand(&.{"sync"}).step;

    const setup_out = b.addSystemCommand(&.{ "mkdir", "-p", "zig-out/bin/content", "zig-out/bin/disks" });
    const setup_eon = b.addSystemCommand(&.{ "mkdir", "-p", "content/asm/eon/exec", "content/asm/eon/libs" });

    setup_eon.step.dependOn(clean_step);

    disk_step.step.dependOn(content_step);

    content_step.dependOn(copy_disk);
    content_step.dependOn(&setup_out.step);

    const skel = b.addSystemCommand(&.{ "cp", "-r", "content/rawdisk", "content/disk" });
    skel.step.dependOn(clean_step);
    copy_disk.dependOn(&setup_eon.step);
    copy_disk.dependOn(&skel.step);

    const copy_libs = &b.addSystemCommand(&.{"sync"}).step;
    copy_libs.dependOn(&setup_eon.step);
    copy_libs.dependOn(&skel.step);

    if (optimize == .Debug) {
        const debug_prof = b.addSystemCommand(&.{ "cp", "-r", "content/disk_debug/prof", "content/disk" });
        const debug_conf = b.addSystemCommand(&.{ "cp", "-r", "content/disk_debug/conf", "content/disk" });

        debug_prof.step.dependOn(&skel.step);
        debug_conf.step.dependOn(&skel.step);

        copy_disk.dependOn(&debug_prof.step);
        copy_disk.dependOn(&debug_conf.step);
    }

    for (incLibsFiles) |file| {
        const eonf = std.fmt.allocPrint(b.allocator, "content/eon/libs/{s}.eon", .{file}) catch "";
        const libf = std.fmt.allocPrint(b.allocator, "content/disk/libs/inc/{s}.eon", .{file}) catch "";

        const copy_step = b.addSystemCommand(&.{ "cp", eonf, libf });

        copy_step.step.dependOn(copy_disk);
        copy_libs.dependOn(&copy_step.step);
    }

    // Includes
    exe.addIncludePath(.{ .path = "deps/include" });
    exe.addIncludePath(.{ .path = "deps/steam_sdk/public/" });
    if (target.result.os.tag == .windows) {
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
    if (isSteam) {
        exe.linkSystemLibrary("steam_api");
    }
    exe.linkLibC();

    b.installArtifact(exe);

    for (if (isDemo) &mailDirsDemo else &mailDirs) |folder| {
        const input = std.fmt.allocPrint(b.allocator, "content/mail/{s}/", .{folder}) catch "";
        const output = std.fmt.allocPrint(b.allocator, "content/disk/cont/mail/{s}.eme", .{folder}) catch "";

        var step = try conv.ConvertStep.create(b, emails.emails, input, output);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    if (optimize == .Debug) {
        for (asmTestsFiles) |file| {
            const asmf = std.fmt.allocPrint(b.allocator, "content/asm/tests/{s}.asm", .{file}) catch "";
            const eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/asm/{s}.eep", .{file}) catch "";

            var step = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);
            step.step.dependOn(copy_disk);
            content_step.dependOn(&step.step);
        }

        for (eonTestsFiles) |file| {
            const eonf = std.fmt.allocPrint(b.allocator, "content/eon/tests/{s}.eon", .{file}) catch "";
            const asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/exec/{s}.asm", .{file}) catch "";
            const eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/eon/{s}.eep", .{file}) catch "";

            var compStep = try conv.ConvertStep.create(b, eon.compileEon, eonf, asmf);
            compStep.step.dependOn(copy_libs);

            var step = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);
            step.step.dependOn(&compStep.step);

            content_step.dependOn(&step.step);
        }

        for (eonTestSrcs) |file| {
            const eonf = std.fmt.allocPrint(b.allocator, "content/eon/exec/{s}.eon", .{file}) catch "";
            const libf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/src/eon/{s}.eon", .{file}) catch "";

            const step = b.addSystemCommand(&.{ "cp", eonf, libf });

            step.step.dependOn(copy_disk);
            copy_libs.dependOn(&step.step);
        }
    }

    for (asmExecFiles) |file| {
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/exec/{s}.asm", .{file}) catch "";
        const eepf = std.fmt.allocPrint(b.allocator, "content/disk/exec/{s}.eep", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (eonExecFiles) |file| {
        const eonf = std.fmt.allocPrint(b.allocator, "content/eon/exec/{s}.eon", .{file}) catch "";
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/exec/{s}.asm", .{file}) catch "";
        const eepf = std.fmt.allocPrint(b.allocator, "content/disk/exec/{s}.eep", .{file}) catch "";

        var adds = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);
        var compStep = try conv.ConvertStep.create(b, eon.compileEon, eonf, asmf);

        compStep.step.dependOn(copy_libs);

        adds.step.dependOn(&compStep.step);
        content_step.dependOn(&adds.step);
    }

    var libLoadStep = try conv.ConvertStep.create(b, comp.compile, "content/asm/libs/libload.asm", "content/disk/libs/libload.eep");
    libLoadStep.step.dependOn(copy_disk);
    content_step.dependOn(&libLoadStep.step);

    for (asmLibFiles) |file| {
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/libs/{s}.asm", .{file}) catch "";
        const ellf = std.fmt.allocPrint(b.allocator, "content/disk/libs/{s}.ell", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, comp.compileLib, asmf, ellf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (eonLibFiles) |file| {
        const eonf = std.fmt.allocPrint(b.allocator, "content/eon/libs/{s}.eon", .{file}) catch "";
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/libs/{s}.asm", .{file}) catch "";
        const ellf = std.fmt.allocPrint(b.allocator, "content/disk/libs/{s}.ell", .{file}) catch "";

        var compStep = try conv.ConvertStep.create(b, eon.compileEonLib, eonf, asmf);
        compStep.step.dependOn(copy_libs);

        var adds = try conv.ConvertStep.create(b, comp.compileLib, asmf, ellf);
        adds.step.dependOn(&compStep.step);
        content_step.dependOn(&adds.step);
    }

    for (wavSoundFiles) |file| {
        const wavf = std.fmt.allocPrint(b.allocator, "content/audio/{s}.wav", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/snds/{s}.era", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, sound.convert, wavf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (iconImageFiles) |file| {
        const pngf = std.fmt.allocPrint(b.allocator, "content/images/icons/{s}.png", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/icns/{s}.eia", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, image.convert, pngf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (pngImageFiles) |file| {
        const pngf = std.fmt.allocPrint(b.allocator, "content/images/{s}.png", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/imgs/{s}.eia", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, image.convert, pngf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (internalImageFiles) |file| {
        const pngf = std.fmt.allocPrint(b.allocator, "content/images/{s}.png", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "src/images/{s}.eia", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, image.convert, pngf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (internalSoundFiles) |file| {
        const wavf = std.fmt.allocPrint(b.allocator, "content/audio/{s}.wav", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "src/sounds/{s}.era", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, sound.convert, wavf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    if (randomTests != 0) {
        _ = b.run(&[_][]const u8{ "mkdir", "-p", "content/disk/prof/tests/rand" });
        const filename = b.fmt("content/disk/prof/tests/rand/all.esh", .{});
        const count = b.fmt("{}", .{randomTests});

        var step = try conv.ConvertStep.create(b, rand.createScript, count, filename);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (0..@intCast(randomTests)) |idx| {
        const filename = b.fmt("content/disk/prof/tests/rand/{}.eep", .{idx});

        var step = try conv.ConvertStep.create(b, rand.create, "", filename);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    var fontJokeStep = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEEJoke.png", "content/disk/cont/fnts/SandEEEJoke.eff");
    var fontStep = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans.png", "content/disk/cont/fnts/SandEEESans.eff");
    var font2xStep = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans2x.png", "content/disk/cont/fnts/SandEEESans2x.eff");
    var biosFontStep = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans2x.png", "src/images/main.eff");

    fontJokeStep.step.dependOn(copy_disk);
    fontStep.step.dependOn(copy_disk);
    font2xStep.step.dependOn(copy_disk);
    biosFontStep.step.dependOn(copy_disk);

    content_step.dependOn(&fontStep.step);
    content_step.dependOn(&fontJokeStep.step);
    content_step.dependOn(&font2xStep.step);
    content_step.dependOn(&biosFontStep.step);

    exe.step.dependOn(&disk_step.step);

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

    if (target.result.os.tag == .windows) {
        b.installFile("deps/dll/glfw3.dll", "bin/glfw3.dll");
        b.installFile("deps/dll/libgcc_s_seh-1.dll", "bin/libgcc_s_seh-1.dll");
        b.installFile("deps/dll/libstdc++-6.dll", "bin/libstdc++-6.dll");
        b.installFile("deps/dll/OpenAL32.dll", "bin/OpenAL32.dll");
        b.installFile("deps/dll/libssp-0.dll", "bin/libssp-0.dll");
        b.installFile("deps/dll/libwinpthread-1.dll", "bin/libwinpthread-1.dll");
        if (isSteam)
            b.installFile("deps/steam_sdk/redistributable_bin/win64/steam_api64.dll", "bin/steam_api64.dll");
    } else if (target.result.os.tag == .linux) {
        _ = b.run(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/lib/" });
        b.installFile("runSandEEE", "bin/runSandEEE");
        b.installFile("deps/lib/libglfw.so.3", "bin/lib/libglfw.so.3");
        b.installFile("deps/lib/libopenal.so.1", "bin/lib/libopenal.so.1");
        if (isSteam)
            b.installFile("deps/steam_sdk/redistributable_bin/linux64/libsteam_api.so", "bin/lib/libsteam_api.so");
    }
    if (isSteam and optimize == .Debug)
        b.installFile("steam_appid.txt", "bin/steam_appid.txt");

    const www_step = b.step("www", "Build the website");

    {
        const changelog_step = b.addSystemCommand(&.{ "bash", "./changelog.sh" });

        www_step.dependOn(&changelog_step.step);
    }

    var count: usize = 0;

    for (wwwFiles) |file| {
        if (file.downloadLabel) |_|
            count += 1;
    }

    var inputFiles = try b.allocator.alloc([]const u8, count);
    const downloadStep: WWWStepData = .{
        .inputFiles = inputFiles,

        .outputFile = "www/downloads.edf",
        .converter = dwns.create,

        .downloadLabel = null,
    };

    var idx: usize = 0;
    for (wwwFiles) |file| {
        const step = try conv.ConvertStep.createMulti(b, file.converter, file.inputFiles, file.outputFile);
        step.step.dependOn(&disk_step.step);

        www_step.dependOn(&step.step);

        if (file.downloadLabel) |label| {
            inputFiles[idx] = try std.fmt.allocPrint(b.allocator, "{s}:{s}", .{ label, file.outputFile[4..] });
            idx += 1;
        }
    }

    {
        const file = downloadStep;

        const step = try conv.ConvertStep.createMulti(b, file.converter, file.inputFiles, file.outputFile);
        step.step.dependOn(&disk_step.step);

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

    const platform = switch (target.result.os.tag) {
        .windows => "win",
        .linux => "linux",
        else => "",
    };

    const suffix = switch (optimize) {
        .Debug => if (isDemo) "-dbg-new-demo" else "-dbg",
        else => if (isDemo) "-new-demo" else "",
    };

    exe_tests.step.dependOn(&disk_step.step);
    exe_tests.root_module.addImport("options", options.createModule());
    exe_tests.root_module.addImport("network", networkModule);
    exe_tests.root_module.addImport("steam", steamModule);

    const branch = std.fmt.allocPrint(b.allocator, "prestosilver/sandeee-os:{s}{s}", .{ platform, suffix }) catch "";

    const butler_step = try butler.ButlerStep.create(b, "zig-out/bin", branch);
    butler_step.step.dependOn(&exe.step);
    butler_step.step.dependOn(b.getInstallStep());

    const upload_step = b.step("upload", "Upload to itch");
    upload_step.dependOn(&butler_step.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
