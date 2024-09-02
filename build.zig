const std = @import("std");
const mail = @import("src/system/mail.zig");
const comp = @import("tools/asm.zig");
const epk = @import("tools/epk.zig");
const sound = @import("tools/sound.zig");
const image = @import("tools/textures.zig");
const disk = @import("tools/disk.zig");
const conv = @import("tools/convert.zig");
const font = @import("tools/fonts.zig");
const eon = @import("tools/eon.zig");
const butler = @import("tools/butler.zig");
const emails = @import("tools/mail.zig");
const rand = @import("tools/random.zig");
const dwns = @import("tools/downloadpage.zig");
const changelog = @import("tools/changelog.zig");
const docs = @import("tools/docs.zig");

// debug only
const ASM_TEST_FILES = [_][]const u8{ "hello", "window", "texture", "fib", "arraytest", "audiotest", "tabletest" };
const EON_TEST_FILES = [_][]const u8{ "input", "color", "bugs", "tabletest", "heaptest", "stringtest", "paren" };
const EON_TEST_SRCS = [_][]const u8{ "eon", "pix", "fib" };

// demo overrides
const MAIL_DIRS_DEMO = [_][]const u8{"inbox"};

// all builds
const ASM_EXEC_FILES = [_][]const u8{ "time", "dump", "echo", "aplay", "libdump" };
const EON_EXEC_FILES = [_][]const u8{ "epkman", "eon", "stat", "player", "asm", "pix", "elib", "alib" };
const ASM_LIB_FILES = [_][]const u8{ "string", "window", "texture", "sound", "array" };
const EON_LIB_FILES = [_][]const u8{ "ui", "heap", "table", "asm", "eon" };
const WAV_SOUND_FILES = [_][]const u8{ "login", "logout", "message" };
const PNG_IMAGE_FILES = [_][]const u8{ "email-logo", "icons", "ui", "bar", "iconsBig", "window", "wall1", "wall2", "wall3", "barlogo", "cursor" };
const INTERNAL_IMAGE_FILES = [_][]const u8{ "logo", "load", "sad", "bios", "error" };
const INTERNAL_SOUND_FILES = [_][]const u8{ "bg", "bios-blip", "bios-select" };
const INC_LIBS_FILES = [_][]const u8{ "libload", "sys" };
const MAIL_DIRS = [_][]const u8{ "inbox", "spam", "private", "work" };
const ICON_IMAGE_FILES = [_][]const u8{ "eeedt", "tasks", "cmd", "settings", "launch", "debug", "logout", "folder", "email", "web" };

// the website
const WWW_FILES = [_]WWWStepData{
    .{
        // pong
        .input_files = &.{
            "content/eon/exec/pong.eon:/exec/pong.eep",
            "content/images/pong.png:/cont/imgs/pong.eia",
            "content/images/icons/pong.png:/cont/icns/pong.eia",
            "content/audio/pong-blip.wav:/cont/snds/pong-blip.era",
            "content/elns/Pong.eln:/conf/apps/Pong.eln",
        },
        .output_file = "www/downloads/games/pong.epk",
        .converter = epk.convert,
        .download_label = "Games",
    },
    .{
        // connectris
        .input_files = &.{
            "content/eon/exec/connectris.eon:/exec/connectris.eep",
            "content/images/connectris.png:/cont/imgs/connectris.eia",
            "content/images/icons/connectris.png:/cont/icns/connectris.eia",
            "content/elns/Connectris.eln:/conf/apps/Connectris.eln",
        },
        .output_file = "www/downloads/games/connectris.epk",
        .converter = epk.convert,
        .download_label = "Games",
    },
    .{
        // paint
        .input_files = &.{
            "content/eon/exec/paint.eon:/exec/paint.eep",
            "content/images/transparent.png:/cont/imgs/transparent.eia",
            "content/elns/Paint.eln:/conf/apps/Paint.eln",
            "content/images/icons/paint.png:/cont/icns/paint.eia",
        },
        .output_file = "www/downloads/tools/paint.epk",
        .converter = epk.convert,
        .download_label = "Tools",
    },
    .{
        // wallpaper wood
        .input_files = &.{"content/images/wood.png"},
        .output_file = "www/downloads/wallpapers/wood.eia",
        .converter = image.convert,
        .download_label = "Wallpapers",
    },
    .{
        // wallpaper wood
        .input_files = &.{"content/images/capy.png"},
        .output_file = "www/downloads/wallpapers/capy.eia",
        .converter = image.convert,
        .download_label = "Wallpapers",
    },
};

// www data
const WWWStepData = struct {
    input_files: []const []const u8,
    output_file: []const u8,

    download_label: ?[]const u8,

    converter: *const fn ([]const []const u8, std.mem.Allocator) anyerror!std.ArrayList(u8),
};

var version: std.SemanticVersion = .{
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
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    var commit = b.run(&.{ "git", "rev-list", "HEAD", "--count" });

    const is_demo = b.option(bool, "demo", "Makes SandEEE build a demo build") orelse false;
    const steam_mode = b.option(enum { Off, On, Fake }, "steam", "Makes SandEEE build a steam build") orelse .Off;
    const random_tests = b.option(i32, "random", "Makes SandEEE write some random files") orelse 0;
    const version_suffix = switch (optimize) {
        .Debug => if (is_demo) "D0DE" else "00DE",
        else => if (is_demo) "D000" else "0000",
    };

    std.fs.cwd().writeFile(.{
        .sub_path = "VERSION",
        .data = std.fmt.allocPrint(b.allocator, "{}", .{version}) catch return,
    }) catch return;

    version.build = b.fmt("{s}-{X:0>4}", .{ version_suffix, std.fmt.parseInt(u64, commit[0 .. commit.len - 1], 0) catch 0 });

    std.fs.cwd().writeFile(.{
        .sub_path = "IVERSION",
        .data = std.fmt.allocPrint(b.allocator, "{}", .{version}) catch return,
    }) catch return;

    const network_module = b.addModule("network", .{
        .root_source_file = b.path("deps/zig-network/network.zig"),
    });

    const steam_module = b.addModule("steam", .{
        .root_source_file = b.path("steam/steam.zig"),
    });

    const options = b.addOptions();

    const version_text = std.fmt.allocPrint(b.allocator, "V_{{}}", .{}) catch return;

    options.addOption(std.SemanticVersion, "SandEEEVersion", version);
    options.addOption([]const u8, "VersionText", version_text);
    options.addOption(bool, "IsDemo", is_demo);
    options.addOption(bool, "IsSteam", steam_mode != .Off);
    options.addOption(bool, "fakeSteam", steam_mode == .Fake);

    exe.root_module.addImport("options", options.createModule());
    exe.root_module.addImport("steam", steam_module);
    exe.root_module.addImport("network", network_module);

    const clean_step = b.step("clean", "cleans the build env");
    const content_step = b.step("content", "builds the content folder");

    // cleanup
    {
        const rm_disk_step = b.addSystemCommand(&.{ "rm", "-rf", "content/disk", "content/asm/eon" });
        clean_step.dependOn(&rm_disk_step.step);
    }

    var disk_step = try disk.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");
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
        var dir = try std.fs.cwd().openDir("content/overlays/debug/", .{ .iterate = true });
        var iter = dir.iterate();

        while (try iter.next()) |path| {
            const p = try std.mem.concat(b.allocator, u8, &.{ "content/overlays/debug/", path.name });
            defer b.allocator.free(p);

            const debug_overlay = b.addSystemCommand(&.{ "cp", "-r", p, "content/disk" });

            debug_overlay.step.dependOn(&skel.step);

            copy_disk.dependOn(&debug_overlay.step);
        }
    }

    if (steam_mode != .Off) {
        var dir = try std.fs.cwd().openDir("content/overlays/steam/", .{ .iterate = true });
        var iter = dir.iterate();

        while (try iter.next()) |path| {
            const p = try std.mem.concat(b.allocator, u8, &.{ "content/overlays/steam/", path.name });
            defer b.allocator.free(p);

            const steam_overlay = b.addSystemCommand(&.{ "cp", "-r", p, "content/disk" });

            steam_overlay.step.dependOn(&skel.step);

            copy_disk.dependOn(&steam_overlay.step);
        }
    }

    for (INC_LIBS_FILES) |file| {
        const eonf = std.fmt.allocPrint(b.allocator, "content/eon/libs/{s}.eon", .{file}) catch "";
        const libf = std.fmt.allocPrint(b.allocator, "content/disk/libs/inc/{s}.eon", .{file}) catch "";

        const copy_step = b.addSystemCommand(&.{ "cp", eonf, libf });

        copy_step.step.dependOn(copy_disk);
        copy_libs.dependOn(&copy_step.step);
    }

    // Includes
    exe.addIncludePath(b.path("deps/include"));
    exe.addIncludePath(b.path("deps/steam_sdk/public/"));
    if (target.result.os.tag == .windows) {
        exe.addObjectFile(b.path("content/app.res.obj"));
        exe.addLibraryPath(b.path("deps/lib"));
        exe.addLibraryPath(b.path("deps/steam_sdk/redistributable_bin/win64"));
        exe.subsystem = .Windows;
    } else {
        exe.addLibraryPath(b.path("deps/steam_sdk/redistributable_bin/linux64"));
    }

    // Sources
    exe.addCSourceFile(
        .{
            .file = b.path("deps/src/glad.c"),
            .flags = &[_][]const u8{"-std=c99"},
        },
    );

    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("OpenAL");
    if (steam_mode == .On) {
        exe.linkSystemLibrary("steam_api");
    }
    exe.linkLibC();

    b.installArtifact(exe);

    for (if (is_demo) &MAIL_DIRS_DEMO else &MAIL_DIRS) |folder| {
        const input = std.fmt.allocPrint(b.allocator, "content/mail/{s}/", .{folder}) catch "";
        const output = std.fmt.allocPrint(b.allocator, "content/disk/cont/mail/{s}.eme", .{folder}) catch "";

        var step = try conv.ConvertStep.create(b, emails.emails, input, output);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    if (optimize == .Debug) {
        for (ASM_TEST_FILES) |file| {
            const asmf = std.fmt.allocPrint(b.allocator, "content/asm/tests/{s}.asm", .{file}) catch "";
            const eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/asm/{s}.eep", .{file}) catch "";

            var step = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);
            step.step.dependOn(copy_disk);
            content_step.dependOn(&step.step);
        }

        for (EON_TEST_FILES) |file| {
            const eonf = std.fmt.allocPrint(b.allocator, "content/eon/tests/{s}.eon", .{file}) catch "";
            const asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/exec/{s}.asm", .{file}) catch "";
            const eepf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/eon/{s}.eep", .{file}) catch "";

            var comp_step = try conv.ConvertStep.create(b, eon.compileEon, eonf, asmf);
            comp_step.step.dependOn(copy_libs);

            var step = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);
            step.step.dependOn(&comp_step.step);

            content_step.dependOn(&step.step);
        }

        for (EON_TEST_SRCS) |file| {
            const eonf = std.fmt.allocPrint(b.allocator, "content/eon/exec/{s}.eon", .{file}) catch "";
            const libf = std.fmt.allocPrint(b.allocator, "content/disk/prof/tests/src/eon/{s}.eon", .{file}) catch "";

            const step = b.addSystemCommand(&.{ "cp", eonf, libf });

            step.step.dependOn(copy_disk);
            copy_libs.dependOn(&step.step);
        }
    }

    for (ASM_EXEC_FILES) |file| {
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/exec/{s}.asm", .{file}) catch "";
        const eepf = std.fmt.allocPrint(b.allocator, "content/disk/exec/{s}.eep", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (EON_EXEC_FILES) |file| {
        const eonf = std.fmt.allocPrint(b.allocator, "content/eon/exec/{s}.eon", .{file}) catch "";
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/exec/{s}.asm", .{file}) catch "";
        const eepf = std.fmt.allocPrint(b.allocator, "content/disk/exec/{s}.eep", .{file}) catch "";

        var adds = try conv.ConvertStep.create(b, comp.compile, asmf, eepf);
        var comp_step = try conv.ConvertStep.create(b, eon.compileEon, eonf, asmf);

        comp_step.step.dependOn(copy_libs);

        adds.step.dependOn(&comp_step.step);
        content_step.dependOn(&adds.step);
    }

    var lib_load_step = try conv.ConvertStep.create(b, comp.compile, "content/asm/libs/libload.asm", "content/disk/libs/libload.eep");
    lib_load_step.step.dependOn(copy_disk);
    content_step.dependOn(&lib_load_step.step);

    for (ASM_LIB_FILES) |file| {
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/libs/{s}.asm", .{file}) catch "";
        const ellf = std.fmt.allocPrint(b.allocator, "content/disk/libs/{s}.ell", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, comp.compileLib, asmf, ellf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (EON_LIB_FILES) |file| {
        const eonf = std.fmt.allocPrint(b.allocator, "content/eon/libs/{s}.eon", .{file}) catch "";
        const asmf = std.fmt.allocPrint(b.allocator, "content/asm/eon/libs/{s}.asm", .{file}) catch "";
        const ellf = std.fmt.allocPrint(b.allocator, "content/disk/libs/{s}.ell", .{file}) catch "";

        var comp_step = try conv.ConvertStep.create(b, eon.compileEonLib, eonf, asmf);
        comp_step.step.dependOn(copy_libs);

        var adds = try conv.ConvertStep.create(b, comp.compileLib, asmf, ellf);
        adds.step.dependOn(&comp_step.step);
        content_step.dependOn(&adds.step);
    }

    for (WAV_SOUND_FILES) |file| {
        const wavf = std.fmt.allocPrint(b.allocator, "content/audio/{s}.wav", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/snds/{s}.era", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, sound.convert, wavf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (ICON_IMAGE_FILES) |file| {
        const pngf = std.fmt.allocPrint(b.allocator, "content/images/icons/{s}.png", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/icns/{s}.eia", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, image.convert, pngf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (PNG_IMAGE_FILES) |file| {
        const pngf = std.fmt.allocPrint(b.allocator, "content/images/{s}.png", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "content/disk/cont/imgs/{s}.eia", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, image.convert, pngf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (INTERNAL_IMAGE_FILES) |file| {
        const pngf = std.fmt.allocPrint(b.allocator, "content/images/{s}.png", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "src/images/{s}.eia", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, image.convert, pngf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (INTERNAL_SOUND_FILES) |file| {
        const wavf = std.fmt.allocPrint(b.allocator, "content/audio/{s}.wav", .{file}) catch "";
        const eraf = std.fmt.allocPrint(b.allocator, "src/sounds/{s}.era", .{file}) catch "";

        var step = try conv.ConvertStep.create(b, sound.convert, wavf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    if (random_tests != 0) {
        _ = b.run(&[_][]const u8{ "mkdir", "-p", "content/disk/prof/tests/rand" });
        const filename = b.fmt("content/disk/prof/tests/rand/all.esh", .{});
        const count = b.fmt("{}", .{random_tests});

        var step = try conv.ConvertStep.create(b, rand.createScript, count, filename);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    for (0..@intCast(random_tests)) |idx| {
        const filename = b.fmt("content/disk/prof/tests/rand/{}.eep", .{idx});

        var step = try conv.ConvertStep.create(b, rand.create, "", filename);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    var font_joke_step = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEEJoke.png", "content/disk/cont/fnts/SandEEEJoke.eff");
    var font_step = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans.png", "content/disk/cont/fnts/SandEEESans.eff");
    var font_2x_step = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans2x.png", "content/disk/cont/fnts/SandEEESans2x.eff");
    var bios_font_step = try conv.ConvertStep.create(b, font.convert, "content/images/SandEEESans2x.png", "src/images/main.eff");

    font_joke_step.step.dependOn(copy_disk);
    font_step.step.dependOn(copy_disk);
    font_2x_step.step.dependOn(copy_disk);
    bios_font_step.step.dependOn(copy_disk);

    content_step.dependOn(&font_step.step);
    content_step.dependOn(&font_joke_step.step);
    content_step.dependOn(&font_2x_step.step);
    content_step.dependOn(&bios_font_step.step);

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
        if (steam_mode == .On)
            b.installFile("deps/steam_sdk/redistributable_bin/win64/steam_api64.dll", "bin/steam_api64.dll");
    } else if (target.result.os.tag == .linux) {
        _ = b.run(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/lib/" });
        b.installFile("runSandEEE", "bin/runSandEEE");
        b.installFile("deps/lib/libglfw.so.3", "bin/lib/libglfw.so.3");
        b.installFile("deps/lib/libopenal.so.1", "bin/lib/libopenal.so.1");
        if (steam_mode == .On)
            b.installFile("deps/steam_sdk/redistributable_bin/linux64/libsteam_api.so", "bin/lib/libsteam_api.so");
    }

    if (steam_mode == .On and optimize == .Debug)
        b.installFile("steam_appid.txt", "bin/steam_appid.txt");

    const www_step = b.step("www", "Build the website");
    var count: usize = 0;

    for (WWW_FILES) |file| {
        if (file.download_label) |_|
            count += 1;
    }

    var input_files = try b.allocator.alloc([]const u8, count);
    const download_step: WWWStepData = .{
        .input_files = input_files,

        .output_file = "www/downloads.edf",
        .converter = dwns.create,

        .download_label = null,
    };

    var idx: usize = 0;
    for (WWW_FILES) |file| {
        const step = try conv.ConvertStep.createMulti(b, file.converter, file.input_files, file.output_file);
        step.step.dependOn(&disk_step.step);

        www_step.dependOn(&step.step);

        if (file.download_label) |label| {
            input_files[idx] = try std.fmt.allocPrint(b.allocator, "{s}:{s}", .{ label, file.output_file[4..] });
            idx += 1;
        }
    }

    {
        const file = download_step;

        const step = try conv.ConvertStep.createMulti(b, file.converter, file.input_files, file.output_file);
        step.step.dependOn(&disk_step.step);

        www_step.dependOn(&step.step);
    }

    {
        const step = try changelog.ChangelogStep.create(b, "www/changelog.edf");
        www_step.dependOn(&step.step);
    }

    {
        const docs_step = try docs.DocStep.create(b, "docs", "www/docs", "@/docs/");
        www_step.dependOn(&docs_step.step);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const headless_step = b.step("headless", "Run the app headless");
    headless_step.dependOn(&headless_cmd.step);

    const exe_tests = b.addTest(.{
        .name = "main-test",
        .root_source_file = b.path("src/main.zig"),
    });

    const platform = switch (target.result.os.tag) {
        .windows => "win",
        .linux => "linux",
        else => "",
    };

    const suffix = switch (optimize) {
        .Debug => if (is_demo) "-dbg-new-demo" else "-dbg",
        else => if (is_demo) "-new-demo" else "",
    };

    exe_tests.step.dependOn(&disk_step.step);
    exe_tests.root_module.addImport("options", options.createModule());
    exe_tests.root_module.addImport("network", network_module);
    exe_tests.root_module.addImport("steam", steam_module);

    const branch = std.fmt.allocPrint(b.allocator, "prestosilver/sandeee-os:{s}{s}", .{ platform, suffix }) catch "";

    const butler_step = try butler.ButlerStep.create(b, "zig-out/bin", branch);
    butler_step.step.dependOn(&exe.step);
    butler_step.step.dependOn(b.getInstallStep());

    const upload_step = b.step("upload", "Upload to itch");
    upload_step.dependOn(&butler_step.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
