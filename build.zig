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

const DiskFileInputType = enum {
    Local,
    Temp,
};

const DiskFileInputData = union(DiskFileInputType) {
    Local: []const u8,
    Temp: *const DiskFileInput,
};

const DiskFileInput = struct {
    input: DiskFileInputData,

    converter: ?*const fn (*std.Build, []const std.Build.LazyPath) anyerror!std.ArrayList(u8),
};

const DiskFile = struct {
    input: DiskFileInputData,
    output: []const u8,

    converter: ?*const fn (*std.Build, []const std.Build.LazyPath) anyerror!std.ArrayList(u8),
};

const DEBUG_FILES = [_]DiskFile{
    // asm tests
    .{
        .input = .{ .Local = "asm/tests/hello.asm" },
        .output = "prof/tests/asm/hello.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/tests/window.asm" },
        .output = "prof/tests/asm/window.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/tests/texture.asm" },
        .output = "prof/tests/asm/texture.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/tests/fib.asm" },
        .output = "prof/tests/asm/fib.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/tests/arraytest.asm" },
        .output = "prof/tests/asm/arraytest.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/tests/audiotest.asm" },
        .output = "prof/tests/asm/audiotest.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/tests/tabletest.asm" },
        .output = "prof/tests/asm/tabletest.eep",
        .converter = comp.compile,
    },

    // eon tests
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/tests/input.eon" },
            .converter = eon.compileEon,
        } },
        .output = "prof/tests/eon/input.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/tests/color.eon" },
            .converter = eon.compileEon,
        } },
        .output = "prof/tests/eon/color.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/tests/bugs.eon" },
            .converter = eon.compileEon,
        } },
        .output = "prof/tests/eon/bugs.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/tests/tabletest.eon" },
            .converter = eon.compileEon,
        } },
        .output = "prof/tests/eon/tabletest.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/tests/heaptest.eon" },
            .converter = eon.compileEon,
        } },
        .output = "prof/tests/eon/heaptest.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/tests/stringtest.eon" },
            .converter = eon.compileEon,
        } },
        .output = "prof/tests/eon/stringtest.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/tests/paren.eon" },
            .converter = eon.compileEon,
        } },
        .output = "prof/tests/eon/paren.eep",
        .converter = comp.compile,
    },

    // eon sources
    .{
        .input = .{ .Local = "eon/exec/eon.eon" },
        .output = "prof/tests/src/eon/eon.eon",
        .converter = null,
    },
    .{
        .input = .{ .Local = "eon/exec/pix.eon" },
        .output = "prof/tests/src/eon/pix.eon",
        .converter = null,
    },
    .{
        .input = .{ .Local = "eon/exec/fib.eon" },
        .output = "prof/tests/src/eon/fib.eon",
        .converter = null,
    },
};

// these are in non demo builds
const NONDEMO_FILES = [_]DiskFile{
    .{
        .input = .{ .Local = "mail/spam/" },
        .output = "cont/mail/spam.eme",
        .converter = emails.emails,
    },
    .{
        .input = .{ .Local = "mail/private/" },
        .output = "cont/mail/private.eme",
        .converter = emails.emails,
    },
    .{
        .input = .{ .Local = "mail/work/" },
        .output = "cont/mail/work.eme",
        .converter = emails.emails,
    },
};

// this is in all builds, including demo.
const BASE_FILES = [_]DiskFile{
    // emails
    .{
        .input = .{ .Local = "mail/inbox/" },
        .output = "cont/mail/inbox.eme",
        .converter = emails.emails,
    },

    // asm executables
    .{
        .input = .{ .Local = "asm/exec/time.asm" },
        .output = "exec/time.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/exec/dump.asm" },
        .output = "exec/dump.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/exec/echo.asm" },
        .output = "exec/echo.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/exec/aplay.asm" },
        .output = "exec/aplay.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Local = "asm/exec/libdump.asm" },
        .output = "exec/libdump.eep",
        .converter = comp.compile,
    },

    // asm libraries
    .{
        .input = .{ .Local = "asm/libs/string.asm" },
        .output = "libs/string.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Local = "asm/libs/window.asm" },
        .output = "libs/window.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Local = "asm/libs/texture.asm" },
        .output = "libs/texture.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Local = "asm/libs/sound.asm" },
        .output = "libs/sound.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Local = "asm/libs/array.asm" },
        .output = "libs/array.ell",
        .converter = comp.compileLib,
    },

    // eon executables
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/epkman.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/epkman.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/eon.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/eon.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/stat.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/stat.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/player.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/player.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/asm.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/asm.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/pix.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/pix.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/elib.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/elib.eep",
        .converter = comp.compile,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/exec/alib.eon" },
            .converter = eon.compileEon,
        } },
        .output = "exec/alib.eep",
        .converter = comp.compile,
    },

    // eon libraries
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/libs/ui.eon" },
            .converter = eon.compileEonLib,
        } },
        .output = "libs/ui.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/libs/heap.eon" },
            .converter = eon.compileEonLib,
        } },
        .output = "libs/heap.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/libs/table.eon" },
            .converter = eon.compileEonLib,
        } },
        .output = "libs/table.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/libs/asm.eon" },
            .converter = eon.compileEonLib,
        } },
        .output = "libs/asm.ell",
        .converter = comp.compileLib,
    },
    .{
        .input = .{ .Temp = &.{
            .input = .{ .Local = "eon/libs/eon.eon" },
            .converter = eon.compileEonLib,
        } },
        .output = "libs/eon.ell",
        .converter = comp.compileLib,
    },

    // sounds
    .{
        .input = .{ .Local = "audio/login.wav" },
        .output = "cont/snds/login.era",
        .converter = sound.convert,
    },
    .{
        .input = .{ .Local = "audio/logout.wav" },
        .output = "cont/snds/logout.era",
        .converter = sound.convert,
    },
    .{
        .input = .{ .Local = "audio/message.wav" },
        .output = "cont/snds/message.era",
        .converter = sound.convert,
    },

    // images
    .{
        .input = .{ .Local = "images/email-logo.png" },
        .output = "cont/imgs/email-logo.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/icons.png" },
        .output = "cont/imgs/icons.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/ui.png" },
        .output = "cont/imgs/ui.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/bar.png" },
        .output = "cont/imgs/bar.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/iconsBig.png" },
        .output = "cont/imgs/iconsBig.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/window.png" },
        .output = "cont/imgs/window.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/wall1.png" },
        .output = "cont/imgs/wall1.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/wall2.png" },
        .output = "cont/imgs/wall2.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/wall3.png" },
        .output = "cont/imgs/wall3.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/barlogo.png" },
        .output = "cont/imgs/barlogo.eia",
        .converter = image.convert,
    },
    .{
        .input = .{ .Local = "images/cursor.png" },
        .output = "cont/imgs/cursor.eia",
        .converter = image.convert,
    },

    // includes
    .{
        .input = .{ .Local = "eon/libs/libload.eon" },
        .output = "libs/inc/libload.eon",
        .converter = null,
    },
    .{
        .input = .{ .Local = "eon/libs/sys.eon" },
        .output = "libs/inc/sys.eon",
        .converter = null,
    },

    // icons
    .{
        .input = .{ .Local = "images/icons/eeedt.png" },
        .output = "cont/icns/eeedt.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/tasks.png" },
        .output = "cont/icns/tasks.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/cmd.png" },
        .output = "cont/icns/cmd.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/settings.png" },
        .output = "cont/icns/settings.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/launch.png" },
        .output = "cont/icns/launch.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/debug.png" },
        .output = "cont/icns/debug.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/logout.png" },
        .output = "cont/icns/logout.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/folder.png" },
        .output = "cont/icns/folder.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/email.png" },
        .output = "cont/icns/email.eia",
        .converter = null,
    },
    .{
        .input = .{ .Local = "images/icons/web.png" },
        .output = "cont/icns/web.eia",
        .converter = null,
    },
};

// all builds
const INTERNAL_IMAGE_FILES = [_][]const u8{ "logo", "load", "sad", "bios", "error" };
const INTERNAL_SOUND_FILES = [_][]const u8{ "bg", "bios-blip", "bios-select" };

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

var temp_idx: usize = 0;

pub fn get_step(
    b: *std.Build,
    root: *std.Build.Step,
    temp_path: std.Build.LazyPath,
    content_path: std.Build.LazyPath,
    step: DiskFileInput,
    output: std.Build.LazyPath,
) !*std.Build.Step {
    switch (step.input) {
        .Local => |l| {
            if (step.converter) |converter| {
                const out_step = (try conv.ConvertStep.create(b, converter, content_path.path(b, l), output));

                out_step.step.dependOn(root);

                return &out_step.step;
            } else {
                const out_step = b.addSystemCommand(&.{
                    "cp",
                    content_path.path(b, l).getPath3(b, null).sub_path,
                    output.getPath3(b, null).sub_path,
                });

                out_step.step.dependOn(root);

                return &out_step.step;
            }
        },
        .Temp => |t| {
            const temp_file = temp_path.path(b, b.fmt("{}", .{temp_idx}));

            const child_step = try get_step(b, root, temp_path, content_path, t.*, temp_file);

            temp_idx += 1;

            if (step.converter) |converter| {
                var out_step = (try conv.ConvertStep.create(b, converter, temp_file, output));

                out_step.step.dependOn(child_step);

                return &out_step.step;
            } else {
                const out_step = b.addSystemCommand(&.{
                    "cp",
                    temp_file.getPath3(b, null).sub_path,
                    output.getPath3(b, null).sub_path,
                });

                out_step.step.dependOn(child_step);

                return &out_step.step;
            }
        },
    }
}

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

    const version_write = b.addWriteFile(
        "VERSION",
        b.fmt("{}", .{version}),
    );

    version.build = b.fmt("{s}-{X:0>4}", .{ version_suffix, std.fmt.parseInt(u64, commit[0 .. commit.len - 1], 0) catch 0 });

    const iversion_write = b.addWriteFile(
        "IVERSION",
        b.fmt("{}", .{version}),
    );

    const network_module = b.addModule("network", .{
        .root_source_file = b.path("deps/zig-network/network.zig"),
    });

    const steam_module = b.addModule("steam", .{
        .root_source_file = b.path("steam/steam.zig"),
    });

    const options = b.addOptions();

    const version_text = b.fmt("V_{{}}", .{});

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

    const file_data = try std.mem.concat(b.allocator, DiskFile, &.{
        &BASE_FILES,
        if (!is_demo) &NONDEMO_FILES else &.{},
        if (optimize == .Debug) &DEBUG_FILES else &.{},
    });

    const content_path = b.path("content");
    const disk_path = content_path.path(b, "disk");

    const temp_path = content_path.path(b, ".tmp");

    for (file_data) |file| {
        const root = if (file.converter == null) copy_disk else copy_libs;

        const step = try get_step(
            b,
            root,
            temp_path,
            content_path,
            .{ .converter = file.converter, .input = file.input },
            disk_path.path(b, file.output),
        );

        if (file.converter == null) {
            copy_libs.dependOn(step);
        } else {
            content_step.dependOn(step);
        }
    }

    var lib_load_step = try conv.ConvertStep.create(b, comp.compile, content_path.path(b, "asm/libs/libload.asm"), disk_path.path(b, "libs/libload.eep"));
    lib_load_step.step.dependOn(copy_disk);
    content_step.dependOn(&lib_load_step.step);

    const image_path = content_path.path(b, "images");
    const internal_image_path = b.path("src/images");

    inline for (INTERNAL_IMAGE_FILES) |file| {
        const pngf = image_path.path(b, file ++ ".png");
        const eiaf = internal_image_path.path(b, file ++ ".eia");

        var step = try conv.ConvertStep.create(b, image.convert, pngf, eiaf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    const audio_path = content_path.path(b, "audio");
    const internal_audio_path = b.path("src/sounds");

    inline for (INTERNAL_SOUND_FILES) |file| {
        const wavf = audio_path.path(b, file ++ ".wav");
        const eraf = internal_audio_path.path(b, file ++ ".era");

        var step = try conv.ConvertStep.create(b, sound.convert, wavf, eraf);

        step.step.dependOn(copy_disk);
        content_step.dependOn(&step.step);
    }

    _ = random_tests;
    // if (random_tests != 0) {
    //     _ = b.run(&[_][]const u8{ "mkdir", "-p", "content/disk/prof/tests/rand" });
    //     const filename = b.fmt("content/disk/prof/tests/rand/all.esh", .{});
    //     const count = b.fmt("{}", .{random_tests});

    //     var step = try conv.ConvertStep.create(b, rand.createScript, count, filename);

    //     step.step.dependOn(copy_disk);
    //     content_step.dependOn(&step.step);
    // }

    // for (0..@intCast(random_tests)) |idx| {
    //     const filename = b.fmt("content/disk/prof/tests/rand/{}.eep", .{idx});

    //     var step = try conv.ConvertStep.create(b, rand.create, "", filename);

    //     step.step.dependOn(copy_disk);
    //     content_step.dependOn(&step.step);
    // }

    var font_joke_step = try conv.ConvertStep.create(b, font.convert, image_path.path(b, "SandEEEJoke.png"), disk_path.path(b, "cont/fnts/SandEEEJoke.eff"));
    var font_step = try conv.ConvertStep.create(b, font.convert, image_path.path(b, "SandEEESans.png"), disk_path.path(b, "cont/fnts/SandEEESans.eff"));
    var font_2x_step = try conv.ConvertStep.create(b, font.convert, image_path.path(b, "SandEEESans2x.png"), disk_path.path(b, "cont/fnts/SandEEESans2x.eff"));
    var font_bios_step = try conv.ConvertStep.create(b, font.convert, image_path.path(b, "SandEEESans2x.png"), b.path("src/images/main.eff"));

    font_joke_step.step.dependOn(copy_disk);
    font_step.step.dependOn(copy_disk);
    font_2x_step.step.dependOn(copy_disk);
    font_bios_step.step.dependOn(copy_disk);

    content_step.dependOn(&font_step.step);
    content_step.dependOn(&font_joke_step.step);
    content_step.dependOn(&font_2x_step.step);
    content_step.dependOn(&font_bios_step.step);

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

    // const www_step = b.step("www", "Build the website");
    // var count: usize = 0;

    // for (WWW_FILES) |file| {
    //     if (file.download_label) |_|
    //         count += 1;
    // }

    // var input_files = try b.allocator.alloc([]const u8, count);
    // const download_step: WWWStepData = .{
    //     .input_files = input_files,

    //     .output_file = "www/downloads.edf",
    //     .converter = dwns.create,

    //     .download_label = null,
    // };

    // var idx: usize = 0;
    // for (WWW_FILES) |file| {
    //     const step = try conv.ConvertStep.createMulti(b, file.converter, file.input_files, file.output_file);
    //     step.step.dependOn(&disk_step.step);

    //     www_step.dependOn(&step.step);

    //     if (file.download_label) |label| {
    //         input_files[idx] = try std.fmt.allocPrint(b.allocator, "{s}:{s}", .{ label, file.output_file[4..] });
    //         idx += 1;
    //     }
    // }

    // {
    //     const file = download_step;

    //     const step = try conv.ConvertStep.createMulti(b, file.converter, file.input_files, file.output_file);
    //     step.step.dependOn(&disk_step.step);

    //     www_step.dependOn(&step.step);
    // }

    // {
    //     const step = try changelog.ChangelogStep.create(b, "www/changelog.edf");
    //     www_step.dependOn(&step.step);
    // }

    // {
    //     const docs_step = try docs.DocStep.create(b, "docs", "www/docs", "@/docs/");
    //     www_step.dependOn(&docs_step.step);
    // }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&version_write.step);
    run_step.dependOn(&iversion_write.step);

    run_step.dependOn(&run_cmd.step);

    const headless_step = b.step("headless", "Run the app headless");

    headless_step.dependOn(&version_write.step);
    headless_step.dependOn(&iversion_write.step);

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

    const branch = b.fmt("prestosilver/sandeee-os:{s}{s}", .{ platform, suffix });

    const butler_step = try butler.ButlerStep.create(b, "zig-out/bin", branch);
    butler_step.step.dependOn(&exe.step);
    butler_step.step.dependOn(b.getInstallStep());

    const upload_step = b.step("upload", "Upload to itch");
    upload_step.dependOn(&butler_step.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
