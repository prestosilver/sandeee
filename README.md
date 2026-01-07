# SandEEE OS

> :bangbang::bangbang: **WARNING** :bangbang::bangbang: Some of this repo contains spoilers for SandEEE, read docs outside of the README at your own risk.

## What is sandeee

SandEEE is a game! :open_mouth:

Jokes aside, SandEEE is a programming game ment to be as immersive as possible. Pulling no punches when it comes to design and planning. SandEEE assumes it exists in a world where text is the fundamental data layer, not a byproduct of binary design. Hence consistency, human-readability, and reversibility will always take precedence over performance when it comes to internal systems. When uncertain, programs should prefer formats that read easily when opened as plain text, even if a faster way does exist.

## Repo structure

|Path|Purpose|
|---|---|
|assets/ | All the assets for the game, this is stuff out of the builds
|assets/disks/ | Disk image backups
|assets/steam/ | Steam related images
|deps/ | Some dependencies, I might not use them all.
|docs/ | The User facing docs, unprocessed zig build www builds
|fake_steam/ |Files used for the fake steamworks 
|steam/ | A small custom steam library for zig
|tests/ | Tests for in game (non zig) code.
|tools/ | Some zig tools for converting file formats and stuffs
|www/ | A submodule that is hosted on [SandEEE website](http://sandeee.prestosilver.info)

### Important docs

- [The metadocumentation](assets/docs/meta.md)
- [Lore sheet & reference](assets/docs/lore.md)
- [Trailer plans (GPT Generated)](assets/docs/gpt/gpt_trailer.md)
- [Rolling Bug/Todo List](assets/docs/todo.md)
- [Various **low pri** optimization ideas](assets/docs/opt_ideas.md)
- [Important asset listing](assets/docs/asset_listing.md)
- [Content asset listing](assets/docs/content_index.md)

## Legal stuffs & notices

### SandEEE's AI Policy

In early 2024 I was using AI a bit to aid with planning. In mid-late 2025 for personal reasons I decided to stop this practice, and with that have moved these documents into the repo and clearly labeled all stuff that was in some form AI processed. I do/will not be using these tools in the future, and will not exercise the thought. Any edits to these documents will be hand written.

### License

All of sandeees code, art, and other non audio files are under the MIT License, see [here](assets/licenses/CODE_LICENSE.md) for the full text. Any audio files are to be used only within SandEEE.