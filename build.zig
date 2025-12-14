const std = @import("std");
const Version = @import("src/data/version.zig");

var version: Version = .{
    .program = "os",
    .phase = .seed,
    .index = 9,
};

// this will need to be readded, its for assets embeded in the executable
const INTERNAL_IMAGE_FILES = [_][]const u8{ "logo", "load", "sad", "bios", "error" };
const INTERNAL_SOUND_FILES = [_][]const u8{ "bg", "bios-blip", "bios-select" };

pub inline fn addOverlay(
    b: *std.Build,
    disk_steps: []const *std.Build.Step.Run,
    overlay_path: std.Build.LazyPath,
) void {
    var dir = std.fs.openDirAbsolute(overlay_path.getPath(b), .{ .iterate = true }) catch unreachable;
    defer dir.close();

    var iter = dir.walk(b.allocator) catch unreachable;
    while (iter.next() catch unreachable) |path| {
        switch (path.kind) {
            .file => addConvertFile(b, disk_steps, &.{}, &.{}, overlay_path.path(b, path.path), b.fmt("/{s}", .{path.path})),
            else => {},
        }
    }
}

pub inline fn addConvertFile(
    b: *std.Build,
    disk_steps: []const *std.Build.Step.Run,
    converters: []const *std.Build.Step.Compile,
    args: []const []const []const u8,
    input: std.Build.LazyPath,
    disk_path: []const u8,
) void {
    var current_file = input;

    inline for (converters, args, 0..) |converter, arg, idx| {
        const new_step = b.addRunArtifact(converter);
        new_step.addArgs(arg);
        new_step.addFileArg(current_file);
        new_step.addFileInput(current_file);

        const slash = if (std.mem.lastIndexOf(u8, disk_path, "/")) |i| i + 1 else 0;
        current_file = new_step.addOutputFileArg(b.fmt("{s}_{}", .{ disk_path[slash..], idx }));
    }

    for (disk_steps) |disk_step| {
        disk_step.addArg("--file");
        disk_step.addFileInput(current_file);
        disk_step.addFileArg(current_file);
        disk_step.addArg(disk_path);
    }
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

    const exe_host_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
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

    version.meta = b.fmt("{X:0>4}_{s}", .{ std.fmt.parseInt(u64, commit[0 .. commit.len - 1], 0) catch 0, version_suffix });

    const iversion_file = version_create_write.add("IVERSION", b.fmt("{}", .{version}));

    const version_write = b.addInstallFile(version_file, "../VERSION");
    const iversion_write = b.addInstallFile(iversion_file, "../IVERSION");

    const glfw_dependency = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    const glfw_module = glfw_dependency.module("glfw");

    const zgl_dependency = b.dependency("zgl", .{
        .target = target,
        .optimize = optimize,
    });
    const zgl_module = zgl_dependency.module("zgl");

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

    const www_path: std.Build.InstallDir = .{ .custom = "../www" };

    options.addOption(Version, "SandEEEVersion", version);
    options.addOption([]const u8, "VersionText", version_text);
    options.addOption(bool, "IsDemo", is_demo);
    options.addOption(bool, "IsSteam", steam_mode != .Off);
    options.addOption(bool, "fakeSteam", steam_mode == .Fake);
    const options_module = options.createModule();

    exe_mod.addImport("options", options_module);
    exe_mod.addImport("network", network_module);
    exe_mod.addImport("glfw", glfw_module);
    exe_mod.addImport("zgl", zgl_module);
    exe_mod.addImport("steam", steam_module);

    exe_host_mod.addImport("options", options_module);
    exe_host_mod.addImport("network", network_module);
    exe_host_mod.addImport("glfw", glfw_module);
    exe_host_mod.addImport("zgl", zgl_module);
    exe_host_mod.addImport("steam", steam_module);

    const image_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/disk.zig"),
        .target = b.graph.host,
        .optimize = optimize,
        .link_libc = true,
    });
    image_builder_mod.addImport("sandeee", exe_host_mod);
    image_builder_mod.addImport("options", options_module);
    const image_builder_exe = b.addExecutable(.{
        .name = "eee_builder",
        .root_module = image_builder_mod,
        .link_libc = true,
    });

    const eon_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/eon.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    eon_builder_mod.addImport("sandeee", exe_host_mod);
    eon_builder_mod.addImport("options", options_module);
    const eon_builder_exe = b.addExecutable(.{
        .name = "eon_builder",
        .root_module = eon_builder_mod,
        .link_libc = true,
    });

    const asm_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/asm.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    asm_builder_mod.addAnonymousImport("sandeee_operation", .{
        .root_source_file = b.path("src/system/vmoperation.zig"),
    });
    asm_builder_mod.addImport("options", options_module);
    const asm_builder_exe = b.addExecutable(.{
        .name = "asm_builder",
        .root_module = asm_builder_mod,
        .link_libc = true,
    });

    const eia_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/eia.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    eia_builder_mod.addImport("sandeee", exe_host_mod);
    eia_builder_mod.addImport("zigimg", zigimg_module);
    eia_builder_mod.addImport("options", options_module);
    const eia_builder_exe = b.addExecutable(.{
        .name = "eia_builder",
        .root_module = eia_builder_mod,
        .link_libc = true,
    });

    const epk_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/epk.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    epk_builder_mod.addImport("sandeee", exe_host_mod);
    epk_builder_mod.addImport("zigimg", zigimg_module);
    epk_builder_mod.addImport("options", options_module);
    const epk_builder_exe = b.addExecutable(.{
        .name = "epk_builder",
        .root_module = epk_builder_mod,
        .link_libc = true,
    });

    const eff_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/eff.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    eff_builder_mod.addImport("sandeee", exe_host_mod);
    eff_builder_mod.addImport("zigimg", zigimg_module);
    eff_builder_mod.addImport("options", options_module);
    const eff_builder_exe = b.addExecutable(.{
        .name = "eff_builder",
        .root_module = eff_builder_mod,
        .link_libc = true,
    });

    const era_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/era.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    era_builder_mod.addImport("sandeee", exe_host_mod);
    era_builder_mod.addImport("options", options_module);
    const era_builder_exe = b.addExecutable(.{
        .name = "era_builder",
        .root_module = era_builder_mod,
        .link_libc = true,
    });

    const changelog_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/edf/changelog.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    changelog_builder_mod.addImport("sandeee", exe_host_mod);
    changelog_builder_mod.addImport("options", options_module);
    const changelog_builder_exe = b.addExecutable(.{
        .name = "changelog_builder",
        .root_module = changelog_builder_mod,
        .link_libc = true,
    });

    const downloads_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/edf/downloads.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    downloads_builder_mod.addImport("sandeee", exe_host_mod);
    downloads_builder_mod.addImport("options", options_module);
    const downloads_builder_exe = b.addExecutable(.{
        .name = "downloads_builder",
        .root_module = downloads_builder_mod,
        .link_libc = true,
    });

    const docs_builder_mod = b.createModule(.{
        .root_source_file = b.path("tools/edf/docs.zig"),
        .target = b.graph.host,
        .link_libc = true,
    });
    docs_builder_mod.addImport("sandeee", exe_host_mod);
    docs_builder_mod.addImport("options", options_module);
    const docs_builder_exe = b.addExecutable(.{
        .name = "docs_builder",
        .root_module = docs_builder_mod,
        .link_libc = true,
    });

    // Module setup done, remaining is disk image and final steps
    var skel_cmd: std.ArrayList([]const u8) = .init(b.allocator);
    defer skel_cmd.deinit();

    var disk_image_step = b.addRunArtifact(image_builder_exe);
    const disk_image_path = disk_image_step.addOutputFileArg("disk_recovery.eee");
    var debug_image_step = b.addRunArtifact(image_builder_exe);
    const debug_image_path = debug_image_step.addOutputFileArg("debug_recovery.eee");
    var steam_image_step = b.addRunArtifact(image_builder_exe);
    const steam_image_path = steam_image_step.addOutputFileArg("steam_recovery.eee");

    const overlays_path = content_path.path(b, "overlays");

    {
        const paths_file = content_path.path(b, "overlays/paths.txt");
        disk_image_step.addFileInput(paths_file);
        steam_image_step.addFileInput(paths_file);
        const skel_file = try std.fs.openFileAbsolute(paths_file.getPath(b), .{});
        defer skel_file.close();

        const read = try skel_file.readToEndAlloc(b.allocator, 1000000);
        var iter = std.mem.splitScalar(u8, read, '\n');
        while (iter.next()) |line| {
            if (line.len == 0)
                continue;

            const first_space = std.mem.indexOf(u8, line, " ") orelse continue;

            if (std.mem.eql(u8, line[0..first_space], "debug")) {
                debug_image_step.addArg("--dir");
                debug_image_step.addArg(line[first_space + 1 ..]);
                continue;
            }

            if (std.mem.eql(u8, line[0..first_space], "steam") and steam_mode == .Off) {
                steam_image_step.addArg("--dir");
                steam_image_step.addArg(line[first_space + 1 ..]);
                continue;
            }

            steam_image_step.addArg("--dir");
            steam_image_step.addArg(line[first_space + 1 ..]);
            debug_image_step.addArg("--dir");
            debug_image_step.addArg(line[first_space + 1 ..]);
            disk_image_step.addArg("--dir");
            disk_image_step.addArg(line[first_space + 1 ..]);
        }
    }

    addOverlay(b, &.{ steam_image_step, disk_image_step, debug_image_step }, overlays_path.path(b, "base"));

    // debug files
    addConvertFile(b, &.{debug_image_step}, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/tests/hello.asm"), "/prof/tests/eep/asm/hello.eep");
    addConvertFile(b, &.{debug_image_step}, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/tests/window.asm"), "/prof/tests/eep/asm/window.eep");
    addConvertFile(b, &.{debug_image_step}, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/tests/texture.asm"), "/prof/tests/eep/asm/texture.eep");
    addConvertFile(b, &.{debug_image_step}, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/tests/fib.asm"), "/prof/tests/eep/asm/fib.eep");
    addConvertFile(b, &.{debug_image_step}, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/tests/arraytest.asm"), "/prof/tests/eep/asm/arraytest.eep");
    addConvertFile(b, &.{debug_image_step}, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/tests/audiotest.asm"), "/prof/tests/eep/asm/audiotest.eep");
    addConvertFile(b, &.{debug_image_step}, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/tests/tabletest.asm"), "/prof/tests/eep/asm/tabletest.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/input.eon"), "/prof/tests/eep/eon/input.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/console.eon"), "/prof/tests/eep/eon/console.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/color.eon"), "/prof/tests/eep/eon/color.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/bugs.eon"), "/prof/tests/eep/eon/bugs.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/tabletest.eon"), "/prof/tests/eep/eon/tabletest.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/heaptest.eon"), "/prof/tests/eep/eon/heaptest.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/stringtest.eon"), "/prof/tests/eep/eon/stringtest.eep");
    addConvertFile(b, &.{debug_image_step}, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/tests/paren.eon"), "/prof/tests/eep/eon/paren.eep");
    addConvertFile(b, &.{debug_image_step}, &.{}, &.{}, content_path.path(b, "eon/exec/eon.eon"), "/prof/tests/src/eon/eon.eon");
    addConvertFile(b, &.{debug_image_step}, &.{}, &.{}, content_path.path(b, "eon/libs/eon.eon"), "/prof/tests/src/eon/eon_lib.eon");
    addConvertFile(b, &.{debug_image_step}, &.{}, &.{}, content_path.path(b, "eon/exec/pix.eon"), "/prof/tests/src/eon/pix.eon");
    addConvertFile(b, &.{debug_image_step}, &.{}, &.{}, content_path.path(b, "eon/exec/pix.eon"), "/prof/tests/src/eon/fib.eon");
    addConvertFile(b, &.{debug_image_step}, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/debug.png"), "/cont/icns/debug.eia");
    addConvertFile(b, &.{debug_image_step}, &.{era_builder_exe}, &.{&.{}}, content_path.path(b, "audio/redbone.wav"), "/cont/snds/redbone.era");

    addConvertFile(b, &.{ debug_image_step, steam_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/steamtool.eon"), "/exec/steamtool.eep");

    // base images
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/email-logo.png"), "/cont/imgs/email-logo.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons.png"), "/cont/imgs/icons.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/ui.png"), "/cont/imgs/ui.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/bar.png"), "/cont/imgs/bar.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/iconsBig.png"), "/cont/imgs/iconsBig.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/window.png"), "/cont/imgs/window.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/wall1.png"), "/cont/imgs/wall1.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/wall2.png"), "/cont/imgs/wall2.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/wall3.png"), "/cont/imgs/wall3.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/barlogo.png"), "/cont/imgs/barlogo.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/cursor.png"), "/cont/imgs/cursor.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/web.png"), "/cont/icns/web.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/settings.png"), "/cont/icns/settings.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/logout.png"), "/cont/icns/logout.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/launch.png"), "/cont/icns/launch.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/cmd.png"), "/cont/icns/cmd.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/email.png"), "/cont/icns/email.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/folder.png"), "/cont/icns/folder.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/tasks.png"), "/cont/icns/tasks.eia");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eia_builder_exe}, &.{&.{}}, content_path.path(b, "images/icons/eeedt.png"), "/cont/icns/eeedt.eia");

    // base audio
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{era_builder_exe}, &.{&.{}}, content_path.path(b, "audio/login.wav"), "/cont/snds/login.era");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{era_builder_exe}, &.{&.{}}, content_path.path(b, "audio/logout.wav"), "/cont/snds/logout.era");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{era_builder_exe}, &.{&.{}}, content_path.path(b, "audio/message.wav"), "/cont/snds/message.era");

    // base fonts
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eff_builder_exe}, &.{&.{}}, content_path.path(b, "images/SandEEESans.png"), "/cont/fnts/SandEEESans.eff");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eff_builder_exe}, &.{&.{}}, content_path.path(b, "images/SandEEESans2x.png"), "/cont/fnts/SandEEESans2x.eff");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{eff_builder_exe}, &.{&.{}}, content_path.path(b, "images/SandEEEJoke.png"), "/cont/fnts/SandEEEJoke.eff");

    // executables
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/epkman.eon"), "/exec/epkman.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/eon.eon"), "/exec/eon.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/stat.eon"), "/exec/stat.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/player.eon"), "/exec/player.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/asm.eon"), "/exec/asm.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/pix.eon"), "/exec/pix.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/elib.eon"), "/exec/elib.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"exe"}, &.{"exe"} }, content_path.path(b, "eon/exec/alib.eon"), "/exec/alib.eep");

    // libraries
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"lib"}, &.{"lib"} }, content_path.path(b, "eon/libs/ui.eon"), "/libs/ui.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"lib"}, &.{"lib"} }, content_path.path(b, "eon/libs/heap.eon"), "/libs/heap.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"lib"}, &.{"lib"} }, content_path.path(b, "eon/libs/table.eon"), "/libs/table.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"lib"}, &.{"lib"} }, content_path.path(b, "eon/libs/asm.eon"), "/libs/asm.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{ eon_builder_exe, asm_builder_exe }, &.{ &.{"lib"}, &.{"lib"} }, content_path.path(b, "eon/libs/eon.eon"), "/libs/eon.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{asm_builder_exe}, &.{&.{"lib"}}, content_path.path(b, "asm/libs/string.asm"), "/libs/string.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{asm_builder_exe}, &.{&.{"lib"}}, content_path.path(b, "asm/libs/window.asm"), "/libs/window.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{asm_builder_exe}, &.{&.{"lib"}}, content_path.path(b, "asm/libs/texture.asm"), "/libs/texture.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{asm_builder_exe}, &.{&.{"lib"}}, content_path.path(b, "asm/libs/sound.asm"), "/libs/sound.ell");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{asm_builder_exe}, &.{&.{"lib"}}, content_path.path(b, "asm/libs/array.asm"), "/libs/array.ell");

    // includable libs
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{asm_builder_exe}, &.{&.{"exe"}}, content_path.path(b, "asm/libs/libload.asm"), "/libs/libload.eep");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{}, &.{}, content_path.path(b, "eon/libs/incl/sys.eon"), "/libs/incl/sys.eon");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{}, &.{}, content_path.path(b, "eon/libs/incl/libload.eon"), "/libs/incl/libload.eon");
    addConvertFile(b, &.{ debug_image_step, steam_image_step, disk_image_step }, &.{}, &.{}, content_path.path(b, "asm/libs/incl/libload.asm"), "/libs/incl/libload.asm");

    addOverlay(b, &.{steam_image_step}, overlays_path.path(b, "steam"));
    if (steam_mode != .Off)
        addOverlay(b, &.{ debug_image_step, steam_image_step, disk_image_step }, overlays_path.path(b, "steam"));

    const disk_step = b.step("disk", "Builds the disk image");
    if (optimize == .Debug) {
        const install_disk = b.addInstallFile(debug_image_path, "bin/content/recovery.eee");
        disk_step.dependOn(&install_disk.step);
    } else {
        const install_disk = b.addInstallFile(disk_image_path, "bin/content/recovery.eee");
        disk_step.dependOn(&install_disk.step);
    }

    addOverlay(b, &.{debug_image_step}, overlays_path.path(b, "debug"));

    const resFileStep = b.addSystemCommand(&.{"x86_64-w64-mingw32-windres"});
    resFileStep.addFileInput(content_path.path(b, "data/app.rc"));
    resFileStep.addFileArg(content_path.path(b, "data/app.rc"));
    const rc_file = resFileStep.addOutputFileArg("app.rc.o");

    // Includes
    exe.addIncludePath(b.path("deps/include"));
    exe.addIncludePath(b.path("deps/steam_sdk/public/"));
    if (target.result.os.tag == .windows) {
        exe.addObjectFile(rc_file);
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

    if (steam_mode == .On) {
        if (target.result.os.tag == .windows)
            exe.linkSystemLibrary("steam_api64")
        else
            exe.linkSystemLibrary("steam_api");
    }
    exe.linkLibC();

    b.installArtifact(exe);

    const image_path = content_path.path(b, "images");

    inline for (INTERNAL_IMAGE_FILES) |file| {
        const pngf = image_path.path(b, file ++ ".png");
        const eiaf = file ++ ".eia";

        const builder = b.addRunArtifact(eia_builder_exe);
        builder.addFileInput(pngf);
        builder.addFileArg(pngf);

        const output_file = builder.addOutputFileArg(eiaf);

        exe_mod.addAnonymousImport(eiaf, .{
            .root_source_file = output_file,
        });
    }

    const audio_path = content_path.path(b, "audio");

    inline for (INTERNAL_SOUND_FILES) |file| {
        const wavf = audio_path.path(b, file ++ ".wav");
        const eraf = file ++ ".era";

        const builder = b.addRunArtifact(era_builder_exe);
        builder.addFileInput(wavf);
        builder.addFileArg(wavf);
        const output_file = builder.addOutputFileArg(eraf);

        exe_mod.addAnonymousImport(eraf, .{
            .root_source_file = output_file,
        });
    }

    {
        const bios_font_path = image_path.path(b, "SandEEESans2x.png");

        const builder = b.addRunArtifact(eff_builder_exe);
        builder.addFileInput(bios_font_path);
        builder.addFileArg(bios_font_path);
        const output_file = builder.addOutputFileArg("bios.eff");

        exe_mod.addAnonymousImport("bios.eff", .{
            .root_source_file = output_file,
        });
    }

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
    b.getInstallStep().dependOn(disk_step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addArgs(&[_][]const u8{"--cwd"});
    run_cmd.addFileArg(b.path("zig-out/bin/"));
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const headless_cmd = b.addRunArtifact(exe);
    headless_cmd.step.dependOn(b.getInstallStep());
    headless_cmd.addArgs(&[_][]const u8{"--cwd"});
    headless_cmd.addFileArg(b.path("zig-out/bin/"));
    headless_cmd.addArg("--headless");
    if (b.args) |args| {
        headless_cmd.addArgs(args);
    }

    if (target.result.os.tag == .windows) {
        b.installFile("deps/dll/libglfw3.dll", "bin/glfw3.dll");
        b.installFile("deps/dll/libgcc_s_seh-1.dll", "bin/libgcc_s_seh-1.dll");
        b.installFile("deps/dll/libstdc++-6.dll", "bin/libstdc++-6.dll");
        b.installFile("deps/dll/libopenal.dll", "bin/OpenAL32.dll");
        b.installFile("deps/dll/libssp-0.dll", "bin/libssp-0.dll");
        b.installFile("deps/dll/libwinpthread-1.dll", "bin/libwinpthread-1.dll");
        if (steam_mode == .On)
            b.installFile("deps/steam_sdk/redistributable_bin/win64/steam_api64.dll", "bin/steam_api64.dll");
    } else if (target.result.os.tag == .linux) {
        b.installFile("runSandEEE", "bin/runSandEEE");
        if (steam_mode == .On)
            b.installFile("deps/steam_sdk/redistributable_bin/linux64/libsteam_api.so", "bin/lib/libsteam_api.so");
    }

    if (steam_mode == .On)
        b.installFile("steam_appid.txt", "bin/steam_appid.txt");

    const www_misc_step = b.step("www_misc", "Build www misc");

    const changelog_step = b.addRunArtifact(changelog_builder_exe);
    changelog_step.addFileInput(b.path("VERSION"));
    changelog_step.addFileArg(b.path("VERSION"));

    changelog_step.addFileInput(content_path.path(b, "data/os_versions.csv"));
    changelog_step.addFileArg(content_path.path(b, "data/os_versions.csv"));

    const changelog_file_path = changelog_step.addOutputFileArg("changelog.edf");
    const install_changelog = b.addInstallFileWithDir(changelog_file_path, www_path, "changelog.edf");
    www_misc_step.dependOn(&install_changelog.step);

    const docs_step = b.addRunArtifact(docs_builder_exe);
    docs_step.addArg("@/docs/");
    docs_step.addDirectoryArg(b.path("docs"));
    docs_step.addDirectoryArg(b.path("www/docs"));
    www_misc_step.dependOn(&docs_step.step);

    const wood_wallpaper_step = b.addRunArtifact(eia_builder_exe);
    wood_wallpaper_step.addFileInput(content_path.path(b, "images/wood.png"));
    wood_wallpaper_step.addFileArg(content_path.path(b, "images/wood.png"));
    const wood_wallpaper_path = wood_wallpaper_step.addOutputFileArg("wood.eia");

    const capy_wallpaper_step = b.addRunArtifact(eia_builder_exe);
    capy_wallpaper_step.addFileInput(content_path.path(b, "images/capy.png"));
    capy_wallpaper_step.addFileArg(content_path.path(b, "images/capy.png"));
    const capy_wallpaper_path = capy_wallpaper_step.addOutputFileArg("wood.eia");

    const pong_app_step = b.addRunArtifact(epk_builder_exe);
    const pong_app_file_path = pong_app_step.addOutputFileArg("pong.epk");
    {
        const pong_image_step = b.addRunArtifact(eia_builder_exe);
        pong_image_step.addFileInput(content_path.path(b, "images/pong.png"));
        pong_image_step.addFileArg(content_path.path(b, "images/pong.png"));
        const pong_image_file = pong_image_step.addOutputFileArg("pong.eia");

        pong_app_step.addArgs(&.{ "--file", "/cont/imgs/pong.eia" });
        pong_app_step.addFileInput(pong_image_file);
        pong_app_step.addFileArg(pong_image_file);

        const pong_icon_step = b.addRunArtifact(eia_builder_exe);
        pong_icon_step.addFileInput(content_path.path(b, "images/icons/pong.png"));
        pong_icon_step.addFileArg(content_path.path(b, "images/icons/pong.png"));
        const pong_icon_file = pong_icon_step.addOutputFileArg("pong.eia");

        pong_app_step.addArgs(&.{ "--file", "/cont/icns/pong.eia" });
        pong_app_step.addFileInput(pong_icon_file);
        pong_app_step.addFileArg(pong_icon_file);

        const pong_blip_step = b.addRunArtifact(era_builder_exe);
        pong_blip_step.addFileInput(content_path.path(b, "audio/pong-blip.wav"));
        pong_blip_step.addFileArg(content_path.path(b, "audio/pong-blip.wav"));
        const pong_blip_file = pong_blip_step.addOutputFileArg("pong-blip.era");

        pong_app_step.addArgs(&.{ "--file", "/cont/snds/pong-blip.era" });
        pong_app_step.addFileInput(pong_blip_file);
        pong_app_step.addFileArg(pong_blip_file);

        const pong_eon_step = b.addRunArtifact(eon_builder_exe);
        pong_eon_step.addArg("exe");
        pong_eon_step.addFileInput(content_path.path(b, "eon/exec/pong.eon"));
        pong_eon_step.addFileArg(content_path.path(b, "eon/exec/pong.eon"));
        const pong_asm_file = pong_eon_step.addOutputFileArg("pong.eon");

        const pong_asm_step = b.addRunArtifact(asm_builder_exe);
        pong_asm_step.addArg("exe");
        pong_asm_step.addFileInput(pong_asm_file);
        pong_asm_step.addFileArg(pong_asm_file);
        const pong_exec_file = pong_asm_step.addOutputFileArg("pong.eep");

        pong_app_step.addArgs(&.{ "--file", "/exec/pong.eep" });
        pong_app_step.addFileInput(pong_exec_file);
        pong_app_step.addFileArg(pong_exec_file);

        pong_app_step.addArgs(&.{ "--file", "/conf/apps/Pong.eln" });
        pong_app_step.addFileInput(content_path.path(b, "elns/Pong.eln"));
        pong_app_step.addFileArg(content_path.path(b, "elns/Pong.eln"));
    }

    const paint_app_step = b.addRunArtifact(epk_builder_exe);
    const paint_app_file_path = paint_app_step.addOutputFileArg("paint.epk");
    {
        const paint_timage_step = b.addRunArtifact(eia_builder_exe);
        paint_timage_step.addFileInput(content_path.path(b, "images/transparent.png"));
        paint_timage_step.addFileArg(content_path.path(b, "images/transparent.png"));
        const paint_timage_file = paint_timage_step.addOutputFileArg("transparent.eia");

        paint_app_step.addArgs(&.{ "--file", "/cont/imgs/transparent.eia" });
        paint_app_step.addFileInput(paint_timage_file);
        paint_app_step.addFileArg(paint_timage_file);

        const paint_icon_step = b.addRunArtifact(eia_builder_exe);
        paint_icon_step.addFileInput(content_path.path(b, "images/icons/paint.png"));
        paint_icon_step.addFileArg(content_path.path(b, "images/icons/paint.png"));
        const paint_icon_file = paint_icon_step.addOutputFileArg("paint.eia");

        paint_app_step.addArgs(&.{ "--file", "/cont/icns/paint.eia" });
        paint_app_step.addFileInput(paint_icon_file);
        paint_app_step.addFileArg(paint_icon_file);

        const paint_eon_step = b.addRunArtifact(eon_builder_exe);
        paint_eon_step.addArg("exe");
        paint_eon_step.addFileInput(content_path.path(b, "eon/exec/paint.eon"));
        paint_eon_step.addFileArg(content_path.path(b, "eon/exec/paint.eon"));
        const paint_asm_file = paint_eon_step.addOutputFileArg("paint.eon");

        const paint_asm_step = b.addRunArtifact(asm_builder_exe);
        paint_asm_step.addArg("exe");
        paint_asm_step.addFileInput(paint_asm_file);
        paint_asm_step.addFileArg(paint_asm_file);
        const paint_exec_file = paint_asm_step.addOutputFileArg("paint.eep");

        paint_app_step.addArgs(&.{ "--file", "/exec/paint.eep" });
        paint_app_step.addFileInput(paint_exec_file);
        paint_app_step.addFileArg(paint_exec_file);

        paint_app_step.addArgs(&.{ "--file", "/conf/apps/Paint.eln" });
        paint_app_step.addFileInput(content_path.path(b, "elns/Paint.eln"));
        paint_app_step.addFileArg(content_path.path(b, "elns/Paint.eln"));
    }

    const downloads_step = b.addRunArtifact(downloads_builder_exe);
    const downloads_file_path = downloads_step.addOutputFileArg("downloads.edf");
    const downloads_dir_path = downloads_step.addOutputDirectoryArg("downloads");
    downloads_step.addArgs(&.{ "--section", "Games", "games" });
    downloads_step.addArgs(&.{ "--file", "Pong" });
    downloads_step.addFileArg(pong_app_file_path);

    downloads_step.addArgs(&.{ "--section", "Tools", "tools" });
    downloads_step.addArgs(&.{ "--file", "Paint" });
    downloads_step.addFileArg(paint_app_file_path);

    downloads_step.addArgs(&.{ "--section", "Wallpapers", "wallpapers" });
    downloads_step.addArgs(&.{ "--file", "Wood" });
    downloads_step.addFileArg(wood_wallpaper_path);
    downloads_step.addArgs(&.{ "--file", "Capy" });
    downloads_step.addFileArg(capy_wallpaper_path);

    const install_downloads = b.addInstallFileWithDir(downloads_file_path, www_path, "downloads.edf");
    const install_downloads_dir = b.addInstallDirectory(.{ .source_dir = downloads_dir_path, .install_dir = www_path, .install_subdir = "downloads" });
    www_misc_step.dependOn(&install_downloads.step);
    www_misc_step.dependOn(&install_downloads_dir.step);

    // const www_files_step = b.step("www_files", "Build www files");
    // www_files_step.dependOn(www_misc_step);

    // for (WWW_FILES) |file| {
    //     const step = try file.getStep(b, content_path, b.path("www/downloads"), www_misc_step);

    //     www_files_step.dependOn(step);
    // }

    const www_step = b.step("www", "Build the website");
    www_step.dependOn(www_misc_step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const headless_step = b.step("headless", "Run the app headless");
    headless_step.dependOn(&version_write.step);
    headless_step.dependOn(&iversion_write.step);

    headless_step.dependOn(&headless_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);

    // public builds step
    const pub_step = b.step("pub", "Build all public builds");
    {
        const steam_pub_path: std.Build.InstallDir = .{ .custom = "pub/steam" };
        const install_recovery_step = b.addInstallFileWithDir(steam_image_path, steam_pub_path, "content/recovery.eee");

        pub_step.dependOn(&install_recovery_step.step);

        const public_options = b.addOptions();
        public_options.addOption(Version, "SandEEEVersion", version);
        public_options.addOption([]const u8, "VersionText", version_text);
        public_options.addOption(bool, "IsDemo", false);
        public_options.addOption(bool, "IsSteam", true);
        public_options.addOption(bool, "fakeSteam", false);

        const public_options_module = public_options.createModule();

        const exe_mod_pub_linux = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .os_tag = .linux,
                .abi = .gnu,
            }),
            .optimize = .ReleaseFast,
            .link_libc = true,
        });
        exe_mod_pub_linux.addImport("options", public_options_module);
        exe_mod_pub_linux.addImport("network", network_module);
        exe_mod_pub_linux.addImport("steam", steam_module);

        const exe_pub_linux = b.addExecutable(.{
            .name = "SandEEE",
            .root_module = exe_mod_pub_linux,
            .link_libc = true,
        });
        exe_pub_linux.addIncludePath(b.path("deps/include"));
        exe_pub_linux.addIncludePath(b.path("deps/steam_sdk/public/"));

        exe_pub_linux.addLibraryPath(b.path("deps/lib"));
        exe_pub_linux.addLibraryPath(b.path("deps/steam_sdk/redistributable_bin/linux64"));
        exe_pub_linux.addObjectFile(b.path("deps/lib/libglfw.so"));
        exe_pub_linux.addObjectFile(b.path("deps/lib/libopenal.so"));
        exe_pub_linux.linkSystemLibrary("steam_api");
        exe_pub_linux.linkLibC();

        const pub_linux_step = b.addInstallArtifact(
            exe_pub_linux,
            .{
                .dest_dir = .{ .override = steam_pub_path },
                .dest_sub_path = "linux/SandEEE",
            },
        );

        const exe_mod_pub_windows = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .os_tag = .windows,
                .abi = .gnu,
            }),
            .optimize = .ReleaseFast,
            .link_libc = true,
        });
        exe_mod_pub_windows.addImport("options", public_options_module);
        exe_mod_pub_windows.addImport("network", network_module);
        exe_mod_pub_windows.addImport("steam", steam_module);

        const exe_pub_windows = b.addExecutable(.{
            .name = "SandEEE",
            .root_module = exe_mod_pub_windows,
            .link_libc = true,
        });
        exe_pub_windows.addIncludePath(b.path("deps/include"));
        exe_pub_windows.addIncludePath(b.path("deps/steam_sdk/public/"));

        exe_pub_windows.addObjectFile(rc_file);
        exe_pub_windows.addLibraryPath(b.path("deps/lib"));
        exe_pub_windows.addLibraryPath(b.path("deps/steam_sdk/redistributable_bin/win64/"));
        exe_pub_windows.addObjectFile(b.path("deps/dll/libglfw3.dll"));
        exe_pub_windows.addObjectFile(b.path("deps/dll/libopenal.dll"));
        exe_pub_windows.subsystem = .Windows;
        exe_pub_linux.linkLibC();

        exe_pub_windows.linkSystemLibrary("steam_api64");

        const pub_windows_step = b.addInstallArtifact(
            exe_pub_windows,
            .{
                .dest_dir = .{ .override = steam_pub_path },
                .dest_sub_path = "windows/SandEEE.exe",
            },
        );

        pub_step.dependOn(&pub_linux_step.step);
        pub_step.dependOn(&pub_windows_step.step);

        const run_script_step = b.addInstallFileWithDir(b.path("runSandEEE"), steam_pub_path, "linux/runSandEEE");

        pub_step.dependOn(&run_script_step.step);

        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/dll/libglfw3.dll"), steam_pub_path, "windows/glfw3.dll");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/dll/libgcc_s_seh-1.dll"), steam_pub_path, "windows/libgcc_s_seh-1.dll");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/dll/libstdc++-6.dll"), steam_pub_path, "windows/libstdc++-6.dll");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/dll/libopenal.dll"), steam_pub_path, "windows/OpenAL32.dll");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/dll/libssp-0.dll"), steam_pub_path, "windows/libssp-0.dll");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/dll/libwinpthread-1.dll"), steam_pub_path, "windows/libwinpthread-1.dll");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/steam_sdk/redistributable_bin/win64/steam_api64.dll"), steam_pub_path, "windows/steam_api64.dll");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/steam_sdk/redistributable_bin/linux64/libsteam_api.so"), steam_pub_path, "linux/libsteam_api.so");
            pub_step.dependOn(&tmp_file_step.step);
        }
        {
            const tmp_file_step = b.addInstallFileWithDir(b.path("deps/lib/libglfw.so"), steam_pub_path, "linux/libglfw.so.3");
            pub_step.dependOn(&tmp_file_step.step);
        }
    }
    {
        const itch_pub_path: std.Build.InstallDir = .{ .custom = "pub/itch" };
        const install_recovery_linux_step = b.addInstallFileWithDir(disk_image_path, itch_pub_path, "linux/content/recovery.eee");
        const install_recovery_windows_step = b.addInstallFileWithDir(disk_image_path, itch_pub_path, "windows/content/recovery.eee");
        pub_step.dependOn(&install_recovery_linux_step.step);
        pub_step.dependOn(&install_recovery_windows_step.step);

        const public_options = b.addOptions();
        public_options.addOption(Version, "SandEEEVersion", version);
        public_options.addOption([]const u8, "VersionText", version_text);
        public_options.addOption(bool, "IsDemo", false);
        public_options.addOption(bool, "IsSteam", false);
        public_options.addOption(bool, "fakeSteam", false);

        const public_options_module = public_options.createModule();

        const exe_mod_pub_linux = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .os_tag = .linux,
                .abi = .gnu,
            }),
            .optimize = .ReleaseFast,
            .link_libc = true,
        });
        exe_mod_pub_linux.addImport("options", public_options_module);
        exe_mod_pub_linux.addImport("network", network_module);

        const exe_pub_linux = b.addExecutable(.{
            .name = "SandEEE",
            .root_module = exe_mod_pub_linux,
            .link_libc = true,
        });
        exe_pub_linux.addIncludePath(b.path("deps/include"));

        exe_pub_linux.addLibraryPath(b.path("deps/lib"));
        exe_pub_linux.addObjectFile(b.path("deps/lib/libglfw.so"));
        exe_pub_linux.addObjectFile(b.path("deps/lib/libopenal.so"));

        const pub_linux_step = b.addInstallArtifact(
            exe_pub_linux,
            .{
                .dest_dir = .{ .override = itch_pub_path },
                .dest_sub_path = "linux/SandEEE",
            },
        );

        const exe_mod_pub_windows = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .os_tag = .windows,
                .abi = .gnu,
            }),
            .optimize = .ReleaseFast,
            .link_libc = true,
        });
        exe_mod_pub_windows.addImport("options", public_options_module);
        exe_mod_pub_windows.addImport("network", network_module);

        const exe_pub_windows = b.addExecutable(.{
            .name = "SandEEE",
            .root_module = exe_mod_pub_windows,
            .link_libc = true,
        });
        exe_pub_windows.addIncludePath(b.path("deps/include"));

        exe_pub_windows.addObjectFile(rc_file);
        exe_pub_windows.addLibraryPath(b.path("deps/lib"));
        exe_pub_windows.addObjectFile(b.path("deps/dll/libglfw3.dll"));
        exe_pub_windows.addObjectFile(b.path("deps/dll/libopenal.dll"));
        exe_pub_windows.subsystem = .Windows;

        const pub_windows_step = b.addInstallArtifact(
            exe_pub_windows,
            .{
                .dest_dir = .{ .override = itch_pub_path },
                .dest_sub_path = "windows/SandEEE.exe",
            },
        );

        pub_step.dependOn(&pub_linux_step.step);
        pub_step.dependOn(&pub_windows_step.step);

        const run_script_step = b.addInstallFileWithDir(b.path("runSandEEE"), itch_pub_path, "linux/runSandEEE");

        pub_step.dependOn(&run_script_step.step);
    }

    // upload step
    const upload_step = b.step("upload", "Uploads a build to all platforms");
    const upload_steam_step = b.step("upload_steam", "Uploads a build to steam");

    const steamcmd_step = b.addSystemCommand(&.{ "steamcmd", "+login", "preston3410", "+run_app_build", "-desc", "Auto Upload" });
    steamcmd_step.addFileInput(b.path("steam/upload.vdf"));
    steamcmd_step.addFileArg(b.path("steam/upload.vdf"));
    steamcmd_step.addArg("+quit");

    steamcmd_step.step.dependOn(pub_step);

    upload_steam_step.dependOn(&steamcmd_step.step);
    upload_step.dependOn(upload_steam_step);

    // upload step
    const upload_itch_step = b.step("upload_itch", "Uploads a build to itch");

    const butler_linux_step = b.addSystemCommand(&.{ "butler", "push" });
    butler_linux_step.addFileInput(iversion_file);
    butler_linux_step.addPrefixedFileArg("--userversion-file=", iversion_file);
    butler_linux_step.addDirectoryArg(b.path("zig-out/pub/itch/linux/"));
    butler_linux_step.addArg(b.fmt("prestosilver/sandeee-alpha:linux", .{}));

    butler_linux_step.step.dependOn(pub_step);

    const butler_windows_step = b.addSystemCommand(&.{ "butler", "push" });
    butler_windows_step.addFileInput(iversion_file);
    butler_windows_step.addPrefixedFileArg("--userversion-file=", iversion_file);
    butler_windows_step.addDirectoryArg(b.path("zig-out/pub/itch/windows/"));
    butler_windows_step.addArg(b.fmt("prestosilver/sandeee-alpha:win", .{}));

    butler_windows_step.step.dependOn(pub_step);
    butler_linux_step.step.dependOn(pub_step);

    upload_itch_step.dependOn(&butler_windows_step.step);
    upload_itch_step.dependOn(&butler_linux_step.step);
    upload_step.dependOn(upload_itch_step);
}
