# SandEEE task list

> This is sorted by priority, please keep it that way :wink:.

## Known Bugs

- [X] Editor selection color wrong
- [X] Back button works in web when no history exists
- [X] !!!!144hz bs
- [X] Editor selection acts really weird
- [X] Window IDs limit at 255, but game keeps making windows
- [X] Scroll bars aren't scrolling
- [X] Steamtool item id is not labeled right
- [X] Keyboard localization is screwed
- [ ] Possible crash on email VM calls
- [ ] Wordwrap in console
- [ ] VMS don't close on crash, meaning they can lag the crash state.
- [ ] Audio keeps playing on logout, or in other cases where it should stop.
- [ ] Restoring and installing a disk drops frames
- [ ] Disks files are unordered everywhere, sort on save
- [ ] Task manager can fullscreen and renders wrong
- [ ] Steam in web can lag the game
- [ ] Github actions doesnt test `-Dsteam=On`

## Minor non bug fixes

- [X] Error when web content type is not either "application/octet-stream" or "text/eeedocument"
- [X] Unify double click
- [X] Switch to proper versioning everywhere
- [X] Fix random mem leak on tests
- [X] Recheck changelog items
- [X] Separate build for demo bc different appids!
- [ ] Fix program names and versions
  - [X] Merge BootEEE
  - [ ] Breakout other versions to `strings.zig`
- [ ] Add actual pickers to settings ui
- [ ] <=> in font should not connect at all
- [ ] All buttons should look disabled when disabled
- [ ] Add consistent id+iota type utility
- [ ] Load progress on web
- [ ] Auto fix capitalization in changelog gen
- [ ] Control the dithering, and crt of the shader separately
- [ ] Separate build for debug bc different appids!

## General tentative todo

- [X] New partial disk scripted recovery system
- [X] zig build upload_itch_release
- [X] Double check wording in demo emails
- [X] Workshop previews
- [X] EDS Background color
- [ ] Workshop favorites
- [ ] Breakout UI for consistency!!!
- [ ] SandEEE install should be configurable somehow, cli flag probably.
- [ ] zig test should check www for dead links
- [ ] zig build steam_changelog
- [ ] zig build itch_changelog
- [ ] Inter email box conditions
- [ ] Embed file fix
- [ ] Update email content
- [ ] Change email unlocked to key based
- [ ] Accessibility settings in bios somewhere!
- [ ] Consistent color parsing
- [ ] Email notification text is cut off a bit.
- [ ] Don't copy _*_meta files on disk install
- [ ] Crash screen should be relative paths
- [ ] Move runSandEEE to a subfolder somewhere (in repo)
- [ ] Steam tool transfer from demo.
- [ ] Some sort of credits.
- [ ] Zig 0.16
