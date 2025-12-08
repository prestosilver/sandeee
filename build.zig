const std = @import("std");

var version: std.SemanticVersion = .{
    .major = 0,
    .minor = 5,
    .patch = 0,
    .build = null,
};

pub fn addConvertFile(
    b: *std.Build,
    disk_step: *std.Build.Step.Run,
    converter: *std.Build.Step.Compile,
    args: []const []const u8,
    input: std.Build.LazyPath,
    disk_path: []const u8,
) void {
    const new_step = b.addRunArtifact(converter);
    new_step.addArgs(args);
    new_step.addFileArg(input);
    new_step.addFileInput(input);

    const slash = if (std.mem.lastIndexOf(u8, disk_path, "/")) |i| i + 1 else 0;

    const output_file = new_step.addOutputFileArg(disk_path[slash..]);
    disk_step.addArg("--file");
    disk_step.addFileInput(output_file);
    disk_step.addFileArg(output_file);
    disk_step.addArg(disk_path);
}

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "SandEEE",
        .root_module = exe_mod,
        .link_libc = true,
    });

    var commit = b.run(&.{ "git", "rev-list", "HEAD", "--count" });

    const is_demo = b.option(bool, "demo", "Makes SandEEE build a demo build") orelse false;
    const steam_mode = b.option(enum { Off, On, Fake }, "steam", "Makes SandEEE build a steam build") orelse .Off;
    const random_tests = b.option(i32, "random", "Makes SandEEE write some random files") orelse 0;
    const version_suffix = switch (optimize) {
        .Debug => if (is_demo) "D0DE" else "00DE",
        else => if (is_demo) "D000" else "0000",
    };

    const version_create_write = std.Build.Step.WriteFile.create(b);

    const version_file = version_create_write.add("VERSION", b.fmt("{}", .{version}));

    version.build = b.fmt("{s}-{X:0>4}", .{ version_suffix, std.fmt.parseInt(u64, commit[0 .. commit.len - 1], 0) catch 0 });

    const iversion_file = version_create_write.add("IVERSION", b.fmt("{}", .{version}));

    const version_write = b.addSystemCommand(&.{"cp"});
    version_write.addFileArg(version_file);
    version_write.addFileArg(b.path("VERSION"));

    version_write.step.dependOn(&version_create_write.step);

    const iversion_write = b.addSystemCommand(&.{"cp"});
    iversion_write.addFileArg(iversion_file);
    iversion_write.addFileArg(b.path("IVERSION"));

    iversion_write.step.dependOn(&version_create_write.step);

    const network_dependency = b.dependency("network", .{
        .target = target,
        .optimize = optimize,
    });
    const network_module = network_dependency.module("network");

    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });
    const zigimg_module = zigimg_dependency.module("zigimg");

    const steam_module = b.addModule("steam", .{
        .root_source_file = b.path("steam/steam.zig"),
    });

    const options = b.addOptions();

    const version_text = b.fmt("V_{{}}", .{});

    const content_path = b.path("content");
    const disk_path = content_path.path(b, ".tmp/disk");

    options.addOption(std.SemanticVersion, "SandEEEVersion", version);
    options.addOption([]const u8, "VersionText", version_text);
    options.addOption(bool, "IsDemo", is_demo);
    options.addOption(bool, "IsSteam", steam_mode != .Off);
    options.addOption(bool, "fakeSteam", steam_mode == .Fake);

    exe_mod.addImport("options", options.createModule());
    exe_mod.addImport("network", network_module);
    exe_mod.addImport("steam", steam_module);

    const image_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/disk.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    image_builder_mod.addImport("sandeee", exe_mod);
    image_builder_mod.addImport("options", options.createModule());
    const image_builder_exe = b.addExecutable(.{
        .name = "eee_builder",
        .root_module = image_builder_mod,
        .link_libc = true,
    });

    const asm_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/asm.zig"),
        .target = target,
        .link_libc = true,
    });
    asm_builder_mod.addImport("sandeee", exe_mod);
    asm_builder_mod.addImport("options", options.createModule());
    const asm_builder_exe = b.addExecutable(.{
        .name = "asm_builder",
        .root_module = asm_builder_mod,
        .link_libc = true,
    });

    const eia_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/eia.zig"),
        .target = target,
        .link_libc = true,
    });
    eia_builder_mod.addImport("sandeee", exe_mod);
    eia_builder_mod.addImport("zigimg", zigimg_module);
    eia_builder_mod.addImport("options", options.createModule());
    const eia_builder_exe = b.addExecutable(.{
        .name = "eia_builder",
        .root_module = eia_builder_mod,
        .link_libc = true,
    });

    const eff_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/eff.zig"),
        .target = target,
        .link_libc = true,
    });
    eff_builder_mod.addImport("sandeee", exe_mod);
    eff_builder_mod.addImport("zigimg", zigimg_module);
    eff_builder_mod.addImport("options", options.createModule());
    const eff_builder_exe = b.addExecutable(.{
        .name = "eff_builder",
        .root_module = eff_builder_mod,
        .link_libc = true,
    });

    const era_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/era.zig"),
        .target = target,
        .link_libc = true,
    });
    era_builder_mod.addImport("sandeee", exe_mod);
    era_builder_mod.addImport("options", options.createModule());
    const era_builder_exe = b.addExecutable(.{
        .name = "sandeee_era_builder",
        .root_module = era_builder_mod,
        .link_libc = true,
    });

    // Module setup done, remaining is disk image and final steps
    const clean_disk_step = b.addSystemCommand(&.{ "rm", "-rf", disk_path.getPath(b) });

    var skel_cmd: std.ArrayList([]const u8) = .init(b.allocator);
    defer skel_cmd.deinit();

    var disk_image_step = b.addRunArtifact(image_builder_exe);
    const disk_image_path = disk_image_step.addOutputFileArg("recovery.eee");

    const overlays_path = content_path.path(b, "overlays");

    {
        const paths_file = content_path.path(b, "overlays/paths.txt");
        disk_image_step.addFileInput(paths_file);
        const skel_file = try std.fs.openFileAbsolute(paths_file.getPath(b), .{});
        defer skel_file.close();

        const read = try skel_file.readToEndAlloc(b.allocator, 1000000);
        var iter = std.mem.splitScalar(u8, read, '\n');
        while (iter.next()) |line| {
            if (line.len == 0)
                continue;

            const first_space = std.mem.indexOf(u8, line, " ") orelse continue;

            if (std.mem.eql(u8, line[0..first_space], "debug") and optimize != .Debug)
                continue;
            if (std.mem.eql(u8, line[0..first_space], "steam") and steam_mode == .Off)
                continue;

            disk_image_step.addArg("--dir");
            disk_image_step.addArg(line[first_space + 1 ..]);
        }
    }

    {
        const base_path = overlays_path.path(b, "base");

        var dir = try std.fs.openDirAbsolute(base_path.getPath(b), .{ .iterate = true });
        defer dir.close();

        var iter = try dir.walk(b.allocator);

        while (try iter.next()) |path| {
            switch (path.kind) {
                .file => {
                    const p = base_path.path(b, path.path);

                    disk_image_step.addArg("--file");
                    disk_image_step.addFileInput(p);
                    disk_image_step.addFileArg(p);
                    disk_image_step.addArg(b.fmt("/{s}", .{path.path}));
                },
                else => {},
            }
        }
    }

    // debug files
    addConvertFile(b, disk_image_step, asm_builder_exe, &.{"exe"}, content_path.path(b, "asm/tests/hello.asm"), "/prof/tests/asm/hello.eep");

    // base images
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/email-logo.png"), "/cont/imgs/email-logo.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/icons.png"), "/cont/imgs/icons.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/ui.png"), "/cont/imgs/ui.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/bar.png"), "/cont/imgs/bar.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/iconsBig.png"), "/cont/imgs/iconsBig.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/window.png"), "/cont/imgs/window.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/wall1.png"), "/cont/imgs/wall1.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/wall2.png"), "/cont/imgs/wall2.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/wall3.png"), "cont/imgs/wall3.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/barlogo.png"), "cont/imgs/barlogo.eia");
    addConvertFile(b, disk_image_step, eia_builder_exe, &.{}, content_path.path(b, "images/cursor.png"), "cont/imgs/cursor.eia");

    // base audio
    addConvertFile(b, disk_image_step, era_builder_exe, &.{}, content_path.path(b, "audio/login.wav"), "cont/snds/login.era");
    addConvertFile(b, disk_image_step, era_builder_exe, &.{}, content_path.path(b, "audio/logout.wav"), "cont/snds/logout.era");
    addConvertFile(b, disk_image_step, era_builder_exe, &.{}, content_path.path(b, "audio/message.wav"), "cont/snds/message.era");

    // base fonts
    addConvertFile(b, disk_image_step, eff_builder_exe, &.{}, content_path.path(b, "images/SandEEESans.png"), "cont/fnts/SandEEESans.eff");

    const install_disk = b.addInstallFile(disk_image_path, "bin/content/recovery.eee");
    install_disk.step.dependOn(&disk_image_step.step);

    const disk_step = b.step("disk", "Builds the disk image");
    disk_step.dependOn(&install_disk.step);

    // cleanup temp files
    const clean_tmp = b.addSystemCommand(&.{ "rm", "-rf", "content/.tmp", ".zig-cache", "zig-out" });

    const clean_step = b.step("clean", "cleans the build env");
    clean_step.dependOn(&clean_tmp.step);
    clean_step.dependOn(&clean_disk_step.step);

    if (optimize == .Debug) {
        const debug_path = overlays_path.path(b, "debug");

        var dir = try std.fs.openDirAbsolute(debug_path.getPath(b), .{ .iterate = true });
        defer dir.close();

        var iter = try dir.walk(b.allocator);

        while (try iter.next()) |path| {
            switch (path.kind) {
                .file => {
                    const p = debug_path.path(b, path.path);

                    disk_image_step.addArg("--file");
                    disk_image_step.addFileInput(p);
                    disk_image_step.addFileArg(p);
                    disk_image_step.addArg(b.fmt("/{s}", .{path.path}));
                },
                else => {},
            }
        }
    }

    if (steam_mode != .Off) {
        const steam_path = overlays_path.path(b, "steam");

        var dir = try std.fs.openDirAbsolute(steam_path.getPath(b), .{ .iterate = true });
        defer dir.close();

        var iter = try dir.walk(b.allocator);

        while (try iter.next()) |path| {
            switch (path.kind) {
                .file => {
                    const p = steam_path.path(b, path.path);

                    disk_image_step.addArg("--file");
                    disk_image_step.addFileInput(p);
                    disk_image_step.addFileArg(p);
                    disk_image_step.addArg(path.path);
                },
                else => {},
            }
        }
    }

    // Includes
    exe.addIncludePath(b.path("deps/include"));
    exe.addIncludePath(b.path("deps/steam_sdk/public/"));
    if (target.result.os.tag == .windows) {
        exe.addObjectFile(b.path("content/app.res.obj"));
        exe.addLibraryPath(b.path("deps/lib"));
        exe.addLibraryPath(b.path("deps/steam_sdk/redistributable_bin/win64/"));
        exe.addObjectFile(b.path("deps/dll/libglfw3.dll"));
        exe.addObjectFile(b.path("deps/dll/libopenal.dll"));
        exe.subsystem = .Windows;
    } else {
        exe.addLibraryPath(b.path("deps/lib"));
        exe.addLibraryPath(b.path("deps/steam_sdk/redistributable_bin/linux64"));
        exe.addObjectFile(b.path("deps/lib/libglfw.so"));
        exe.addObjectFile(b.path("deps/lib/libopenal.so"));
    }

    // Sources
    exe.addCSourceFile(
        .{
            .file = b.path("deps/src/glad.c"),
            .flags = &[_][]const u8{"-std=c99"},
        },
    );

    if (steam_mode == .On) {
        if (target.result.os.tag == .windows)
            exe.linkSystemLibrary("steam_api64")
        else
            exe.linkSystemLibrary("steam_api");
    }
    exe.linkLibC();

    //const vm_dependency = b.dependency("sandeee_vm", .{
    //    .target = target,
    //    .optimize = optimize,
    //});

    //const vm_artifact = vm_dependency.artifact("eee");
    //const vm_install_a = b.addInstallArtifact(vm_artifact, .{ .dest_dir = .{ .override = .{ .custom = "bin/lib" } } });

    //b.getInstallStep().dependOn(&vm_install_a.step);

    //exe_mod.linkSystemLibrary("eee", .{});

    exe_mod.addLibraryPath(b.path("zig-out/bin/lib/"));

    b.installArtifact(exe);

    // const file_data = try std.mem.concat(b.allocator, DiskFile, &.{
    //     &BASE_FILES,
    //     if (!is_demo) &NONDEMO_FILES else &.{},
    //     if (optimize == .Debug) &DEBUG_FILES else &.{},
    //     if (steam_mode != .Off) &STEAM_FILES else &.{},
    // });

    // for (file_data) |file| {
    //     const root = if (file.file.converter == conv.copy)
    //         &skel_step.step
    //     else
    //         copy_libs_step;

    //     const step = try file.getStep(b, content_path, disk_path, root);

    //     if (file.file.converter == conv.copy) {
    //         copy_libs_step.dependOn(step);
    //     } else {
    //         content_step.dependOn(step);
    //     }
    // }

    // var lib_load_step = try conv.ConvertStep.create(b, comp.compile, &.{content_path.path(b, "asm/libs/libload.asm")}, disk_path.path(b, "libs/libload.eep"));
    // lib_load_step.step.dependOn(&skel_step.step);
    // content_step.dependOn(&lib_load_step.step);

    // const image_path = content_path.path(b, "images");
    // const internal_image_path = b.path("src/images");

    // inline for (INTERNAL_IMAGE_FILES) |file| {
    //     const pngf = image_path.path(b, file ++ ".png");
    //     const eiaf = internal_image_path.path(b, file ++ ".eia");

    //     var step = try conv.ConvertStep.create(b, image.convert, &.{pngf}, eiaf);

    //     content_step.dependOn(&step.step);
    // }

    // const audio_path = content_path.path(b, "audio");
    // const internal_audio_path = b.path("src/sounds");

    // inline for (INTERNAL_SOUND_FILES) |file| {
    //     const wavf = audio_path.path(b, file ++ ".wav");
    //     const eraf = internal_audio_path.path(b, file ++ ".era");

    //     var step = try conv.ConvertStep.create(b, sound.convert, &.{wavf}, eraf);

    //     content_step.dependOn(&step.step);
    // }

    _ = random_tests;
    // if (random_tests != 0) {
    //     _ = b.run(&[_][]const u8{ "mkdir", "-p", "content/disk/prof/tests/rand" });
    //     const filename = b.fmt("content/disk/prof/tests/rand/all.esh", .{});
    //     const count = b.fmt("{}", .{random_tests});

    //     var step = try conv.ConvertStep.create(b, rand.createScript, count, filename);

    //     step.step.dependOn(skel_step);
    //     content_step.dependOn(&step.step);
    // }

    // for (0..@intCast(random_tests)) |idx| {
    //     const filename = b.fmt("content/disk/prof/tests/rand/{}.eep", .{idx});

    //     var step = try conv.ConvertStep.create(b, rand.create, "", filename);

    //     step.step.dependOn(skel_step);
    //     content_step.dependOn(&step.step);
    // }

    // var font_joke_step = try conv.ConvertStep.create(
    //     b,
    //     font.convert,
    //     &.{image_path.path(b, "SandEEEJoke.png")},
    //     disk_path.path(b, "cont/fnts/SandEEEJoke.eff"),
    // );
    // var font_step = try conv.ConvertStep.create(
    //     b,
    //     font.convert,
    //     &.{image_path.path(b, "SandEEESans.png")},
    //     disk_path.path(b, "cont/fnts/SandEEESans.eff"),
    // );
    // var font_2x_step = try conv.ConvertStep.create(
    //     b,
    //     font.convert,
    //     &.{image_path.path(b, "SandEEESans2x.png")},
    //     disk_path.path(b, "cont/fnts/SandEEESans2x.eff"),
    // );
    // var font_bios_step = try conv.ConvertStep.create(
    //     b,
    //     font.convert,
    //     &.{image_path.path(b, "SandEEESans2x.png")},
    //     b.path("src/images/main.eff"),
    // );

    // font_joke_step.step.dependOn(&skel_step.step);
    // font_step.step.dependOn(&skel_step.step);
    // font_2x_step.step.dependOn(&skel_step.step);
    // font_bios_step.step.dependOn(&skel_step.step);

    // content_step.dependOn(&font_step.step);
    // content_step.dependOn(&font_joke_step.step);
    // content_step.dependOn(&font_2x_step.step);
    // content_step.dependOn(&font_bios_step.step);

    exe.step.dependOn(&version_write.step);
    exe.step.dependOn(&iversion_write.step);
    exe.step.dependOn(disk_step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addArgs(&[_][]const u8{ "--cwd", b.install_path });
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const headless_cmd = b.addRunArtifact(exe);
    headless_cmd.step.dependOn(b.getInstallStep());
    headless_cmd.addArgs(&[_][]const u8{ "--cwd", b.install_path, "--headless" });
    if (b.args) |args| {
        headless_cmd.addArgs(args);
    }

    if (target.result.os.tag == .windows) {
        _ = b.run(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/lib/" });
        b.installFile("deps/dll/libglfw3.dll", "bin/glfw3.dll");
        b.installFile("deps/dll/libgcc_s_seh-1.dll", "bin/libgcc_s_seh-1.dll");
        b.installFile("deps/dll/libstdc++-6.dll", "bin/libstdc++-6.dll");
        b.installFile("deps/dll/libopenal.dll", "bin/OpenAL32.dll");
        b.installFile("deps/dll/libssp-0.dll", "bin/libssp-0.dll");
        b.installFile("deps/dll/libwinpthread-1.dll", "bin/libwinpthread-1.dll");
        if (steam_mode == .On)
            b.installFile("deps/steam_sdk/redistributable_bin/win64/steam_api64.dll", "bin/steam_api64.dll");
    } else if (target.result.os.tag == .linux) {
        _ = b.run(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/lib/" });
        b.installFile("runSandEEE", "bin/runSandEEE");
        // b.installFile("deps/lib/libglfw.so.3", "bin/lib/libglfw.so.3");
        // b.installFile("deps/lib/libopenal.so.1", "bin/lib/libopenal.so.1");
        if (steam_mode == .On)
            b.installFile("deps/steam_sdk/redistributable_bin/linux64/libsteam_api.so", "bin/lib/libsteam_api.so");
    }

    if (steam_mode == .On and optimize == .Debug)
        b.installFile("steam_appid.txt", "bin/steam_appid.txt");

    // var count: usize = 0;

    // for (WWW_FILES) |file| {
    //     for (file.files) |_|
    //         count += 1;
    // }

    // const www_misc_step = b.step("www_misc", "Build www misc");

    // const download_step = try dwns.DownloadPageStep.create(b, &WWW_FILES, b.path("www/downloads.edf"));
    // www_misc_step.dependOn(&download_step.step);

    // const changelog_step = try changelog.ChangelogStep.create(b, "www/changelog.edf");
    // www_misc_step.dependOn(&changelog_step.step);

    // const docs_step = try docs.DocStep.create(b, "docs", "www/docs", "@/docs/");
    // www_misc_step.dependOn(&docs_step.step);

    // const www_files_step = b.step("www_files", "Build www files");
    // www_files_step.dependOn(www_misc_step);

    // for (WWW_FILES) |file| {
    //     const step = try file.getStep(b, content_path, b.path("www/downloads"), www_misc_step);

    //     www_files_step.dependOn(step);
    // }

    // const www_step = b.step("www", "Build the website");
    // www_step.dependOn(www_misc_step);
    // www_step.dependOn(www_files_step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const headless_step = b.step("headless", "Run the app headless");
    headless_step.dependOn(&version_write.step);
    headless_step.dependOn(&iversion_write.step);

    headless_step.dependOn(&headless_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    // const platform = switch (target.result.os.tag) {
    //     .windows => "win",
    //     .linux => "linux",
    //     else => "",
    // };

    // const suffix = switch (optimize) {
    //     .Debug => if (is_demo) "-dbg-new-demo" else "-dbg",
    //     else => if (is_demo) "-new-demo" else "",
    // };

    const run_exe_tests = b.addRunArtifact(exe_tests);

    // const branch = b.fmt("prestosilver/sandeee-os:{s}{s}", .{ platform, suffix });

    // const butler_step = try butler.ButlerStep.create(b, "zig-out/bin", branch);
    // butler_step.step.dependOn(&exe.step);
    // butler_step.step.dependOn(b.getInstallStep());

    // const upload_step = b.step("upload", "Upload to itch");
    // upload_step.dependOn(&butler_step.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);
}
