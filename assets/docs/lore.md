# SandEEE Lore & Implementation Plan  

## Timeline

| Date      | Event           | Notes
|-----------|-----------------|-|
| 03/03/1993  | EEE is founded. | - Their goal was to make programming a universal right, something as common as reading/writing. <br/> - They start with simple programs for normal machines, but in the background are developing a "string efficient cpu". <br/>
| 04/07/2000  | Desktop release | EEE finishes their machine, and decide to make it public, it gains wide support.
| 03/03/2003  | Operating system | EEE announces work on DunEEE A desktop operating system for their machines.
| 05/03/2004  | Epsilon hired | Epsilon is hired by EEE
| 08/01/2004 | Epsilon leaks | Epsilon "leaks" a modified build of SandEEE to make himself look like a whistle blower. EEE is framed for greed, they wanted to accept donations but Epsilon made it look mandatory.
| 08/02/2004 | EEE hated | Overnight articles suspiciously report immediately on EEE's unverified "Wrongdoings", the public hates them it balloons and they can really get their own thoughts out.
| 08/06/2005 | EEE dies | After not even a week, public outcry is so high EEE is forced to file bankruptcy.
| 08/06/2010 | EEE is forgotten | By now no one remembers much of EEE, much like other companies left to die. Only mentioned in the niche books you'll never read, and the rare resurface of `recovery.eee`.

## Key concepts

- SandEEE is an opinionated recreation of DunEEE made by Epsilon.
  - SandEEE is advertised as a leak with corporate docs, however these docs are fake/modified/untrustworthy.
- Sys 255 is not part of DunEEE, instead added by Epsilon to let him import DunEEE disks, it uses the actually secure DunEEE encryption algorithm (Problaby RSA)
  - Epsilon decrypted and reencrypted using SandEEE's decryption (rc4).
- SandEEE started as a unfinished release build, it should be similar feeling to windows Longhorn/Whistler builds.
  - I have to be deliberate about what features I omit, SandEEE should feel incomplete yes, but it should be a logical incomplete.
    - Places the developers spend more time should be further ahead
    - while lesser used programs still have obvious WIP.
  - It was highly edited by epsilon.
    - Epsilon also likely finished some unfinished features to make EEE look bad, for example maybe a WIP payment processing in EEEmail.

## Implementation plans, order, and progress

### Initial release

- Full sandbox
- Subtle inconsistencies in design
  - Should feel like it was made by a team but repurposed by individual
  - Email will be encripted by rc4, however game will have multiple mentions of rsa.

### Lore drop 1

- Base story, should feel too neat will not be too heavy on contradictions, mostly focusing on epsilon as an imfamous whistle blower, bringing down the all greedy EEE.
- eventually leads to joe moes resignition letter, leaking his password to the alt disk. This was missed by epsilon while making SandEEE, and throws a huge gap into SandEEE's neat lore.

### Lore drop 2

- New recovery disk for DunEEE
  - Game will have a way to decript update images with a key.
    - Encrypted with rsa.
  - Its publically considered a "fake" image, an attempt to cover up the whistle blow. but is more real than SandEEE, and was made by joe moe.
    - Important to know that this is still opionated, joe took out stuff remotely incriminating.
- Epsilon starts to feel off, hes an ass in this disk.
- The disk is so focused on Epsilon it feels fake, theres no way a junior was the talk of the company.
  - In reality, he was infact on everyones head everyone thought he was a prodigy.
  - He is super manipulative, and is always going behind peoples back.
- Introduces Unnamed, but dosent implicate them as negative. Internal private emails chatting about the company.

### Lore drop 3

- Final disk image, also encrypted.
  - This will be "epsilons personal disk", containing his diary of his job.
- The reveal, epsilon was a spy dropped in by unnamed.
- Have a draft for the entire plot accessible by now, "Wait this was all planned."
