# SandEEE task list

> This is sorted by priority, please keep it that way :wink:.

List priority goes Bugs->Fixes->Todo

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
- [ ] Crash dosent save sometimes
- [ ] Wth is up with popups!!
- [ ] Wordwrap in console
- [ ] Disks files are unordered everywhere, sort on save
- [ ] VMS don't stop on crash, meaning they can lag the crash state.
- [ ] Audio keeps playing on logout, or in other cases where it should stop.
- [ ] Restoring and installing a disk drops frames
- [ ] Task manager can fullscreen and renders wrong
- [ ] Steam in web can lag the game
- [ ] Steam upload can lag game
- [ ] Notification text can cut off
- [ ] _*_meta files should not copy to disk on install
- [ ] Crash screen should display relative paths

## Minor non bug fixes

These are tasks that dont fix existing behaviour, but improve accessability for any demograhic (Including everyone).

- [X] Error when web content type is not either "application/octet-stream" or "text/eeedocument"
- [X] Unify double click
- [X] Switch to proper versioning everywhere
- [X] Fix random mem leak on tests
- [X] Recheck changelog items
- [X] Separate build for demo bc different appids!
- [ ] Add actual pickers to settings ui
- [ ] Accessibility wizard
  - [ ] In BootEEE
  - [ ] On first boot
- [ ] <=> in font should not connect at all
- [ ] All buttons should look disabled when disabled
- [ ] Show load progress on web
- [ ] Workshop item SandEEE version tags
- [ ] Control the dithering, and crt of the shader separately
- [ ] Auto fix capitalization in changelog gen
- [ ] SandEEE install disk cli flags
- [ ] Separate build for debug bc different appids!
- [ ] Translation system
- [ ] Consistent color parsing
- [ ] Steam tool transfer from demo.

## Refactor todo

These are tasks that only affect the codebase.

- [X] zig build upload_itch_release
- [ ] zig test should check www for dead links
- [ ] Breakout UI for consistency!!!
- [ ] Add consistent id+iota type utility
- [ ] zig build steam_changelog
- [ ] zig build itch_changelog
- [ ] Move runSandEEE to a subfolder somewhere (in repo)
- [ ] Github actions doesnt test `-Dsteam=On`
- [ ] Zig 0.16


## General tentative todo

These are tasks that include adding new features to the game, or arent covered by the other two lists.

- [X] New partial disk scripted recovery system
- [X] Double check wording in demo emails
- [X] Workshop previews
- [X] EDS Background color
- [ ] Workshop favorites
    - [X] Show in list
    - [ ] Dedicated list
- [ ] Fix program names and versions
  - [X] Merge BootEEE
  - [ ] Breakout other versions to `strings.zig`
- [ ] Add a credits app
- [ ] Inter email box conditions
- [ ] Embed file fix
- [ ] Update email content
