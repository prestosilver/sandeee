# SandEEE task list

> This is sorted by priority, please keep it that way :wink:.

List priority goes Bugs->Fixes->Todo

Though this is listed by priority, I do order by difficulty aswell. My logic has alwasy been along the lines of "Why waist the time fixing one big bug when you can fix 20 small ones while internally fixing the big one". If an issue/task is stopped ill take a break and get it done when I know I can schmoove through it. For a list organized by date/implementation order see [The release checklist](release_checklist.md).

## Known Bugs

These are fixes for behaviours that are implemented wrong.

- [X] Editor selection color wrong
- [X] Back button works in web when no history exists
- [X] !!!!144hz bs
- [X] Editor selection acts really weird
- [X] Window IDs limit at 255, but game keeps making windows
- [X] Scroll bars aren't scrolling
- [X] Steamtool item id is not labeled right
- [X] Keyboard localization is screwed
- [X] Steam web crashes game on unknown page
- [X] Possible crash on email VM calls
- [X] Web slighty cuts off paragraphs
- [X] Wth is up with popups!!
- [ ] Windows get mouse move event when covered.
- [ ] Wordwrap in console
- [ ] Disks files are unordered everywhere, sort on save
- [ ] Crash dosent save sometimes
- [ ] VMS don't stop on crash, meaning they can lag the crash state.
- [ ] Audio keeps playing on logout, or in other cases where it should stop.
- [ ] Restoring and installing a disk drops frames
- [ ] Task manager can fullscreen and renders wrong
- [ ] Steam in web can lag the game
- [ ] Steam upload can lag game
- [ ] Notification text can cut off
- [ ] _*_meta files should not copy to disk on install
- [ ] Crash screen should display relative paths
- [ ] Web threads crash on windows
    - [ ] Wine only

## Minor non bug fixes

These are tasks that dont fix existing behaviour, but improve accessibility for any demographic (Including everyone).

- [X] Error when web content type is not either "application/octet-stream" or "text/eeedocument"
- [X] Unify double click
- [X] Switch to proper versioning everywhere
- [X] Fix random mem leak on tests
- [X] Recheck changelog items
- [X] Separate build for demo bc different appids!
- [ ] Add actual pickers to settings ui
- [ ] Control the dithering, and crt of the shader separately
- [ ] Accessibility wizard
  - [ ] In BootEEE
  - [ ] On first boot
- [ ] Windowed mode
  - [X] Cli arg
  - [ ] BIOS setting
- [ ] Consistent color parsing
  - [ ] Design new format
- [ ] <=> in font should not connect at all
- [ ] All buttons should look disabled when disabled
- [ ] Workshop item SandEEE version tags
- [ ] Translation system
- [ ] Show load progress on web
- [ ] Auto fix capitalization in changelog gen
- [ ] SandEEE install disk cli flags
- [ ] Steam tool transfer from demo.

## Refactor todo

These are tasks that only affect the codebase.

- [X] zig build upload_itch_release
- [X] Zig 0.16
- [X] Move runSandEEE to a subfolder somewhere (in repo)
- [X] Github actions doesnt test `-Dsteam=On`
- [X] Remove anyerror
- [ ] Magic number cleanup
  - [X] Colors
  - [ ] Sizes
- [ ] Breakout UI for consistency!!!
  - [ ] data/sizes.zig
  - [ ] ui namespace
  - [ ] switch apps
  - [ ] switch bar, desktop icons, and start menu
- [ ] Move embed files inside build.zig
- [ ] zig test should check www for dead links
- [ ] Add consistent id+iota type utility
- [ ] Rework popups to be owned by windows instead of state
- [ ] Separate build for debug bc different appids!
- [ ] zig build steam_changelog
- [ ] zig build itch_changelog

## General todo

These are tasks that include adding new features to the game, or arent covered by the other two lists.

- [X] New partial disk scripted recovery system
- [X] Double check wording in demo emails
- [X] Workshop previews
- [X] EDS Background color
- [X] Fix program names and versions
  - [X] Merge BootEEE
  - [X] Breakout other versions to `strings.zig`
- [ ] New email system
- [ ] Add joe disk image
- [ ] Sys 255 impl
  - [ ] File encrypted flag
  - [ ] Rsa/Rc4 decide on how itll work.
- [ ] Recovery image encryption
- [ ] Workshop favorites
    - [X] Show in list
    - [ ] Dedicated list
- [ ] Add a about SandEEE app with creator credits
- [ ] Figure out music