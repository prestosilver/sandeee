# Documentation overview

## General structure & rules

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

### Exact structure

- www/docs/index.edf
- www/docs/encodings/
    - www/docs/encodings/EEEch.eia
- www/docs/binaries
    - www/docs/binaries/index.edf
    - www/docs/binaries/eia.edf
    - www/docs/binaries/ell.edf
    - www/docs/binaries/epk.edf
    - www/docs/binaries/eee.edf
    - www/docs/binaries/eme.edf
    - www/docs/binaries/era.edf
- www/docs/text
    - www/docs/text/index.edf
    - www/docs/text/eon.edf
    - www/docs/text/edf.edf
    - www/docs/text/esf.edf
- www/docs/programs
    - www/docs/libraries/index.edf
    - www/docs/libraries/eon.edf
- www/docs/libraries
    - www/docs/libraries/index.edf
    - www/docs/libraries/eon.edf

## Text file extensions

> Definition:
> A text file is a file format that does not soley depend on the EEEch format.

- All text files should be named with 3 letter lowercase extensions.
- All text file docs should be listed under categories named `text`
- A text format is considered "Builtin" if it is parsed by SandEEE itsself rather than an `.eep` program
- Docs should specify if a file format is builtin

### Example

```md
```

## Binary file extensions

> Definiton:
> A binary file is a file format that does not soley depend on the EEEch format.

- All binary files should be named with 3 letter lowercase extensions.
- All binary file docs should be listed under categories named `binaries`, to keep things consistent that means no shortening to "bins".
- A binary format is considered "Builtin" if it is parsed by SandEEE itsself rather than an `.eep` program
- Everything has 4 char magic, capitalization will be inconsistent. Docs should mention this first, followed by format specs.
- File extensions should be listed in the same line as what the file does
    - Format `File use (extensions)`
- Format should **never** use int names, it should always be a character width.
    - Reasoning: SandEEE was made in a world where strings are fast, so they are more used.
- All docs should be in .edf format
- Everything after the magic should be in a `Data` secion
- Formats are ordered lists, syntax
- Binary files should be given a proper name, ex. for eia can be called "EEE Image Array"
- Docs should specify if a file format is builtin

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