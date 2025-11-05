---
marp: true
# class: invert
style: |
    .columns {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 1;
    }
---

<style>
@font-face {
    font-family: SandEEESans;
    font-size: 32px;
    src: url(https://sandeee.prestosilver.info/font.ttf);
}

* {
    font-family: SandEEESans;
}
</style>

<!-- backgroundImage: url(frame.png) -->
<!-- backgroundSize: cover -->
<!-- backgroundPosition: center -->
<!-- backgroundAttachment: fixed -->

# In Defense of Metadocumentation
Preston Precourt (prestosilver)

---

# What is SandEEE?

<!--

- Passion project, experimental
- Feel so coherent it has to be real
- Project is already at an MVP

-->

![bg right vertical 80%](wallpaper.png)

---

# Why?

<!--

- Many inconsistencies
- Worrying about missing something

-->

<div class="columns">
<div>

Documentation for eon
```edf
#Style @/style.eds
:logo: [@/logo.eia]

-- Eon --

    ...

:center: --- EEE Sees all ---
```

</div>
<div>

Documentation for asm
```edf
#Style @../../style.eds
:logo: [@/logo.eia]

-- asm --

    ...

:center: -- EEE Sees all --
```

</div>
</div>

---

<!--

- If you're not documenting your game for your userbase, I would not suggest this
- This takes a long time, and if you dont follow it its not worth it.

-->


# This is Not for Everyone 

- SandEEE by nature has user facing documentation
- I am documenting this after I have a full working MVP
- In SandEEE, Bad Docs ⇒ Bad Game

---

<!--

- I was pleasantly suprised and wanted to pitch this to people who may not know its a thing

-->

# I Didn't expect to get so much out of this
- Solid framework for what I need
- I know what SandEEE is now

---

<!--

- I started binary formats just because I knew I would be able to do a lot.
- Really though i would suggest doing whatever you can, but take your time and really think

-->

# Where to Start

- Just start, anywhere works

![bg left h:720](docs.png)

---

## Any questions
# This is My First Marp Presentation, btw

[The docs in question](https://gist.github.com/prestosilver/a8b96a828b9d794878bf9f73bf88c5cb0)

![bg right 60%](qr.png)