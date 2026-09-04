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
EventCorrection is a separate Actual relation stream. It may be physically absent
when empty, but that absence does not erase its persistence boundary.

The question is therefore:

> Which physical storage changes are only representation cleanup, and which
> changes merge write / failure / authority domains and therefore require a new
> publication model?

This observation does not change canonical household data.

## Current logical families

The current persistence model contains distinct physical evidence families such as:

```text
Actual Event / Effect evidence
Actual occurrence-date evidence
Actual human-recognition description evidence
Actual EventCorrection evidence (optional physical stream when non-empty)
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
corrections.loam              # optional / physically absent when empty
scheduled.loam
basis.loam
balance-view.tsv
```

Properties:

- EventMemory has a dedicated physical authority file;
- date / description evidence can be published before Event authority;
- EventCorrection retains its own relation write unit when present;
- Scheduled, QuantityBasis, and view configuration remain separate write domains.

### B. Unified Actual file

Representative shape:

```text
actual.loam
scheduled.loam
basis.loam
balance-view.tsv
```

where `actual.loam` contains typed Event, ActualValidity, EventDescription, and
EventCorrection records.

This can be a coherent future design, especially if the whole file is staged and
atomically replaced. But it is **not** a path-only cleanup:

- Event authority no longer has a dedicated physical write unit;
- Event + date + description + correction become one publication unit;
- the current auxiliary-first Event admission semantics and separate correction
  publication boundary must be replaced by and qualified against a new whole-Actual
  commit protocol.

The observation therefore does not reject unified Actual. It classifies it as a
semantic persistence redesign that needs its own pressure and qualification.

### C. Semantic Actual directory

The minimum representation-only specimen keeps existing filenames and sidecar
conventions unchanged while grouping the Actual persistence streams under one
parent directory:

```text
actual/
  memory.loam
  memory.loam.actual-validity
  memory.loam.descriptions
  corrections.loam            # optional / absent when empty
scheduled.loam
basis.loam
balance-view.tsv
```

This exact shape matters. Current production code derives the validity and
description paths from the EventMemory path. Therefore renaming those files to
`events.loam`, `validity.loam`, and `descriptions.loam` would add another
persistence-path decision and is not part of this representation-only candidate.

The EventCorrection path is supplied separately by practical consumers today, so
moving it under `actual/` requires path wiring to follow the bundle but does not
merge it with EventMemory or change its file format / write unit.

The Actual streams remain distinct write units, but their parent path exposes the
logical bundle. The candidate changes placement without changing which streams
share a physical write unit. Therefore the current write partition and authority
isolation can remain structurally unchanged.

### D. Whole-household monolith

Representative shape:

```text
household.loam
```

with Actual, Scheduled, QuantityBasis, and view configuration all sharing one
physical file.

This merges fact families that currently have independent write / failure domains.
It is not representation-only cleanup. That classification is not, by itself, a
rejection: for small household state, staging and atomically replacing one complete
snapshot might eliminate partial cross-file publication states. The tradeoff is a
larger write / corruption domain and a new whole-household authority protocol.

## Lean qualification

`Loam/Observations/Observation149.lean` models each fact family as a stream and
separates two physical coordinates:

```text
directory placement
file write unit
```

It establishes:

1. moving the Actual streams under `actual/` preserves the complete current write
   partition, including the optional EventCorrection stream;
2. that directory move preserves the dedicated Event authority file;
3. Actual remains physically separate from Scheduled, QuantityBasis, and view
   configuration;
4. a unified Actual file merges Event, ActualValidity, EventDescription, and
   EventCorrection into one write unit and therefore changes the current
   publication boundary;
5. a whole-household monolith additionally couples independent non-Actual fact
   families;
6. among the concrete alternatives, only the semantic-directory candidate is a
   representation-only change relative to the current storage partition.

## What this observation does not prove

The Lean model intentionally does not claim that separate Actual files are the
final best design.

A unified `actual.loam` may eventually be better if whole-Actual atomic publication
reduces operational complexity, improves portability, or makes corruption /
recovery behavior easier to reason about. That requires a separate observation
because the authority protocol changes.

A whole `household.loam` snapshot may deserve the same deeper observation if real
pressure shows that one atomic household generation is simpler and safer in
practice. Observation 149 only proves that such a move is semantic, not cosmetic.

Likewise, grouping files under `actual/` may prove aesthetically cleaner but not
worth migration churn. Path movement itself must earn value in real use.

Humanizing the sidecar filenames is also a separate question from grouping them.
The representation-only specimen intentionally avoids changing directory,
companion naming, and write partition all at once.

## Private canonical pressure

After the public Lean qualification passes, the private canonical `loam-data`
generation should be tested in scratch only, without changing its canonical tree.

For the same current data generation, construct four specimens:

1. current root sidecars, preserving physical absence of empty optional streams;
2. a unified-Actual observation envelope that losslessly contains the current
   Event, ActualValidity, EventDescription, and optional EventCorrection state and
   can be materialized back to the exact current stream bytes;
3. the semantic-directory specimen under `actual/`, again preserving optional
   stream absence;
4. a whole-household observation envelope containing the same Actual state plus
   Scheduled, QuantityBasis, and view state.

The two observation envelopes are deliberately not proposed production wire
formats. They exist only to measure the consequences of changing the physical
commit unit. Each must round-trip to the exact source bytes before any semantic
comparison is accepted.

Compare at least:

- production-loader reconstruction parity after exact materialization;
- readable-journal parity;
- Quantity balance parity;
- exact Event / Effect / ActualValidity / EventDescription / EventCorrection counts;
- total stored bytes and atomic-rewrite bytes per mutation;
- Git / human diff locality separately from filesystem bytes rewritten;
- old-or-new behavior under staged atomic replacement for single-file candidates;
- current auxiliary-first partial-publication behavior for multi-file candidates;
- blast radius of one malformed physical stream / container;
- number and scope of write units touched by native Actual append,
  ActualValidity correction, EventCorrection, Scheduled-only, and Basis-only
  operations that production LOAM actually supports.

If an operation is not a current production operation, report that fact instead of
inventing a fake household mutation merely to fill the matrix.

The scratch comparison must not publish or commit a topology migration.

## Decision boundary

At this observation's public-model layer:

```text
semantic directory with unchanged stream formats / write units
    = representation-only candidate

unified Actual file
    = potentially good, but requires a new Actual publication protocol

whole-household monolith
    = potentially good or bad, but requires a new household publication protocol
```

Therefore DD-006 readable-journal publication should remain paused until this
canonical topology question has received private real-data pressure.
