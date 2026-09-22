# Horizontal slice needed

SandEEE has had a pretty strong vertical slice for a while as the demo. This document will explain my plans to expand that out to a horizontal slice.

## Divide and conquer

Since sandeee has a "correct" route will split this route into segments at the most important parts of this, fleshing those out first. I will then fill out the space in between by splitting those.

First split will be the seperate disk upgrades, see `Implementation plans, order, and progress` inside [lore.md](lore.md). Currently the game does not implement disk encryption, so itll be important to flag these inside build.zig.

After that there are some obvious splits containing important events:

- SandEEEs as a story
    - Phase 1: Initial disk
        - Create save, important to reference joe moe for pt 2
        - Epsilon leaks rob r's password in readme
        - Demo, learn to decrypt
        - Find Joe Moes password
    - Phase 2: Factual upgrade
        - Upgrade from disk 2, final demo should end here?
        - Start logging into other peoples accounts
        - Find epsilons password
    - Phase 3: Epsilon personal disk
        - Figure out how to use sys 255
        - Start reading epsilons emails which were a common stopping point in the previous acts.

## Reqs

This implies a few future features not yet implemented are required for a MVP:
- Disk encryption (Could be hardcoded for MVP)
- New email system (Could be simulated for MVP)
- Joe moes disk
- Sys 255