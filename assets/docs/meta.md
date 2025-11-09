# SandEEE Internal Documentation

## Notes about this document

- Things that shall happen are definite, while things that should happen are definite but only when applicable.
- This is the documentation for the documentation, no user facing docs will be repeated here.
    - This document shall not describe any specific behaviours, though the examples are from real docs, they may be upstream see the real docs if your referencing program specific info.
- Anywhere where this document has made a weird/odd decision, there will be a `Reason:` tag, everything else is either intuitive or a project wide assumption.
- This is all internal convention, as such not publicly released so users dont have to know this exists.
    - This means this document shall contain no fixes to issues, if the convention isnt for consistency (think fixes for things like import loops) this is the wrong place, and those bugs cannot be considered fixed.
- Something is considered user facing if the user can see it at any time, whether thats on www, or in any recovery image.
- Definition sections in this document are included for atypical features that already exist, but are not the same as tipical convention, or things that could be misinterpreted easily.
- All code in this document may have a heading or footer omitted, that will be indicated with a `...` at either the beginning or end of the file respectively
    - This will also have 1 empty line next to it, that is not part of the code so it may be ignored.
- Code examples here have the proper language tags, even though markdown doesn't highlight check the source if needed
- All formats defined here are assumed to always consist of this format, versioning is completely separate of this document.
    - If you need to see old docs roll the repo back
    - this is a style guide so make sure to use the latest version when writing docs
- user facing formats such as `.edf` and `.eds` are immutable and documented elsewhere.
    - Reason: Documenting one thing twice can cause contradictions later, and this document is less formal than user docs.

## General structure & rules

- All documentation shall be hosted on sandeee.prestosilver.info
    - this will be moved to a full domain once I get it
- All documentation shall be locally backed up in an alternative recovery image. if the user wants it in their image it can be copied in with a recovery script.
- Documentation will include no hidden files (starting with `_`)
- No dead links obviously, this shall be automatically checked.

### Syscalls

> Definition: A syscall is any assembly instruction that falls under the sys code, the one argument is a byte/number out of 255 that indicates the operation.

- A syscall is *hidden* if it is not documented in the general documentation
- Syscalls shall be documented exactly the same as instructions,

### Name Style Rules

- The SandEEE E is character Ⲉ (U+2C88) in unicode, and a standard E (capital) in ascii.
- SandEEE shall always be spelled SandEEE with the EEEch character for the SandEEE E in place of its Es.
- All SandEEE docs are written in the .edf format, see the user docs for that.
- EEE shall be pronounced "tripple E"
- EEE is always capitalized if in ascii, even in a subset of a program name
- slogan capitalization and formatting is `--- EEE Sees all ---`, centered if possible
    - Always a footer

### Style rules

- Doc names are the same case as what they are describing
    - file extension docs are named after their extension.
    - Encoding docs are named after the encodings acronym/shortend form
    - libraries are named after their .ell file name
- All docs shall include the main style sheet with `#style @www/docs/style.eds`
    - Code blocks are made with the `:code:`, `:code-edge:` and `:code-bad:` styles
        - Bad code is defined as: any line of code that, if left in place, will prevent that block of code from compiling.
        - :code: shall be wrapped in the :code-edge: style for compat.
        - :code-edge: lines have no text.
    - No text shall be centered unless its the footer, header, image, or diagram.
- All docs shall include the usual `:center: --- EEE Sees all ---` footer.
- All documents shall start with a `:center: -- Title --` style for the title.
    - After this this style will never be reused, use heading 2 then 1, then restructure. `-- H2 --` -> `- H1 -` -> redesign layout to avoid over indent.
- Normal text (unstyled), shall have one empty line preceding it.
- Code blocks shall be surrounded by blank lines
- Code blocks shall always have a heading describing their use.
- Links in docs shall use only relative paths.
    - Important for relocation, docs shall contain no reliance at all about where theyre hosted
- Back paths are under the title for documents.
- Examples shall be wrapped with :example-start:, and :example-end:

### Index pages

- Index pages shall exist for every folder, **including** the root.
- They shall have a list of all sibling files or subdirs, but never both ie. if a subdir is needed there can be no siblings.
- Index files shall never be linked to, except in backlinks, or the parent directory.

### Examples

Code
```edf
...

:example-start: Example code block
:example:       :code-edge:
:example:       :code:    | This does stuff
:example:       :code:    | More stuff
:example:       :code-bad:| This breaks my code
:example:       :code-edge:
:example-end:

...
```

Document structure
```edf
#style @/docs/style.eds

:center: -- VM Op-Codes --
> Back: @index.edf

-- Info and things --
- Info -
This is documenting info 

- Stuff -
This is documenting stuff

:center: --- EEE Sees all ---
```

### Exact folder structure

- www/docs/index.edf
- www/docs/style.eds
- www/docs/assembly/
    - www/docs/assembly/index.edf
    - www/docs/assembly/instructions/
        - www/docs/assembly/instructions/index.edf
        - www/docs/assembly/instructions/nop.edf
- www/docs/encodings/
    - www/docs/encodings/index.edf
    - www/docs/encodings/EEEch.eia
- www/docs/binaries/
    - www/docs/binaries/index.edf
    - www/docs/binaries/eia.edf
    - www/docs/binaries/ell.edf
    - www/docs/binaries/epk.edf
    - www/docs/binaries/eep.edf
    - www/docs/binaries/eme.edf
    - www/docs/binaries/era.edf
- www/docs/text/
    - www/docs/text/index.edf
    - www/docs/text/eon.edf
    - www/docs/text/edf.edf
    - www/docs/text/eds.edf
    - www/docs/text/eln.edf
- www/docs/files/
    - www/docs/files/index.edf
    - www/docs/files/images/
        - www/docs/files/images/index.edf
        - www/docs/files/images/ui.edf
    - www/docs/files/libraries/
        - www/docs/files/libraries/index.edf
        - www/docs/files/libraries/eon.edf
        - www/docs/files/libraries/asm.edf
- www/docs/errors/
    - www/docs/errors/index.edf
    - www/docs/errors/asm.edf
    - www/docs/errors/eon.edf

## Formats and uses

- Files in SandEEE will **always** use EEE file formats
- All downloads in the documents shall use `.epk` files
- All EEE file extensions start with `.e`

| Format | builtin | Used for  | Notes |
|--------|-|-----------|---|
|.eee    |✔| Disk images
|.epk    |✔| Recovery scripts<br>Packages
|.eap    |✖| Archives
|.era    |✔| Audio files
|.edf    |✔| Rich text documents
|.eds    |✔| Rich text document style
|.ell    |✖| Libraries | libload.ell is raw code
|.eln    |✔| Shortcuts
|.eep    |✔| Executables

### EEEch Format

> Definition: EEEch (ⲈⲈⲈch in game) is SandEEE's native character encoding, serving as a direct drop-in replacement for ASCII.

- EEEch uses single byte specs, there is no character longer than one.
- EEEch has color symbols, and emojis, though those should not be used in docs.

## Text file extensions

> Definition:
> A text file is a file format that does not solely depend on the EEEch format.
> ie. it is all readable plain text that with no binary structure.

- All text files shall be named with 3 letter lowercase extensions.
- All text file docs shall be listed under categories named `text`
- A text format is considered "Builtin" if it is parsed by SandEEE itself rather than an `.eep` program
- Docs shall specify if a file format is builtin
- Grammar definitions shall be under a heading labeled `Grammar`
    - Each grammar rule is started with a `:rule:` styled line
    - This is followed by each value this rule can convert to
    - The first rule should always be named the same as the file format, following rules are breadth first.
    - The EOF keyword shall always represent the end of the file
    - The ALPHA keyword in grammer refers to any EEEch lowercase or capital letter, this does not include the SandEEE e
    - The NUMBER keyword in grammer refers to any number character 0-9

Example:
```md
#style @/docs/style.eds

:center: -- Eon --
-- Grammar --
:rule: Eon
-> EOF
-> Statement EOF

:rule: Statement
-> Expression
-> Expression ";" Statement

:rule: Expression
-> Identifier

:rule: Identifier
-> ALPHA+

:center: --- EEE Sees all ---
```

## Binary file extensions

> Definition:
> A binary file is a file format that may include EEEch encoded text, but depends on binary encodings too.

- All binary files shall be named with 3 letter lowercase extensions.
- All binary file docs shall be listed under categories named `binaries`, to keep things consistent that means no shortening to "bins".
- A binary format is considered "Builtin" if it is parsed by SandEEE itself rather than an `.eep` program
- Everything has 4 char magic, capitalization will be inconsistent. Docs shall mention this first in the format definition, followed by format specs.
- File extensions shall be listed in the same line as what the file does
    - Format `File usecase (extensions)`
- Format shall **never** use int names, it shall always be a character width.
    - Reasoning: SandEEE was made in a world where strings are fast, so they are more conventional.
- All docs shall be in .edf format
- Everything after the magic shall be in a `Data` secion
- Formats are ordered lists, syntax
- Binary files shall be given a proper name, ex. for eia can be called "EEE Image Array"
- Docs shall specify if a file format is builtin
- Proper unitys for this is chars, label ch.
    - Section repetitions are specified by starting a line with repeat.
    - Expressions can exist, only if they are based off previous entries.
    - Expressions can only use multiplication and addition.

### Classic constructs

> Definition: Classic constructs are common things that will be represented alot, but not a single character.

- Colors
    - Alpha is never the name of a channel in docs
    - Red, Green, Blue, and *Transparent*
    - 32 bpp, 8888RGBA
- Strings
    - 2 bytes for length followed by the value
    - **NEVER** null terminated
        - Reasoning: SandEEE was made in a world where strings take 8 bytes always, so null terminators were slower.
- Numbers
    - All ints shall be big->small, eg: 2 width = [1]\*256^1 + [2]\*256^0
    - Widths are 1, 2, 4, 8. Nothing bigger.

### Example

```edf
...

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

...
```

## Instruction documentation

- Instruction 255 is documented outside of the docs site as it is a "backdoor instruction"
- Documentation for each instruction shall include how it modifies the stack
    - \- Popped +Pushed
- Instruction documentation shall include every case of popped values, string or int
- All potential edge cases shall be explicitly explained and tagged with the :edge: style
- Examples are tagged with `:example:`

Example
```edf
#style @/docs/style.eds

:center: -- (0x04) Add --
-- String, Number --
:mods: -2 +1
Removes n characters from the start of a string.

:example: "fdsa" 2 => "sa"
:edge: There is no error when there is not enough chars: "f" 3 => ""

-- Number, Number --
:mods: -2 +1
Adds 2 numbers

:example: 3 2 => 5
:edge:  "f" 3 => ""

:center: --- EEE Sees all ---
```

## Image files

- All non icon image files shall be documented separately, while icons are documented in an `icons` category.
- Image file documentation shall be put inside a `images` group
- Image file documentation shall be named identically to the image file
- Image documentation shall contain a preview image directly after the page title
    - The line adding preview image shall have 1 line of whitespace before and after it
    - Use the style `:preview-image:` for the preview image
    - This shall be stored next to the image file, with the same name
- Following that there shall be a summary section defining how the image is used.
- Following that there shall be a more descriptive area for per sprite documentation
- Sprite areas are 1 indexed rectanges with the format `X,Y WxH` followed by ` | Description`

Example:
```edf
#style @/docs/style.eds

:center: -- /cont/imgs/ui.eia --
:preview-image: [@ui.eia]

-- Summary --
The image used for ui assets.

-- Sizes --
8x8 sprites

-- Sprites and locations --
- Scroll Bar -
1,1 2x2 | Top of the scroll bar
1,3 2x1 | The scrollable area of a scroll bar
1,4 2x1 | The top of the handle of the scroll bar
1,5 2x1 | The middle of the handle of the scroll bar
1,6 2x1 | The bottom of the handle of the scroll bar
1,7 2x2 | Bottom of the scroll bar

-- Containers --
3,1 1x1 | A manually sizable frame outline
4,1 1x1 | A manually sizable frame fill
3,2 2x2 | A container outline, the middle third of this region is stretched
3,2 2x2 | A container outline, the middle third of this region is stretched

-- Input regions --
3,4 1x1 | A manually sizable input outline
4,4 1x1 | A manually sizable input fill
4,5 1x1 | The overlay for highlighted text

-- Check boxes --
5,7 2x2 | An unchecked box
7,7 2x2 | A checked box


:center: --- EEE Sees all ---
```

## Shell Commands

- Every shell command will return a properly named error on invalid input.
- When a shell command fails
    - If there are no args passed then display the help
    - If args are passed print the error and some related info
- Every shell command shall require atleast one argument

### Help syntax

- All commands shall have a help message
- Help messages shall have a line showing full usage with all possible flags
    - Flags are unordered, other than help with is the first thing following the command.
    - Args can be before after or inbetween flags
- After that there shall be a empty line followed by a complete sentence description of the programs purpose, followed by another newline.
- Finally, there shall be a list of every argument followed by a complete sentence usage.
- Programs may also list bugs or quirks after the arguments with a blank line preceding them.
- Parameter lists are formatted with a tab following the parameter ":parameter\tusage"
    - The help paramters description is always "Displays this message"
- Required arguments and Optional arguments should have headings with the format `- Optional Arguments -` and `- Required Arguments -` respectively
- Required arguments shall not include files unless no file means the program cannot run at all
    - This means all editors can run without a file loaded
    
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

- All library docs shall be listed under categories labeled `libraries`, to keep things consistent that means no shortening to "libs".
- Functions shall list names, eon call signature, and any errors they can raise.
    - For errors, the library shall list each error and what caused that, in a complete sentence description.
- Errors shall not include the name of the library, ex. No "TextureFileNotFound", use "FileNotFound".

## Styles

- Every format shall have a style guide in this document
- Where possible every format should include the `--- EEE Sees all ---` footer

### eds

- Each style shall have no spacers between their name and definition.
- Each style shall have no repeated definitions.
- The default style shall not be modified.
- Wrapper styles shall be named as :wrap-start:, and :wrap-end:, or :wrap-edge: if theyre the same.
    - If the style is required per line, then also include :wrap:

Example:
```eds
#logo
align: Center
scale: 6.0

#biglink
align: Center
scale: 1.5

#h3
scale: 1.5

#hs
scale: 1.5
align: Center
prefix: +
suffix: +

#red
color: FF0000
align: Center

#code
prefix: |     |

#code-bad
color: FF0000
prefix: | BAD |

#code-edge
prefix: +-----+

#example-start
prefix: ---- Example:

#example-end
prefix: ----

#example
offset: 2
```

### edf

see [Style Rules](#style-rules)

### asm

- Assembly can be commented on stack states on user facing code
    - The top of the stack is the end of the line
- Assembly files should be kept eon compatible where possible
- loop labels shall start with `loop_`
- procedural labels shall start with `proc_`
- There are no labels named functions in EEE asm
- Conditional labels shall start with `cond_`
- Other labels dont have any prefix
- Labels shall be in lowerCamelCase, minus their prefix. ex. `proc_doSomething:`
- Since labels are free, exported procs are double labeled
- Asm files shall have a footer of `; --- EEE Sees all ---`
- All asm code files shall be annotated with a header comment
    - first line is title, 2nd is EEE and then year (5 years before the current year), and then a blank comment line (`;`)
    - Then any info in a header, bugs first then explanation, no examples in asm code though.
        - Reason: Top level examples are repetitive, libraries will be documented per function, and executables in the help message.
- The main function shall be labeled even if its never called by asm.
- The main function comes first, no call/jump

Example:
```asm
; SandEEE example Code
; EEE 2020
;
; TODO: implement test2

proc_main:
    push 0
    ret

; This proc is an example function.
; The first argument is an example parameter.
; The second is also an example parameter
proc_test: ; arg1 arg2
    ; do nothing with my arguments
    disc 2

    ; Return zero
    push 0
    ret

; This function is an example function.
; There are no arguments
proc_test2:
    push "Unimplemented"
    sys 18

; --- EEE Sees all ---
```

### eon

- Eon programs shall always `#include "/libs/incl/consts.eon"`.
- Eon programs shall `#include "/libs/incl/sys.eon"` if they need to call syscalls
- All functions shall have a documentation coment preceding them
    - For main this is ignored
- The main function shall be at the end of a file
- When calling a lib function the `"function"()` syntax shall never be used.
- Assembly functions shall be commented after their signature line, and not use `return x;`, rather use the `asm "ret";`
- If something returns a "void" value it shall `return void;` this keyword is defined in `/libs/incl/consts.eon`, and is 0.
- Main shall always `return void`, errors are raised through `error(text)` in std.
- All branches outside of assembly functions shall end with either a `return`, or a `error()`
- There shall be no trailing code after a `return` or `error()`
- All eon code files shall be annotated with a header comment
    - first line is title, 2nd is EEE and then year (5 years before the current year), and then a blank comment line (`//`)
    - Then any info in a header, bugs first then explanation, no examples in eon code though.
        - Reason: Top level examples are repetitive, libraries will be documented per function, and executables in the help message.
- There shall be a single line of whitespace after the header comment
- There shall be a single line of space after includes (if used)
- There shall be a single line of space after imports (if used)
- There shall be a single line of space after consts.
- There shall be a single line of space after every function
- Imports and Includes shall both contain no empty lines
- Includes come first, then imports
- Consts can be separated by at most one line of space.
- Eon files shall be indented by 4 spaces.
- Eon files shall have a footer of `// --- EEE Sees all ---`

Example:
```eon
// SandEEE Example code
// EEE 2020
//
// TODO: implement test2

#include "/libs/incl/consts.eon"

#import "/libs/func/heap.ell"

// This function is an example function.
// The first argument is an example parameter.
// The second is also an example parameter
fn test(arg1, arg2) {
    return void;
}

// This function is an example function.
fn test2() {
    error("Unimplemented");
}

fn main() {
    return void;
}

// --- EEE Sees all ---
```

## Errors

> Definition: Errors are considered unrecoverable, and critical. Anywhere in this document where the word error is used its refering to the associated syscall.
> If something else happens, say a recoverable error like an invalid input this shall be handled by code rather than in the asm.

### Conventions

- All memory errors are all named `AllocatorFault`.
    - Reason: the few cases that cause these are super rare, out of memory, double free, etc. that they can be grouped on user end.
- Todo errors are named `Unimplemented`
- Errors can give more information after their name with a ` - ` as separation.
- Stream errors shall be caught and handled, with a valid reason & file printed to the user.
- Programs shall handle all runtime conditions gracefully and never terminate unexpectedly, this includes erroneous inputs.
- Errors of the same type but different cause should have the same prefix, this uses camel case

## Versioning

- EEE uses a system called EEEvolution to document versions
- Every version starts with a codeword for the program its representing,
- This is followed by a colon
- This is followed by the state of the program, in our world there is alpha, beta, release, in SandEEE there is Seed, Sapling, Tree
- Finally there is a # followed by the current public build, and a _ for the build number
- On a major increment seed->sapling the number resets
- Bug fixes shall not increment the version, but they shall incrmement the build
- Build numbers never reset, but are up to the program to document what it means and how its increment

Examples:
```text
os:seed#3_542     -> Development build 542 of third public seed branch
os:sapling#0_1034 -> First sapling release (reset)
os:tree#0_30545   -> Initial stable release
```

## Final Notes

SandEEE assumes a world where text is the fundamental data layer, not a byproduct of binary design. Consistency, human-readability, and reversibility take precedence over performance when documenting internal systems. When uncertain, programs shall prefer formats that read easily when opened as plain text. Use this as a framework for any decision made, that will keep the project online to preform its vision well.