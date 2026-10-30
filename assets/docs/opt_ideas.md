# general SandEEE optimization ideas

> "We should forget about small efficiencies, say about 97% of the time: premature optimization is the root of all evil." - Donald Knuth

These are all time consuming and non trivial but offer benefit. I am tracking them for when an **Observable**, and **Trackable** slowdown is found i.e. some part of _My_ vision requires the impacted part of SandEEE to be faster.

- Proper PBO usage
- Dirty buffer
- Take advantage of rope better in syscalls and streams
- File listeners via Event members
- Better streams that dont preallocate
- Preallocate fixed buffers like vm windows, iter on create not use
- Per frame temp allocator
