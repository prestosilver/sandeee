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
const www = @import("tools/www.zig");

const isBuild = true;

const DiskFileInputData = www.DiskFileInputData;
const DiskFileInput = www.DiskFileInput;
const DiskFile = www.DiskFile;
const WWWSection = www.WWWSection;

const DEBUG_FILES = [_]DiskFile{
    // asm tests
    .{
        .file = .{
            .input = &.{.local("asm/tests/hello.asm")},
            .converter = comp.compile,
        },
        .output = "prof/tests/asm/hello.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/tests/window.asm")},
            .converter = comp.compile,
        },
        .output = "prof/tests/asm/window.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/tests/texture.asm")},
            .converter = comp.compile,
        },
        .output = "prof/tests/asm/texture.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/tests/fib.asm")},
            .converter = comp.compile,
        },
        .output = "prof/tests/asm/fib.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/tests/arraytest.asm")},
            .converter = comp.compile,
        },
        .output = "prof/tests/asm/arraytest.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/tests/audiotest.asm")},
            .converter = comp.compile,
        },
        .output = "prof/tests/asm/audiotest.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/tests/tabletest.asm")},
            .converter = comp.compile,
        },
        .output = "prof/tests/asm/tabletest.eep",
    },

    // eon tests
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/tests/input.eon")),
            },
            .converter = comp.compile,
        },
        .output = "prof/tests/eon/input.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/tests/color.eon")),
            },
            .converter = comp.compile,
        },
        .output = "prof/tests/eon/color.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/tests/bugs.eon")),
            },
            .converter = comp.compile,
        },
        .output = "prof/tests/eon/bugs.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/tests/tabletest.eon")),
            },
            .converter = comp.compile,
        },
        .output = "prof/tests/eon/tabletest.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/tests/heaptest.eon")),
            },
            .converter = comp.compile,
        },
        .output = "prof/tests/eon/heaptest.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/tests/stringtest.eon")),
            },
            .converter = comp.compile,
        },
        .output = "prof/tests/eon/stringtest.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/tests/paren.eon")),
            },
            .converter = comp.compile,
        },
        .output = "prof/tests/eon/paren.eep",
    },

    // eon sources
    .{
        .file = .{
            .input = &.{.local("eon/exec/eon.eon")},
            .converter = conv.copy,
        },
        .output = "prof/tests/src/eon/eon.eon",
    },
    .{
        .file = .{
            .input = &.{.local("eon/exec/pix.eon")},
            .converter = conv.copy,
        },
        .output = "prof/tests/src/eon/pix.eon",
    },
    .{
        .file = .{
            .input = &.{.local("eon/exec/fib.eon")},
            .converter = conv.copy,
        },
        .output = "prof/tests/src/eon/fib.eon",
    },
};

// steam builds only
const STEAM_FILES = [_]DiskFile{
    .{
        .output = "exec/steamtool.eep",
        .file = .{
            .converter = comp.compile,
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/steamtool.eon")),
            },
        },
    },
};

// these are in non demo builds
const NONDEMO_FILES = [_]DiskFile{
    .{
        .file = .{
            .input = &.{.local("mail/spam/")},
            .converter = emails.emails,
        },
        .output = "cont/mail/spam.eme",
    },
    .{
        .file = .{
            .input = &.{.local("mail/private/")},
            .converter = emails.emails,
        },
        .output = "cont/mail/private.eme",
    },
    .{
        .file = .{
            .input = &.{.local("mail/work/")},
            .converter = emails.emails,
        },
        .output = "cont/mail/work.eme",
    },
};

// this is in all builds, including demo.
const BASE_FILES = [_]DiskFile{
    // emails
    .{
        .file = .{
            .input = &.{.local("mail/inbox/")},
            .converter = emails.emails,
        },
        .output = "cont/mail/inbox.eme",
    },

    // asm executables
    .{
        .file = .{
            .input = &.{.local("asm/exec/time.asm")},
            .converter = comp.compile,
        },
        .output = "exec/time.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/exec/dump.asm")},
            .converter = comp.compile,
        },
        .output = "exec/dump.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/exec/echo.asm")},
            .converter = comp.compile,
        },
        .output = "exec/echo.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/exec/aplay.asm")},
            .converter = comp.compile,
        },
        .output = "exec/aplay.eep",
    },
    .{
        .file = .{
            .input = &.{.local("asm/exec/libdump.asm")},
            .converter = comp.compile,
        },
        .output = "exec/libdump.eep",
    },

    // asm libraries
    .{
        .file = .{
            .input = &.{.local("asm/libs/string.asm")},
            .converter = comp.compileLib,
        },
        .output = "libs/string.ell",
    },
    .{
        .file = .{
            .input = &.{.local("asm/libs/window.asm")},
            .converter = comp.compileLib,
        },
        .output = "libs/window.ell",
    },
    .{
        .file = .{
            .input = &.{.local("asm/libs/texture.asm")},
            .converter = comp.compileLib,
        },
        .output = "libs/texture.ell",
    },
    .{
        .file = .{
            .input = &.{.local("asm/libs/sound.asm")},
            .converter = comp.compileLib,
        },
        .output = "libs/sound.ell",
    },
    .{
        .file = .{
            .input = &.{.local("asm/libs/array.asm")},
            .converter = comp.compileLib,
        },
        .output = "libs/array.ell",
    },

    // eon executables
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/epkman.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/epkman.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/eon.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/eon.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/stat.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/stat.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/player.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/player.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/asm.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/asm.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/pix.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/pix.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/elib.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/elib.eep",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEon, .local("eon/exec/alib.eon")),
            },
            .converter = comp.compile,
        },
        .output = "exec/alib.eep",
    },

    // eon libraries
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEonLib, .local("eon/libs/ui.eon")),
            },
            .converter = comp.compileLib,
        },
        .output = "libs/ui.ell",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEonLib, .local("eon/libs/heap.eon")),
            },
            .converter = comp.compileLib,
        },
        .output = "libs/heap.ell",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEonLib, .local("eon/libs/table.eon")),
            },
            .converter = comp.compileLib,
        },
        .output = "libs/table.ell",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEonLib, .local("eon/libs/asm.eon")),
            },
            .converter = comp.compileLib,
        },
        .output = "libs/asm.ell",
    },
    .{
        .file = .{
            .input = &.{
                .converter(eon.compileEonLib, .local("eon/libs/eon.eon")),
            },
            .converter = comp.compileLib,
        },
        .output = "libs/eon.ell",
    },

    // sounds
    .{
        .file = .{
            .input = &.{.local("audio/login.wav")},
            .converter = sound.convert,
        },
        .output = "cont/snds/login.era",
    },
    .{
        .file = .{
            .input = &.{.local("audio/logout.wav")},
            .converter = sound.convert,
        },
        .output = "cont/snds/logout.era",
    },
    .{
        .file = .{
            .input = &.{.local("audio/message.wav")},
            .converter = sound.convert,
        },
        .output = "cont/snds/message.era",
    },

    // images
    .{
        .file = .{
            .input = &.{.local("images/email-logo.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/email-logo.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/icons.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/ui.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/ui.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/bar.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/bar.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/iconsBig.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/iconsBig.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/window.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/window.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/wall1.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/wall1.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/wall2.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/wall2.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/wall3.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/wall3.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/barlogo.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/barlogo.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/cursor.png")},
            .converter = image.convert,
        },
        .output = "cont/imgs/cursor.eia",
    },

    // includes
    .{
        .file = .{
            .input = &.{.local("eon/libs/libload.eon")},
            .converter = conv.copy,
        },
        .output = "libs/inc/libload.eon",
    },
    .{
        .file = .{
            .input = &.{.local("eon/libs/sys.eon")},
            .converter = conv.copy,
        },
        .output = "libs/inc/sys.eon",
    },

    // icons
    .{
        .file = .{
            .input = &.{.local("images/icons/eeedt.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/eeedt.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/tasks.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/tasks.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/cmd.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/cmd.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/settings.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/settings.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/launch.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/launch.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/debug.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/debug.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/logout.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/logout.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/folder.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/folder.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/email.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/email.eia",
    },
    .{
        .file = .{
            .input = &.{.local("images/icons/web.png")},
            .converter = image.convert,
        },
        .output = "cont/icns/web.eia",
    },
};

// all builds
const INTERNAL_IMAGE_FILES = [_][]const u8{ "logo", "load", "sad", "bios", "error" };
const INTERNAL_SOUND_FILES = [_][]const u8{ "bg", "bios-blip", "bios-select" };

// the website
const WWW_FILES = [_]WWWSection{
    .{
        .label = "Games",
        .folder = "games",
        .files = &.{
            .{ .label = "Pong", .file = "pong.epk", .data = .{
                .epk = &.{
                    .{
                        .file = .{
                            .input = &.{.{ .Temp = &.{
                                .input = &.{.local("eon/exec/pong.eon")},
                                .converter = eon.compileEon,
                            } }},
                            .converter = comp.compile,
                        },
                        .output = "/exec/pong.eep",
                    },
                    .{
                        .file = .{
                            .input = &.{.local("images/pong.png")},
                            .converter = image.convert,
                        },
                        .output = "/cont/imgs/pong.eia",
                    },
                    .{
                        .file = .{
                            .input = &.{.local("images/icons/pong.png")},
                            .converter = image.convert,
                        },
                        .output = "/cont/icns/pong.eia",
                    },
                    .{
                        .file = .{
                            .input = &.{.local("audio/pong-blip.wav")},
                            .converter = sound.convert,
                        },
                        .output = "/cont/snds/pong-blip.era",
                    },
                    .{
                        .file = .{
                            .input = &.{.local("elns/Pong.eln")},
                            .converter = conv.copy,
                        },
                        .output = "/conf/apps/Pong.eln",
                    },
                },
            } },
            .{ .label = "Connectris", .file = "connectris.epk", .data = .{ .epk = &.{
                .{
                    .file = .{
                        .input = &.{.{ .Temp = &.{
                            .input = &.{.local("eon/exec/connectris.eon")},
                            .converter = eon.compileEon,
                        } }},
                        .converter = comp.compile,
                    },
                    .output = "/exec/connectris.eep",
                },
                .{
                    .file = .{
                        .input = &.{.local("images/connectris.png")},
                        .converter = image.convert,
                    },
                    .output = "/cont/imgs/connectris.eia",
                },
                .{
                    .file = .{
                        .input = &.{.local("images/icons/connectris.png")},
                        .converter = image.convert,
                    },
                    .output = "/cont/icns/connectris.eia",
                },
                .{
                    .file = .{
                        .input = &.{.local("elns/Connectris.eln")},
                        .converter = conv.copy,
                    },
                    .output = "/conf/apps/Connectris.eln",
                },
            } } },
        },
    },
    .{
        .label = "Tools",
        .folder = "tools",
        .files = &.{.{
            .label = "Paint",
            .file = "paint.epk",
            .data = .{ .epk = &.{
                .{
                    .file = .{
                        .input = &.{.{ .Temp = &.{
                            .input = &.{.local("eon/exec/paint.eon")},
                            .converter = eon.compileEon,
                        } }},
                        .converter = comp.compile,
                    },
                    .output = "/exec/paint.eep",
                },
                .{
                    .file = .{
                        .input = &.{.local("images/transparent.png")},
                        .converter = image.convert,
                    },
                    .output = "/cont/imgs/transparent.eia",
                },
                .{
                    .file = .{
                        .input = &.{.local("images/icons/paint.png")},
                        .converter = image.convert,
                    },
                    .output = "/cont/icns/paint.eia",
                },
                .{
                    .file = .{
                        .input = &.{.local("elns/Paint.eln")},
                        .converter = conv.copy,
                    },
                    .output = "/conf/apps/Paint.eln",
                },
            } },
        }},
    },
    .{
        .label = "Wallpapers",
        .folder = "wallpapers",
        .files = &.{
            .{ .label = "Wood", .file = "wood.eia", .data = .{
                .file = .{
                    .input = &.{.local("images/wood.png")},
                    .converter = image.convert,
                },
            } },
            .{ .label = "Capy", .file = "capy.eia", .data = .{
                .file = .{
                    .input = &.{.local("images/capy.png")},
                    .converter = image.convert,
                },
            } },
        },
    },
};

var version: std.SemanticVersion = .{
    .major = 0,
    .minor = 4,
    .patch = 4,
    .build = null,
};

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

    const steam_module = b.addModule("steam", .{
        .root_source_file = b.path("steam/steam.zig"),
        .link_libc = true,
    });

    const options = b.addOptions();

    const version_text = b.fmt("V_{{}}", .{});

    const content_path = b.path("content");
    const disk_path = content_path.path(b, "disk");

    options.addOption(std.SemanticVersion, "SandEEEVersion", version);
    options.addOption([]const u8, "VersionText", version_text);
    options.addOption(bool, "IsDemo", is_demo);
    options.addOption(bool, "IsSteam", steam_mode != .Off);
    options.addOption(bool, "fakeSteam", steam_mode == .Fake);

    exe_mod.addImport("options", options.createModule());
    exe_mod.addImport("network", network_module);
    exe_mod.addImport("steam", steam_module);

    const clean_disk_step = b.addSystemCommand(&.{ "rm", "-rf", "content/disk" });

    const setup_out = b.addSystemCommand(&.{ "mkdir", "-p", "zig-out/bin/content", "zig-out/bin/disks" });
    setup_out.step.dependOn(&clean_disk_step.step);

    const skel_step = b.addSystemCommand(&.{ "cp", "-r", "content/rawdisk", "content/disk" });
    skel_step.step.dependOn(&setup_out.step);

    const copy_libs_step = b.step("libraries", "Copies the eon libraries");
    copy_libs_step.dependOn(&skel_step.step);

    const content_step = b.step("content", "builds the content folder");
    content_step.dependOn(copy_libs_step);

    var disk_image_step = try disk.DiskStep.create(b, "content/disk", "zig-out/bin/content/recovery.eee");
    disk_image_step.step.dependOn(content_step);

    const disk_step = b.step("disk", "Builds the disk image");
    disk_step.dependOn(&disk_image_step.step);

    // cleanup temp files
    const clean_tmp = b.addSystemCommand(&.{ "rm", "-rf", "content/.tmp", ".zig-cache", "zig-out" });

    const clean_step = b.step("clean", "cleans the build env");
    clean_step.dependOn(&clean_tmp.step);
    clean_step.dependOn(&clean_disk_step.step);

    if (optimize == .Debug) {
        var dir = try std.fs.cwd().openDir("content/overlays/debug/", .{ .iterate = true });
        var iter = dir.iterate();

        while (try iter.next()) |path| {
            const p = try std.mem.concat(b.allocator, u8, &.{ "content/overlays/debug/", path.name });

            const debug_overlay = b.addSystemCommand(&.{ "cp", "-r", p, "content/disk" });

            debug_overlay.step.dependOn(&skel_step.step);

            content_step.dependOn(&debug_overlay.step);
        }
    }

    if (steam_mode != .Off) {
        var dir = try std.fs.cwd().openDir("content/overlays/steam/", .{ .iterate = true });
        var iter = dir.iterate();

        while (try iter.next()) |path| {
            const p = try std.mem.concat(b.allocator, u8, &.{ "content/overlays/steam/", path.name });
            defer b.allocator.free(p);

            const steam_overlay = b.addSystemCommand(&.{ "cp", "-r", p, "content/disk" });

            steam_overlay.step.dependOn(&skel_step.step);

            content_step.dependOn(&steam_overlay.step);
        }
    }

    // Includes
    exe.addIncludePath(b.path("deps/include"));
    exe.addIncludePath(b.path("deps/steam_sdk/public/"));
    if (target.result.os.tag == .windows) {
        exe.addObjectFile(b.path("content/app.res.obj"));
        exe.addLibraryPath(b.path("deps/lib"));
        exe.addLibraryPath(b.path("deps/steam_sdk/redistributable_bin/win64/"));
        // exe.subsystem = .Windows;
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

    const file_data = try std.mem.concat(b.allocator, DiskFile, &.{
        &BASE_FILES,
        if (!is_demo) &NONDEMO_FILES else &.{},
        if (optimize == .Debug) &DEBUG_FILES else &.{},
        if (steam_mode != .Off) &STEAM_FILES else &.{},
    });

    for (file_data) |file| {
        const root = if (file.file.converter == conv.copy)
            &skel_step.step
        else
            copy_libs_step;

        const step = try file.getStep(b, content_path, disk_path, root);

        if (file.file.converter == conv.copy) {
            copy_libs_step.dependOn(step);
        } else {
            content_step.dependOn(step);
        }
    }

    var lib_load_step = try conv.ConvertStep.create(b, comp.compile, &.{content_path.path(b, "asm/libs/libload.asm")}, disk_path.path(b, "libs/libload.eep"));
    lib_load_step.step.dependOn(&skel_step.step);
    content_step.dependOn(&lib_load_step.step);

    const image_path = content_path.path(b, "images");
    const internal_image_path = b.path("src/images");

    inline for (INTERNAL_IMAGE_FILES) |file| {
        const pngf = image_path.path(b, file ++ ".png");
        const eiaf = internal_image_path.path(b, file ++ ".eia");

        var step = try conv.ConvertStep.create(b, image.convert, &.{pngf}, eiaf);

        content_step.dependOn(&step.step);
    }

    const audio_path = content_path.path(b, "audio");
    const internal_audio_path = b.path("src/sounds");

    inline for (INTERNAL_SOUND_FILES) |file| {
        const wavf = audio_path.path(b, file ++ ".wav");
        const eraf = internal_audio_path.path(b, file ++ ".era");

        var step = try conv.ConvertStep.create(b, sound.convert, &.{wavf}, eraf);

        content_step.dependOn(&step.step);
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

    var font_joke_step = try conv.ConvertStep.create(
        b,
        font.convert,
        &.{image_path.path(b, "SandEEEJoke.png")},
        disk_path.path(b, "cont/fnts/SandEEEJoke.eff"),
    );
    var font_step = try conv.ConvertStep.create(
        b,
        font.convert,
        &.{image_path.path(b, "SandEEESans.png")},
        disk_path.path(b, "cont/fnts/SandEEESans.eff"),
    );
    var font_2x_step = try conv.ConvertStep.create(
        b,
        font.convert,
        &.{image_path.path(b, "SandEEESans2x.png")},
        disk_path.path(b, "cont/fnts/SandEEESans2x.eff"),
    );
    var font_bios_step = try conv.ConvertStep.create(
        b,
        font.convert,
        &.{image_path.path(b, "SandEEESans2x.png")},
        b.path("src/images/main.eff"),
    );

    font_joke_step.step.dependOn(&skel_step.step);
    font_step.step.dependOn(&skel_step.step);
    font_2x_step.step.dependOn(&skel_step.step);
    font_bios_step.step.dependOn(&skel_step.step);

    content_step.dependOn(&font_step.step);
    content_step.dependOn(&font_joke_step.step);
    content_step.dependOn(&font_2x_step.step);
    content_step.dependOn(&font_bios_step.step);

    exe.step.dependOn(&version_write.step);
    exe.step.dependOn(&iversion_write.step);
    exe.step.dependOn(disk_step);

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
        _ = b.run(&[_][]const u8{ "mkdir", "-p", "zig-out/bin/lib/" });
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

    var count: usize = 0;

    for (WWW_FILES) |file| {
        for (file.files) |_|
            count += 1;
    }

    const www_misc_step = b.step("www_misc", "Build www misc");

    const download_step = try dwns.DownloadPageStep.create(b, &WWW_FILES, b.path("www/downloads.edf"));
    www_misc_step.dependOn(&download_step.step);

    const changelog_step = try changelog.ChangelogStep.create(b, "www/changelog.edf");
    www_misc_step.dependOn(&changelog_step.step);

    const docs_step = try docs.DocStep.create(b, "docs", "www/docs", "@/docs/");
    www_misc_step.dependOn(&docs_step.step);

    const www_files_step = b.step("www_files", "Build www files");
    www_files_step.dependOn(www_misc_step);

    for (WWW_FILES) |file| {
        const step = try file.getStep(b, content_path, b.path("www/downloads"), www_misc_step);

        www_files_step.dependOn(step);
    }

    const www_step = b.step("www", "Build the website");
    www_step.dependOn(www_misc_step);
    www_step.dependOn(www_files_step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const headless_step = b.step("headless", "Run the app headless");
    headless_step.dependOn(&version_write.step);
    headless_step.dependOn(&iversion_write.step);

    headless_step.dependOn(&headless_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = exe_mod,
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

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const branch = b.fmt("prestosilver/sandeee-os:{s}{s}", .{ platform, suffix });

    const butler_step = try butler.ButlerStep.create(b, "zig-out/bin", branch);
    butler_step.step.dependOn(&exe.step);
    butler_step.step.dependOn(b.getInstallStep());

    const upload_step = b.step("upload", "Upload to itch");
    upload_step.dependOn(&butler_step.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);
}
