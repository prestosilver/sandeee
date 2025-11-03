# SandEEE Internal Documentation

## Notes about this document

- In this document things that **Should** happen are equivalant to things that **Shall** happen. Things that may happen are not welcome here.
- Same with *will*, though will should **only** be used in a manner out of naming. Think: strings will be represented this way, vs errors shall be represented this way.
- Anywhere where this document has made a weird/odd decision, there should be a `Reason:` tag, everything else is either intuitive or a project wide assumption.
- This is all internal convention, as such not publicly released so users dont have to know this exists.
    - This means this document should contain no fixes to issues, if the convention isnt for consistency (think fixes for things like import loops) this is the wrong place, and those bugs cannot be considered fixed.
- This document should not describe any specific behaviours, though the examples are from real docs, they may be upstream see the real docs if your referencing program specific info.
- Something is considered user facing if the user can see it at any time, wether thats on www, or in any recovery image.
- Definition sections in this document are included for atipical features that already exist, but are not the same as tipical convention, or things that could be misinterpreted easily.
- All code in this document may have a heading or footer omitted, that will be indicated with a `...` at either the begining or end of the file respectively
    - This will also have 1 empty line next to it, that is not part of the code so it may be ignored.
- Code examples here have the proper language tags, even though markdown dosent highlight check the source if needed

## General structure & rules

- All documentation should be hosted on sandeee.prestosilver.info
    - this will be moved to a full domain once I get it
- All documentation should be locally backed up in an alternative recovery image. if the user wants it in their image it can be copied in with a recovery script.
- Documentation will include no hidden files (starting with `_`)
- No dead links obviously, this should problaby be automatically checked.

### Syscalls

> Definition: A syscall is any assembly instruction that falls under the sys code, the one argument is a byte/number out of 255 that indicates the operation.

- A syscall is considered *hidden* if it is not documented in the general documentation

### Name Style Rules

- The SandEEE E is character Ⲉ (U+2C88) in unicode, and a standard E (captial) in ascii.
- SandEEE should always be spelled SandEEE with the EEEch character for the SandEEE E in place of its Es.
- All SandEEE docs are written in the .edf format, see the docs for that.
- EEE is pronounced "tripple E"
- EEE is always capitalized if in ascii, even in a subset of a program name
- slogan capitalization and formatting is `--- EEE Sees all ---`, centered if possible
    - Always a footer

### Style rules

- Doc names are the same case as what they are describing
    - file extension docs are named after their extension.
    - Encoding docs are named after the encodings acronym/shortend form
    - libraries are named after their .ell file name
- All docs should include the main style sheet with `#style @www/docs/style.eds`
    - Code blocks can be made with the `:code:`, `:code-edge:` and `:code-bad:` styles
        - Bad code is defined as: any line of code that if not excluded will prevent that block of code from compiling.
        - :code: should be wrapped in the :code-edge: style for compat.
        - :code-edge: lines have no text.
    - nothing should be centered unless its the footer, header, image, or diagram.
- All docs should include the usual `:center: --- EEE Sees all ---` footer.
- All documents should start with a `:center: -- Title --` style for the title.
    - After this this style will never be reused, use heading 2 then 1, then restructure. `-- H2 --` -> `- H1 -` -> redesign layout to avoid over indent.
- Normal text (unstyled), should have one empty line preceding it.
- Code blocks should be surrounded by blank lines
- Code blocks should always have a heading describing their use.
- Links in docs should use only relative paths.
    - Important for relocation, docs should contain no reliance at all about where theyre hosted
- Back paths are under the title for documents.
- Examples should be wrapped with :example-start:, and :example-end:

### Index pages

- Index pages should exist for every folder, **including** the root.
- They should have a list of all sibling files, xor subdirs, if a subdir is needed there can be no siblings.
- Index files should never be linked to, except in backlinks.

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
- All downloads in the documents will be `.epk` files
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

## Text file extensions

> Definition:
> A text file is a file format that does not soley depend on the EEEch format.

- All text files should be named with 3 letter lowercase extensions.
- All text file docs should be listed under categories named `text`
- A text format is considered "Builtin" if it is parsed by SandEEE itsself rather than an `.eep` program
- Docs should specify if a file format is builtin

Example:
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
- Documentation for each instruction should include how it modifies the stack
    - \- Popped +Pushed
- Instruction documentation should include every case of popped values, string or int
- Edge cases that may be ambiguous should be explained and tagged with the `:edge:` style
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

- All non icon image files should be documented seperately, while icons are documented in an `icons` category.
- Image file documentation should be put inside a `images` group
- Image file documentation should be named identically to the image file
- Image documentation should contain a preview image directly after the page title
    - The line adding preview image should have 1 line of whitespace before and after it
    - Use the style `:preview-image:` for the preview image
    - This should be stored next to the image file, with the same name
- Following that there should be a summary section defining how the image is used.
- Following that there should be a more descriptive area for per sprite documentation
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
- Required arguments should not include files unless no file means the program cannot run at all
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

- All library docs should be listed under categories labeled `libraries`, to keep things consistent that means no shortening to "libs".
- Functions should list names, eon call signature, and any errors they can throw.
    - For errors, the library should list each error and what caused that, in a complete sentence description.
- Errors should not include the name of the library, ex. No "TextureFileNotFound", use "FileNotFound".

## Styles

- Every format should have a style guide in this document

### eds

- Each style should have no spacers between their name and definition.
- Each style should have no repeated definitions.
- The default style should not be modified.
- Wrapper styles should be named as :wrap-start:, and :wrap-end:, or :wrap-edge: if theyre the same.
    - If the style is required per line, then also include :wrap:
- Center should be used sparingly in actual doc styles, if its not for empasis its not nessessary.

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
- loop labels should start with `loop_`
- procedural lablels should start with `proc_`
- There are no labels named functions in EEE asm
- Conditional labels should start with `cond_`
- Other labels dont have any prefix
- Labels should be in lowerCamelCase, minus their prefix. ex. `proc_doSomething:`
- Since labels are free, exported procs are double labeled
- Asm files should have a footer of `; --- EEE Sees all ---`
- All asm code files should be annotated with a header comment
    - first line is title, 2nd is EEE and then year (5 years before the current year), and then a blank comment line (`;`)
    - Then any info in a header, bugs first then explanation, no examples in asm code though.
        - Reason: Top level examples are repetitive, libraries will be documented per function, and executables in the help message.
- The main function should be labeled even if its never called by asm.
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

- Eon programs should always `#include "/libs/incl/consts.eon"`.
- Eon programs should `#include "/libs/incl/sys.eon"` if they need to call syscalls
- All functions should have a documentation coment preceding them
    - For main this is ignored
- The main function should be at the end of a file
- When calling a lib function the `"function"()` syntax should never be used.
- Assembly functions should be commented after their signature line, and not use `return x;`, rather use the `asm "ret";`
- If something returns a "void" value it should `return void;` this keyword is defined in `/libs/inc/consts.eon`, and is 0.
- Main should always `return void`, errors are raised through `error(text)` in std.
- All branches outside of assembly functions should end with either a `return`, or a `error()`
- There should be no trailing code after a `return` or `error()`
- All eon code files should be annotated with a header comment
    - first line is title, 2nd is EEE and then year (5 years before the current year), and then a blank comment line (`//`)
    - Then any info in a header, bugs first then explanation, no examples in eon code though.
        - Reason: Top level examples are repetitive, libraries will be documented per function, and executables in the help message.
- There should be a single line of whitespace after the header comment
- There should be a single line of space after includes (if used)
- There should be a single line of space after imports (if used)
- There should be a single line of space after consts.
- There should be a single line of space after every function
- Imports and Includes should both contain no empty lines
- Includes come first, then imports
- Consts can be seperated by at most one line of space.
- Eon files should be indented by 4 spaces.
- Eon files should have a footer of `// --- EEE Sees all ---`

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

> Definition: Errors are considered unrecoverable, and critical. Anywhere in this document where the word error is used its reffering to the associated syscall.
> If something else happens, say a recoverable error like an invalid input this should be handled by code rather than in the asm.

### Conventions

- All memory errors are all named `AllocatorFault`.
    - Reason: the few cases that cause these are super rare, out of memory, double free, etc. that they can be grouped on user end.
- Todo errors are named `Unimplemented`
- Errors can give more information after their name with a ` - ` as seperation.
- Stream errors should be caught and handled, with a vaild reason & file printed to the user.
- Programs should not crash (obviously), this includes erroneous inputs.
