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

<!-- markdownlint-enable MD036 -->
