# Building SandEEEE

## General info

SandEEE completly uses zigs build system to build, however there are some caveats to this. Currently there is no support for macos or android, though this is a possibility in the future depending on how much I wanna brag about the project.

It should be able to build on any machine that has zig, (and mingw if you are building windows on linux, standart stuff). As of October 2026 I have builds working on Windows, this allows CI to catch my fatal crashes sooner. I also plan to eventually support 32 bit platforms so I can use windows xp machines at exhibitions. Though this is currently a low pri task.

Though this has nothing to do with the general public, for completeness of this document uploading requires steamcmd, and itch's butler depending on the platform you are uploading to.

## Debug flags

> [!NOTE]
> For platform specific steps like `build_steam` and `upload_itch`, all feature flags are ignored to ensure that a debug build never makes it to release, or that a release build never has no audio.

SandEEEs build system will package default disks with all debug info on debug builds. Release builds will have a seperate disk named `debug_recovery.eee` which has the debug data overlayed on it. The `headless` step can be used in conjunction with other parameters to test SandEEE's headless mode, by default it uses a disk called `headless.eee`.

Debug builds with `-Doptimize=debug` (the default) are always slower and larger, as of right now release builds are not shipped with symbols. The crash screen does not always show when the game crashes. When a segfault occurs, a release build will crash. This means debug builds are the only way to debug this. Along with this debug builds also log errors into the web log, so that they can be used for print debugging.

There is a `-Drandom=[number]` flag which will pack any number of randomly generated programs into SandEEE. These are cached but take a while to generate, so use it for testing, not for prototyping. This has helped me find alot of bugs, especially with things like lag in the file explorer. This is specifically for VM Threading tests as parsing errors and crashes should be caught by fuzz testing.

There are also flags like `-Dno_email_app`, and `-Dno_audio` to disable features in the output build. I've used these for debugging crashes from subsystems in the past.

## Disk creation

SandEEE's build system has 4 methods for creating content on a disk

- File placement
- Skeleton creation
- Folder overlays
- Disk overlays

File placement is used to pack generated files such as `eon.eep` on the disk. It can use zig's temp files so caches pretty nicely. Skeleton creation creates empty folders from a list of disk <-> folder associations, the first column in the list should be what disk type has it, while the second (space delimited) should be the path. Folder overlays are placed directly on the root, and are used for raw text configuration files to make `build.zig` a bit easier to follow. Finally disk overlays allow the build system to make intermediate feature disks for things such as steam support, and then overlay them on a different image. This has helped me debug a few things when it comes to file masking orders.

There are several tools for converting real world file formats to in game ones inside the `/build` folder, these are sorted by their in game file format (Though all plain text formats use `.txt` instead).

## The website

> [!NOTE]
> Currently SandEEE's build system cannot build the website on windows platforms.

SandEEE's website is built into `zig-out/www` with `zig build www`. In the CI I push the current release tag to the websites root, and the nightly into `/alpha`.