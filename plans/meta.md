# Documentation overview

## File extensions

- Everything has 4 char magic, capitalization will be inconsistent. Docs should mention this first, followed by format specs.
- File extensions should be listed in the same line as what the file does
    - Format `File use (extensions)`
- Format should **never** use int names, it should always be a character width.
    - Reasoning: SandEEE was made in a world where strings are fast, so they are more used.

- Everything after the magic should be in a `Data` secion
- Formats are ordered lists, syntax

### Classic constructs

- Colors
    - Alpha is never the name of a channel in docs
    - Red, Green, Blue, and *Transparent*
    - 32 bpp, 8888RGBA
- Strings
    - 2 bits for length followed by the value
    - **NEVER** null terminated
        - Reasoning: SandEEE was made in a world where strings take 8 bytes always, so null terminators were slower.
- Numbers
    - All ints should be big->small, eg: 2 width = [1]\*256^1 + [2]\*256^0
    - Widths are 1, 2, 4, 8. Nothing bigger.

### Example

```md
# Image files (.eia)

- Magic: 4 = "eimg"
- Data:
    - Width: 4
    - Height: 4
    - Pixels: Repeat Width * Height
        - Red: 1
        - Green: 1
        - Blue: 1
        - Transparent: 1
```