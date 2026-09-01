# Application 004: writer ownership scope

## Question

Application 003 showed that a writer may be semantically authorized and still lose an already-completed update if it later publishes a stale whole-memory replacement.

The next question is narrower and physical:

> Does the current `Loam.Persistence.saveEventMemory?` boundary actually exhibit the stale whole-memory loss that TLA+ modeled, and what is the smallest ownership scope that prevents it?

This experiment does not yet choose a production locking primitive.

## Current persistence shape

`saveEventMemory?` encodes a complete `EventMemory`, writes it to the sibling `.loam-stage` path, then renames that staging file over the target.

That is useful atomic replacement for one publication, but it does not serialize the larger writer operation:

```text
observe
  -> prepare
  -> admit
  -> publish
```

The physical risk therefore remains a read-modify-publish race rather than a partially-written-target problem.

## Executable witness

The Lean probe imports the production `Loam.Persistence` implementation.

It creates two distinct Events, A and B, and has both logical writers observe the same empty persisted EventMemory before either publishes:

```text
A observes {}
B observes {}
A prepares {A}
B prepares {B}
A publishes {A}
B publishes stale {B}
```

The expected final state is the production lost-update witness:

```text
A absent
B present
```

The workflow requires the probe to print:

```text
unsafe_stale_replace_loses_completed_update=true
```

This is intentionally deterministic. The goal is to qualify the persistence shape, not to depend on scheduler timing to rediscover the same interleaving.

## Ownership contrast

The same probe then repeats the two updates while keeping each complete writer operation inside one serial ownership scope:

```text
A: observe -> prepare -> admit -> publish
B: observe -> prepare -> admit -> publish
```

B therefore observes the state produced by A and publishes `{A, B}`.

The workflow requires:

```text
serial_ownership_scope_preserves_both_updates=true
```

This contrast demonstrates the required scope, not the final mechanism.

## Why this does not choose `flock`, a lock file, or CAS

A process-local mutex would not protect separate LOAM processes. `flock` would make a platform/API choice. Atomic lock-file or lock-directory creation introduces ownership, stale-owner, cleanup, and crash-recovery questions. Revision-aware CAS still requires a real conditional publication primitive; ordinary check-then-rename recreates the race Application 003 already found.

So Application 004 stops one step earlier:

```text
required property:
  exclusive writer ownership spans observation through publication

physical mechanism:
  not yet chosen
```

The next experiment can compare concrete cross-process ownership mechanisms against this scope without changing Core vocabulary.

## Correction relationship

This experiment uses only `EventMemory` so it can isolate the concurrent-writer problem.

It does not replace the earlier split-publication law for corrections:

```text
writer: Correction -> Event
reader: Event -> Correction
```

If a future production ownership primitive protects Correction publication, the ownership scope must encompass the complete relation-first writer protocol rather than locking the two files independently.

## Vocabulary boundary

`spend` remains a human-facing CLI entrance. Nothing in this experiment treats `spend` as the writer abstraction.

The retained writer vocabulary is deliberately neutral:

```text
observe
prepare
admit
publish
ownership
```

## Scope

- one deterministic production-Persistence lost-update witness;
- one serial-ownership contrast;
- no Core changes;
- no Persistence changes;
- no Application production changes;
- no CLI changes;
- no wire-format changes;
- no lock implementation;
- no CAS implementation;
- no crash-recovery claim;
- no new Observation number.
