# SandEEE Internal Documentation

## Notes about this document

- In this document things that *Should* happen are equivalant to things that *Shall* happen. Things that may happen are not welcome here.
- Same with *will*, though *will* should **only** be used in a manner out of naming. Think: strings will be represented this way, vs errors shall be represented this way.
- Anywhere where this document has made a weird/odd decision, there should be a `Reason:` tag, everything else is either intuitive or a project wide assumption.
- This is all internal convention, as such not publicly released so users dont have to know this exists.
    - This means this document should contain no fixes to issues, if the convention isnt for consistency (think fixes for things like import loops) this is the wrong place, and those bugs cannot be considered fixed.
- This document should not describe any specific behaviours, though the examples are from real docs, they may be upstream see the real docs if your referencing program specific info.
- Something is considered user facing if the user can see it at any time, wether thats on www, or in any recovery image.
- Definition sections in this document are included for atipical features that already exist, but are not the same as tipical convention, or things that could be misinterpreted easily.

## General structure & rules

- All documentation should be hosted on sandeee.prestosilver.info (or a full domain once I get it).
- All documentation should be locally backed up in an alternative recovery image. if the user wants it in their image it can be copied in with a recovery script.

### Syscalls

> Definition: A syscall is any assembly instruction that falls under the sys code, the one argument is a byte/number out of 255 that indicates the operation.

- A syscall is considered *hidden* if it is not documented in the general documentation

### Name Style Rules

- The SandEEE E is character Ⲉ (U+2C88) in unicode, and a standard E (captial) in ascii.
- SandEEE should always be spelled SandEEE with the EEEch character for the SandEEE E in place of its Es.
- All SandEEE docs are written in the .edf format, see the docs for that.
- EEE is pronounced "tripple E"
- EEE is always capitalized if in ascii, even in a subset of a program name

### Style rules

- Doc names are the same case as what they are describing
    - file extension docs are named after their extension.
    - Encoding docs are named after the encodings acronym/shortend form
    - libraries are named after their .ell file name
- All docs should include the main style sheet with `#style @www/docs/style.eds`
    - Code blocks can be made with the `:code:`, `:code-edge:` and `:bad-code:` styles
        - Bad code is defined as: any line of code that if not excluded will prevent that block of code from compiling.
        - :code: should be wrapped in the :code-edge: style for compat.
        - :code-edge: lines have no text.
    - nothing should be centered.
- All docs should include the usual `:center: --- EEE Sees all ---` footer.
- All documents should start with a `:center: -- Title --` style for the title.
    - After this this style will never be reused, use heading 2 then 1, then restructure. `-- H2 --` -> `- H1 -` -> redesign layout to avoid over indent.
- Normal text (unstyled), should have one empty line preceding it.
- Code blocks should be surrounded by blank lines
- Code blocks should always have a heading describing their use.
- Links in docs should use only relative paths.
- Back paths are under the title for documents.

### Index pages

- Index pages should exist for every folder, including the root.
- They should have a list of all sibling files, xor subdirs, if a subdir is needed there can be no siblings.
- Index files should never be linked to, except in backlinks.

### Examples

Code
```edf
Example code block
:code-edge:
:code:    | This does stuff
:code:    | More stuff
:bad-code:| This breaks my code
:code-edge:
```

Document structure
```edf
:center: -- VM Op-Codes --
> Back: @index.edf

-- 0x00 NOP --
Does nothing

-- 0x03 ADD --
- String on top of stack -
Shifts the beggining of a string, by an integer value.

- Integer at the beggining of the stack -
Adds the top 2 values on the stack.

:center: --- EEE Sees all ---
```

### Exact folder structure

- www/docs/index.edf
- www/docs/style.eds
- www/docs/encodings/
    - www/docs/encodings/index.edf
    - www/docs/encodings/EEEch.eia
- www/docs/binaries
    - www/docs/binaries/index.edf
    - www/docs/binaries/eia.edf
    - www/docs/binaries/ell.edf
    - www/docs/binaries/epk.edf
    - www/docs/binaries/eep.edf
    - www/docs/binaries/eme.edf
    - www/docs/binaries/era.edf
- www/docs/text
    - www/docs/text/index.edf
    - www/docs/text/eon.edf
    - www/docs/text/edf.edf
    - www/docs/text/esf.edf
- www/docs/libraries
    - www/docs/libraries/index.edf
    - www/docs/libraries/eon.edf
    - www/docs/libraries/asm.edf
- www/docs/errors
    - www/docs/errors/index.edf
    - www/docs/errors/asm.edf
    - www/docs/errors/eon.edf

## Text file extensions

> Definition:
> A text file is a file format that does not soley depend on the EEEch format.

- All text files should be named with 3 letter lowercase extensions.
- All text file docs should be listed under categories named `text`
- A text format is considered "Builtin" if it is parsed by SandEEE itsself rather than an `.eep` program
- Docs should specify if a file format is builtin

### Example

```md
TODO
```

## Binary file extensions

> Definiton:
> A binary file is a file format that does not soley depend on the EEEch format.

- All binary files should be named with 3 letter lowercase extensions.
- All binary file docs should be listed under categories named `binaries`, to keep things consistent that means no shortening to "bins".
- A binary format is considered "Builtin" if it is parsed by SandEEE itsself rather than an `.eep` program
- Everything has 4 char magic, capitalization will be inconsistent. Docs should mention this first, followed by format specs.
- File extensions should be listed in the same line as what the file does
    - Format `File usecase (extensions)`
- Format should **never** use int names, it should always be a character width.
    - Reasoning: SandEEE was made in a world where strings are fast, so they are more conventional.
- All docs should be in .edf format
- Everything after the magic should be in a `Data` secion
- Formats are ordered lists, syntax
- Binary files should be given a proper name, ex. for eia can be called "EEE Image Array"
- Docs should specify if a file format is builtin
- Proper unitys for this is chars, label ch.
    - Section repetitions can be specified by starting a line with repeat.
    - Expressions can exist, only if they are based off previous entries.
    - Expressions can only use multiplication and addition.

### Classic constructs

> Defintion: Classic constructs are common things that will be represented alot, but not a single character.

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

```edf
-- Image files (.eia) --

| - Magic: 4ch = "eimg"
| - Data:
|     - Width: 4ch
|     - Height: 4ch
|     - Pixels: Repeat Width * Height
|         - Red: 1ch
|         - Green: 1ch
|         - Blue: 1ch
|         - Transparent: 1ch
```

## Shell Commands

- Every shell command will return a properly named error on invalid input.
- When a shell command fails
    - If there are no args passed then display the help
    - If args are passed print the error and some related info
- Every shell command should require atleast one argument

### Help syntax

- All commands should have a help message
- Help messages should have a line showing full usage with all possible flags
    - Flags are unordered, other than help with is the first thing following the command.
    - Args can be before after or inbetween flags
- After that there should be a empty line followed by a complete sentence description of the programs purpose, followed by another newline.
- Finally, there should be a list of every argument followed by a complete sentence usage.
- Programs can also list bugs or quirks after the arguments with a blank line preceding them.
- Parameter lists are formatted with a tab following the parameter ":parameter\tusage"
    - The help paramters description is always "Displays this message"
- Required arguments and Optional arguments should have headings with the format `- Optional Arguments -` and `- Required Arguments -` respectivly

Example: 
```text
edit [:help] [:new] [file]

- Optional Arguments -
:help      Displays this message.
:new       Dont load the file, just make a new one.
file       Specify which file to load

Opens a file in EEEdit.
```

If no file is provided the editor will open without a file loaded.

## Libraries

- All library docs should be listed under categories labeled `libraries`, to keep things consistent that means no shortening to "libs".
- Functions should list names, eon call signature, and any errors they can throw.
    - For errors, the library should list each error and what caused that, in a complete sentence description.
- Errors should not include the name of the library, ex. No "TextureFileNotFound", use "FileNotFound".

## Styles

- Every format should have a style guide in this document

### edf

### asm

- Assembly can be commented on stack states on user facing code
- loop labels should start with `loop_`
- procedural lablels should start with `proc_`
- Conditional labels should start with `cond_`
- Other labels dont have any prefix
- Labels should be in lowerCamelCase, minus their prefix. ex. `proc_doSomething:`
- Since labels are free, exported procs are double labeled

### eon

- Eon programs should always `#include "/libs/incl/consts.eon"`.
- Eon programs should `#include "/libs/incl/sys.eon"` if they need to call syscalls
- All functions should have a documentation coment preceding them
    - For main this is ignored
- The main function should be at the end of a file
- When calling a lib function the `"function"()` syntax should never be used.
- Assembly functions should be commented after their signature line, and not use `return x;`, rather use the `asm "ret";`
- If something returns a "void" value it should `return void;` this keyword is defined in `/libs/inc/consts.eon`, and is 0.
- Main should always `return void`, errors are raised through `error(text)` in std.

Example:
```eon
#include "/libs/incl/consts.eon"

#import "/libs/func/heap.ell"

fn test(arg1, arg2) {
    return void;
}

fn main() {
    return void;
}
```

## Errors

> Definition: Errors are considered unrecoverable, and critical. Anywhere in this document where the word error is used its reffering to the associated syscall.
> If something else happens, say a recoverable error like an invalid input this should be handled by code rather than in the asm.

### Conventions

- All memory errors are all named `AllocatorFault`.
    - Reason: the few cases that cause these are super rare, out of memory, double free, etc. that they can be grouped on user end.
- Stream errors should be caught and handled, with a vaild reason & file printed to the user.
- Programs should not crash (obviously), this includes erroneous inputs.