# SandEEE Next Fest 2026 Weekend Timeline (Markdown Table Format)
> **THIS PHRASING IS GPT GENERATED BTW!!!!**, I leaded the ideas, I just dont have the energy to consolidate ideas quite yet

---

## 🗓️ Timeline Overview

| Weekend Range        | Focus Area                        | Key Tasks                                                                                        | Status |
|----------------------|-----------------------------------|--------------------------------------------------------------------------------------------------|:------:|
| Nov 8–9, 2025        | **Debugging / Threading**         | Begin reproducing Windows threading crash; log allocator and GC edge cases                       | 🟩
| Nov 15–16, 2025      | **Threading / Safe Mode**         | Integrate safe mode into threading logic for debugging; verify stability with sample workloads   | 🟩
| Nov 22–23, 2025      | **Windows Fix & QA**              | Finalize threading fix; confirm safe mode toggles properly and works cross-platform              | 🟩
| Nov 29–30, 2025      | **Core VM Polish**                | Audit stack ops, lazy ropes, and copy/dupe semantics; start improving debug symbol infrastructure| 🟩
| Dec 6–7, 2025        | **Graphics / PBO Integration**    | Implement `/gfx/pixel` PBO system and `/fake/tex/stride`; prepare for frame streaming tests      | 🟨
| Dec 13–14, 2025      | **Art Sprint #1**                 | Work on hero background, logo polish, and capsule mockups                                        | ⬜
| Dec 20–21, 2025      | **Video file format**             | Implement the video file format for files                                                        | ⬜
| Dec 27–28, 2025      | **Store Page Setup**              | Draft Steam page description, upload assets, tag features, and request early visibility          | ⬜
| Jan 3–4, 2026        | **Trailer Prep / Script**         | Write and lock script for the 3 Preston meeting video, finalize shot list and pacing             | ⬜
| Jan 10–11, 2026      | **Voice Recording**               | Record all Preston voices and clipped audio for trailer                                          | ⬜
| Jan 17–18, 2026      | **In-Game Capture Setup**         | Build Teams-style app in SandEEE; stage meeting window and camera layout                         | ⬜
| Jan 24–25, 2026      | **Trailer Filming (OBS)**         | Record final trailer sequence in-game, capture audio playback                                    | ⬜
| Jan 31–Feb 1, 2026   | **Art Sprint #2**                 | Produce additional Steam artwork and thumbnails                                                  | ⬜
| Feb 7–8, 2026        | **Demo QA (Safe Mode)**           | Test single-thread mode performance and tune load lag handling                                   | ⬜
| Feb 14–15, 2026      | **Linux Validation**              | Verify compatibility with Linux build, fix path case issues and timing bugs                      | ⬜
| Feb 21–22, 2026      | **Behind-the-Scenes Writeup**     | Write behind-the-scenes article explaining VM internals and fake file system                     | ⬜
| Feb 28–Mar 1, 2026   | **Community Seeding**             | Share teaser clips, post updates on Discords and socials, open tester signups                    | ⬜
| Mar 7–8, 2026        | **Demo Finalization**             | Lock demo build, finalize store materials, verify Steam upload and playtest                      | ⬜
| Mar 14–15, 2026      | **Milestone: Steam Approval**     | Submit final demo for Steam Next Fest listing and confirmation                                   | ⬜
| Apr–May 2026         | **Ongoing Promo & QA**            | Continue marketing, patching, and community engagement until Next Fest launch                    | ⬜

### Key

- 🟩: Done
- 🟨: Started
- ⬜: Complete

---

### ✅ Summary of Priorities

- [X] Fix Windows threading crash (safe mode debugging included)
- [ ] Build `/fake/gfx/pixel` + `/fake/gfx/stride` systems
- [ ] Create Teams-style in-game app for trailer
- [ ] Record voice and screen in OBS with no post-processing
- [ ] Produce and upload store visuals early to reduce crunch
- [ ] Lock Steam store page by **December 2025**
- [ ] Finalize demo and trailer by **March 2026**
- [ ] Target **Steam Next Fest June 2026**

---

## Overview Checklist

### 🧠 Core Development

- [X] Debug Windows threading crash (via Safe Mode)
- [X] Confirm GC & allocator stability under multithread
- [X] Implement ropes
- [X] Implement `/fake/gfx/stride`
- [ ] Integrate `/fake/gfx/` PBO
- [ ] Write audio queue system

### 🖼️ Art & Store

- [ ] Write final Steam description (with lore + tagline)
- [ ] Produce hero & capsule art early
- [ ] Gather screenshots of CRT/UI
- [ ] Create logo variant for capsule
- [ ] Submit store page for early review (Dec 2025)

### 🎥 Trailer

- [ ] Build in-game Teams-like app for trailer
- [ ] Record each Preston role separately (one take per role)
- [ ] Merge via clipped audio edits
- [ ] Record final trailer via OBS (no external post)
- [ ] Maintain “all in-game” authenticity

### 🧪 Demo

- [X] Enable Safe Mode as default for demo build
- [X] Test load time lag—style it as “Booting threads…”
- [X] Verify .eep and .ell integrity
- [ ] Ship Windows & Linux demo builds

### 📣 Release & Community

- [ ] Post early store link + GIFs on social
- [X] Set up small Discord for testers
- [ ] Steam Next Fest registration (May 2026)
