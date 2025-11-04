---
marp: true
theme: uncover
class: invert
style: |
    .columns {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 1;
    }
---

# In Defense of Metadocumentation
Preston Precourt (prestosilver)

---

# What is SandEEE?

<!--

- Programming game
- High emphasis on realism
- Project is already at an MVP

-->

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

-->


# This is Not for Everyone 

- SandEEE by nature has user facing documentation
- I am documenting this after I have a full working MVP
- In SandEEE, Bad Docs ⇒ Bad Game

---

# Didn't expect to get so much out of this
- Solid framework for what I need
- I know what SandEEE is now

---

<!--

- I started binary formats just because I knew I would be able to do a lot.

-->

# Where to Start

- Just start, anywhere works

![](docs.png)

---

[The docs in question](../plans/meta.md)
# This is My First Marp Presentation, btw