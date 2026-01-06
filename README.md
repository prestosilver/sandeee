# SandEEE OS

> **WARNING**❗Some of this repo contains spoilers for SandEEE, read docs outside of the README at your own risk.

## What is sandeee

SandEEE is a game! :open_mouth:

Actually though, sandeee is a programming game ment to be as emersive as possible. Pulling no punches when it comes to design and planning.

SandEEE assumes a world where text is the fundamental data layer, not a byproduct of binary design. Consistency, human-readability, and reversibility take precedence over performance when documenting internal systems. When uncertain, programs shall prefer formats that read easily when opened as plain text. Use this as a framework for any decision made, that will keep the project online to preform its vision well.

## Repo structure

|Path|Purpose|
|---|---|
|assets/ | All the assets for the game, this is stuff out of the builds
|assets/disks | Disk image backups
|assets/steam | Steam related images
|deps/ | Some dependencies, I might not use them all.
|docs/ | The User facing docs, unprocessed zig build www builds
|fake_steam/|Files used for the fake steamworks 
|steam/| A small custom steam library for zig
|tests/| Tests for in game (non zig) code.
|tools/| Some zig tools for converting file formats and stuffs
|www/| A submodule that is hosted on [SandEEE website](http://sandeee.prestosilver.info)

## Important docs

- [The metadocumentation](assets/docs/meta.md)
- [Lore sheet & reference](assets/docs/lore.md)
- [Trailer plans (GPT Generated)](assets/docs/gpt/gpt_trailer.md)
- [Rolling Bug/Todo List](assets/docs/todo.md)
- [Various **low pri** optimization ideas](assets/docs/opt_ideas.md)
- [Important asset listing](assets/docs/asset_listing.md)
- [Content asset listing](assets/docs/content_index.md)