|path|Desc|
|----|---:|
|[content/](../../content/)|All content that can appear in game |
|&emsp;[asm/](../../content/asm)|All code written in EEE Assembly|
|&emsp;&emsp;[exec/](../../content/asm/exec/)|Executables written in EEE Assembly|
|&emsp;&emsp;&emsp;[aplay.asm](../../content/asm/exec/aplay.asm)|The terminal audio player|
|&emsp;&emsp;&emsp;[dump.asm](../../content/asm/exec/dump.asm)|A raw file dumper utility|
|&emsp;&emsp;&emsp;[echo.asm](../../content/asm/exec/echo.asm)|A text printer utility|
|&emsp;&emsp;&emsp;[libdump.asm](../../content/asm/exec/libdump.asm)|A .ell file dumper|
|&emsp;&emsp;&emsp;[time.asm](../../content/asm/exec/time.asm)|Times how long a program takes to run|
|&emsp;&emsp;[libs/](../../content/asm/libs/)|Libraries written in EEE Assembly|
|&emsp;&emsp;&emsp;[incl/](../../content/asm/libs/incl/)|Includable Libraries written in EEE Assembly|
|&emsp;&emsp;&emsp;&emsp;[libload.asm](../../content/asm/libs/incl/libload.asm)|Used by programs to load the .ell file loader|
|&emsp;&emsp;&emsp;[array.asm](../../content/asm/libs/array.asm)|A simple array library.|
|&emsp;&emsp;&emsp;[libload.asm](../../content/asm/libs/libload.asm)|The .ell file loader|
|&emsp;&emsp;&emsp;[sound.asm](../../content/asm/libs/sound.asm)|Basic audio utilities|
|&emsp;&emsp;&emsp;[string.asm](../../content/asm/libs/string.asm)|Basic string utilities|
|&emsp;&emsp;&emsp;[texture.asm](../../content/asm/libs/texture.asm)|Basic texture utilities|
|&emsp;&emsp;&emsp;[window.asm](../../content/asm/libs/window.asm)|Basic window utilities|
|&emsp;&emsp;[tests/](../../content/asm/tests/)|Tests written in EEE Assembly|
|&emsp;[audio/](../../content/audio)|All audio files|
|&emsp;&emsp;[bg.wav](../../content/audio/bg.wav)|Some background noise<br/> ment to sound like a pc fan|
|&emsp;&emsp;[bios-blip.wav](../../content/audio/bios-blip.wav)|Played when a option is hovered in BootEEE|
|&emsp;&emsp;[bios-select.wav](../../content/audio/bios-select.wav)|Played when a option is selected in BootEEE|
|&emsp;&emsp;[fart.wav](../../content/audio/fart.wav)|A sound used for testing short multi second sfx|
|&emsp;&emsp;[login.wav](../../content/audio/login.wav)|Played when the user logs in|
|&emsp;&emsp;[logout.wav](../../content/audio/logout.wav)|Played when the user logs out|
|&emsp;&emsp;[message.wav](../../content/audio/message.wav)|Played when the user recieves an email[^1]|
|&emsp;[data/](../../content/data)|Raw text files that contain some sort of data|
|&emsp;&emsp;[app.rc](../../content/data/app.rc)|Windows app.rc|
|&emsp;&emsp;[os_versions.csv](../../content/data/os_versions.csv)|A conversion table from the old semver versions to EEEversions|
|&emsp;[elns/](../../content/elns)|Eln files for epk downloads<br/>seperate because this is raw text|
|&emsp;&emsp;[Connectris.eln](../../content/elns/Connectris.eln)|The eln for the connectris app|
|&emsp;&emsp;[Paint.eln](../../content/elns/Paint.eln)|The eln for the paint app|
|&emsp;&emsp;[Pong.eln](../../content/elns/Pong.eln)|The eln for the pong app|
|&emsp;[eon/](../../content/eon)|All EEE Eon programs|
|&emsp;&emsp;[exec/](../../content/eon/exec)|Executables written in EEE Eon|
|&emsp;&emsp;&emsp;[alib.eon](../../content/eon/exec/alib.eon)|An assembler for .ell files|
|&emsp;&emsp;&emsp;[asm.eon](../../content/eon/exec/asm.eon)|An assembler for .eep files|
|&emsp;&emsp;&emsp;[connectris.eon](../../content/eon/exec/connectris.eon)|The connectris app|
|&emsp;&emsp;&emsp;[elib.eon](../../content/eon/exec/elib.eon)|The Eon .ell compiler|
|&emsp;&emsp;&emsp;[eon.eon](../../content/eon/exec/eon.eon)|The Eon .eep compiler|
|&emsp;&emsp;&emsp;[epkman.eon](../../content/eon/exec/epkman.eon)|The .epk file installer|
|&emsp;&emsp;&emsp;[fib.eon](../../content/eon/exec/fib.eon)|Fibonacci sequence|
|&emsp;&emsp;&emsp;[paint.eon](../../content/eon/exec/paint.eon)|The paint app|
|&emsp;&emsp;&emsp;[pix.eon](../../content/eon/exec/pix.eon)|The picture viewer app|
|&emsp;&emsp;&emsp;[player.eon](../../content/eon/exec/player.eon)|A simple gui audio player|
|&emsp;&emsp;&emsp;[pong.eon](../../content/eon/exec/pong.eon)|The pong app|
|&emsp;&emsp;&emsp;[stat.eon](../../content/eon/exec/stat.eon)|Prints some file stats|
|&emsp;&emsp;&emsp;[steamtool.eon](../../content/eon/exec/steamtool.eon)|Steam asset uploader|
|&emsp;&emsp;[libs/](../../content/eon/libs)|Libraries written in EEE Eon|
|&emsp;&emsp;&emsp;[incl/](../../content/eon/libs/incl/)|Includable Libraries written in EEE Eon|
|&emsp;&emsp;&emsp;&emsp;[libload.eon](../../content/eon/libs/incl/libload.eon)|Used by programs to load the .ell file loader|
|&emsp;&emsp;&emsp;&emsp;[sys.eon](../../content/eon/libs/incl/sys.eon)|A wrapper for syscalls|
|&emsp;[images/](../../content/images)|Image assets in normal formats|
|&emsp;&emsp;[ase/](../../content/images/ase)|The asperite project files for sandeee images|
|&emsp;&emsp;[icon.ico](../../content/images/icon.ico)|The sandeee app icon for windows[^2]|
|&emsp;&emsp;*.png|Png image assets in sandeee[^2]|
|&emsp;[mail/](../../content/mail)|Email rawtext[^1]|
|&emsp;[overlays/](../../content/overlays/)|Disk image overlays for special builds|

[^1]: Asset will be scrapped, however is cannon hence is being kept
[^2]: Asset will be removed per duplication