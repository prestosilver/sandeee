# Pros and Cons sheet

<!-- markdownlint-disable MD036 -->

In order to make some major decisions Ill use this document to track pros and cons.

## Metabyte files

- Pros
  - Makes more sense in universe
  - Streams can possibly be optimized better
- Cons
  - Implementation time
  - Learning curve
  - Slower
  - Need to restart disk rewrite

**DENIED**

## Remove pseudofiles in favor of a IoRead/IoWrite syscall

- Pros
  - Makes more sense that EEE would use this paradigm bc Strings
  - Cleans up new disk impl
  - Cleans up file read errors
  - Not a terrible switch
  - More specific erorrs
- Cons
  - ~~Seperation of systems makes it harder to teach~~
    - Not an issue as teaching low level systems isnt essential to SandEEE as a concept
  - ~~Full rewrite of syscall system~~
    - Would likely be rewritten anyways with new disk system
  - ~~Swap out in current docs~~
    - Needs to be rewritten anyways
  - Will need to be speced up (Problaby can borrow from pseudofile docs)

**APPROVED**

<!-- markdownlint-enable MD036 -->
