# Building SandEEEE

## General info

SandEEE completly uses zigs build system to build, however there are some caveats to this. Currently there is no support for macos or android, though this is a possibility in the future depending on how much I wanna brag about the project.

It should be able to build on any machine that has lib-glfw, zig, and for windows builds mingw. However I have not tested building on any platform outside of linux.

Though this has nothing to do with contributors, for completeness uploading requires steamcmd, and itch's butler depending on the platform you are uploading to.

## Debug flags

> [!NOTE]
> For platform specific steps like `build_steam` and `upload_itch`, all feature flags are ignored to ensure that a debug build never makes it to release, or that a release build never has no audio.

SandEEEs build system will package default disks with all debug info on debug builds. Release builds will have a seperate disk named `debug_recovery.eee` which has the debug data overlayed on it.

Debug builds with `-Doptimize=Debug` (the default) are always slower and larger, as of right now release builds are not shipped with symbols. The crash screen does not always show when the game crashes. When a segfault occurs, a release build will crash. This means debug builds are the only way to debug this. Along with this debug builds also log errors into the web log, so that they can be used for print debugging.

There is also the `-Drandom=[number]` which will pack any number of randomly generated programs into SandEEE. These are cached but take a while to generate, so use it for testing, not for prototyping. This has helped me find alot of bugs, especially with things like lag in the file explorer.

There are also flags like `-Dno_email_app`, and `-Dno_audio` to disable features in the output build.

## Overlays

SandEEE's build system has 3 steps for creating a disk

- The copy phase
- The generate phase
- The packing phase

In the copy phase all disks and overlays are applied to the current disk. This includes copying all files in relavant overlays (`/content/overlays/[name]`), aswell as creating all folders listed with the same name inside `/content/overlays/paths.txt`. This exists so I dont need to filter and maintain .keep's for empty folders.

In the generate phase sandeee uses programs from `/build/` to convert files to in universe formats. These are organized into folders by output extension.

And finally in the packing phase, SandEEE will take these generated disks and pack them into `.eee` files it will also use some of these `.eee` files to generate more. Overlays for things like steam are kept seperate so that SandEEE can still cache the majority of images (a steam `.eee` requires the base `.eee`, so there is no wait when switching targets).