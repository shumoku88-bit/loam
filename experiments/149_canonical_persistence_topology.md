# Observation 149 — Which canonical persistence topology is actually earned?

## Question

LOAM's current canonical data is physically split across several streams.

The important distinction is not simply "one file versus many files". The current
Actual entrance deliberately publishes supporting evidence before EventMemory and
uses EventMemory as the authority commit point:

```text
ActualValidity
    -> EventDescription when present
    -> EventMemory authority commit
```

If publication stops before the Event commit, already-published supporting
evidence remains inert because no authoritative Event exists with that identity.

The question is therefore:

> Which physical storage changes are only representation cleanup, and which
> changes merge write / failure / authority domains and therefore require a new
> publication model?

This observation does not change canonical household data.

## Current logical families

The current data directory contains distinct physical evidence families such as:

```text
Actual Event / Effect evidence
Actual occurrence-date evidence
Actual human-recognition description evidence
Scheduled evidence
QuantityBasis evidence
view configuration
```

These are not assumed to deserve one file each forever. They are only the current
qualified write partition.

## Compared topologies

### A. Current sidecars

Representative shape:

```text
memory.loam
memory.loam.actual-validity
memory.loam.descriptions
scheduled.loam
basis.loam
balance-view.tsv
```

Properties:

- EventMemory has a dedicated physical authority file;
- date / description evidence can be published before Event authority;
- Scheduled, QuantityBasis, and view configuration remain separate write domains.

### B. Unified Actual file

Representative shape:

```text
actual.loam
scheduled.loam
basis.loam
balance-view.tsv
```

where `actual.loam` contains typed Event, ActualValidity, and EventDescription
records.

This can be a coherent future design, especially if the whole file is staged and
atomically replaced. But it is **not** a path-only cleanup:

- Event authority no longer has a dedicated physical write unit;
- Event + date + description become one publication unit;
- the current auxiliary-first crash semantics must be replaced by and qualified
  against a new whole-Actual commit protocol.

The observation therefore does not reject unified Actual. It classifies it as a
semantic persistence redesign that needs its own pressure and qualification.

### C. Semantic Actual directory

The minimum representation-only specimen keeps the existing filenames and sidecar
convention unchanged and moves the complete Actual bundle under one directory:

```text
actual/
  memory.loam
  memory.loam.actual-validity
  memory.loam.descriptions
scheduled.loam
basis.loam
balance-view.tsv
```

This exact shape matters. Current production code derives the validity and
description paths from the EventMemory path. Therefore renaming the files to
`events.loam`, `validity.loam`, and `descriptions.loam` would require another
persistence-path change and is not part of the representation-only candidate.

The three streams remain distinct write units, but their parent path exposes the
logical Actual bundle. Existing production readers can point at
`actual/memory.loam` and continue deriving the two companion sidecars without a
new file-format or companion-path rule.

This candidate changes placement without changing which streams share a write
unit. Therefore the existing publication protocol can remain structurally
unchanged.

### D. Whole-household monolith

Representative shape:

```text
household.loam
```

with Actual, Scheduled, QuantityBasis, and view configuration all sharing one
physical file.

This merges fact families that currently have independent write / failure domains.
It is not storage cleanup and is not qualified by this observation.

## Lean qualification

`Loam/Observations/Observation149.lean` models each fact family as a stream and
separates two physical coordinates:

```text
directory placement
file write unit
```

It establishes:

1. moving the three Actual streams under `actual/` preserves the complete current
   write partition;
2. that directory move preserves the dedicated Event authority file;
3. Actual remains physically separate from Scheduled, QuantityBasis, and view
   configuration;
4. a unified Actual file merges Event, ActualValidity, and EventDescription into
   one write unit and therefore changes the current publication boundary;
5. a whole-household monolith additionally couples independent non-Actual fact
   families;
6. among the concrete alternatives, only the semantic-directory candidate is a
   representation-only change relative to the current storage partition.

## What this observation does not prove

The Lean model intentionally does not claim that three Actual files are the final
best design.

A unified `actual.loam` may eventually be better if whole-Actual atomic publication
reduces operational complexity, improves portability, or makes corruption /
recovery behavior easier to reason about. That requires a separate observation
because the authority protocol changes.

Likewise, grouping files under `actual/` may prove aesthetically cleaner but not
worth migration churn. Path movement itself must earn value in real use.

Humanizing the sidecar filenames is also a separate question from grouping them.
The representation-only specimen intentionally avoids changing both directory and
companion-path convention at once.

## Private canonical pressure

After the public Lean qualification passes, the private canonical `loam-data`
generation should be tested in scratch only, without changing its canonical tree.

For the same current data generation, construct:

1. current root sidecars;
2. a unified-Actual specimen that can be losslessly materialized back to the
   current three stream bytes for production-reader parity checks;
3. `actual/memory.loam` plus its two unchanged companion sidecars.

Compare at least:

- production-loader reconstruction parity;
- readable-journal parity;
- Quantity balance parity;
- exact Event / Effect / ActualValidity / EventDescription counts;
- byte size and changed-byte locality for one representative native Actual append;
- crash / partial-publication states;
- number and scope of files rewritten by date-only, description-only, correction,
  Scheduled-only, and Basis-only changes.

The scratch comparison must not publish or commit a topology migration.

## Decision boundary

At this observation's public-model layer:

```text
semantic directory with unchanged sidecar names
    = representation-only candidate

unified Actual file
    = potentially good, but requires a new publication protocol

whole-household monolith
    = couples currently independent fact families
```

Therefore DD-006 readable-journal publication should remain paused until this
canonical topology question has received private real-data pressure.
