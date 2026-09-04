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

The public qualification was followed by scratch-only pressure against the then
current private canonical generation. The private repository remained unchanged;
no branch, commit, push, PR, or historical-admission rewrite was performed.

The tested generation contained:

```text
564 Events
1171 Effects
564 BASE ActualValidity entries
0 ActualValidity revisions
0 ActualValidity corrections
564 EventDescriptions
0 EventCorrections
```

Its active root persistence occupied about 75 KiB before any observation-envelope
overhead. EventCorrection remained physically absent because the stream was empty.

Four scratch specimens were constructed from the same generation:

```text
A current sidecars
B unified Actual observation envelope
C semantic Actual directory
D whole-household observation envelope
```

The B and D envelopes were deliberately observation-only containers, not proposed
production formats. Both losslessly round-tripped the source streams, including
physical absence of the empty EventCorrection stream.

### Semantic parity

A, B after exact unpack, C, and D after exact unpack produced byte-identical
production answers for the checked summary, review, Daily Quantity balances, and
Readable Journal. Every materialized stream also matched the baseline bytes.

So the topology question is not about whether the same household facts can be
represented. All four specimens can carry the current generation exactly.

### Physical write pressure

Representative measured sizes were:

```text
current active persistence       about 77.2 KiB
unified Actual envelope          about 76.4 KiB for the Actual write unit
whole-household envelope         about 77.9 KiB for the household write unit
```

The important result was not raw I/O cost. At this household scale even the whole
state is small. The important distinction was mutation and failure scope.

Under current sidecars, Scheduled-only and Basis-only changes rewrite only their
small dedicated streams. Under a whole-household snapshot they would rewrite the
entire household generation even though the byte cost itself is modest.

### Publication pressure

The existing A topology and the C directory specimen retain the qualified
auxiliary-first Actual publication shape:

```text
ActualValidity
-> optional EventDescription
-> EventMemory authority commit
```

Scratch crash-phase checks confirmed that the new Event stays unreadable before
the EventMemory authority commit. Earlier supporting evidence can remain inert,
but no false-readable mixed Event is exposed.

The unified Actual observation envelope showed a different attractive property:

```text
complete new Actual generation staged beside old generation
-> atomic rename
```

Before rename, readers see only the old complete generation. After rename, they
see only the new complete generation. The observation therefore found concrete
pressure for replacing the multi-step Actual publication protocol with one
whole-Actual atomic generation.

That is not yet a production qualification because it changes the authority
boundary. It is evidence for the next observation.

### Corruption blast radius

Current sidecars showed useful physical fault isolation:

- malformed ActualValidity blocked date-dependent review / journal paths without
  blocking recorded quantity answers;
- malformed EventDescription likewise left quantity answers available;
- malformed Scheduled data did not disable Actual queries;
- malformed QuantityBasis did not disable raw recorded memory / journal output.

A corrupted unified Actual envelope blocked the whole Actual family while leaving
separate Scheduled and Basis state outside that container.

A corrupted whole-household envelope blocked every tested household surface.

This makes the whole-household candidate's larger failure domain concrete even
though its raw write cost is cheap.

### Path-coupling pressure

The lower production binaries can accept explicit persistence paths and can derive
ActualValidity / EventDescription companions from an `actual/memory.loam` path.
However, higher-level practical wrappers and the private request-application
workflow still contain root-level path assumptions.

So C is not free migration: it preserves write semantics but requires path rewiring
without providing a measured semantic or operational gain.

## Private result

The private pressure narrows the candidates as follows:

```text
A current sidecars
    KEEP CURRENT as the qualified operational baseline

C semantic directory
    NOT EARNED
    same write / failure semantics as A, plus migration and wrapper rewiring

D whole-household snapshot
    NOT EARNED
    cheap I/O, but unnecessarily couples independent fact families and blast radius

B unified Actual
    DESERVES NEXT OBSERVATION
    preserves separation from Scheduled / Basis / view while eliminating
    multi-step Actual publication in the scratch atomic-generation specimen
```

Therefore Observation 149 does **not** authorize a persistence migration.
Production remains on the current sidecar topology.

It does establish a concrete next question:

> Can Event, ActualValidity, EventDescription, and EventCorrection become one
> atomic Actual generation while preserving their semantic distinctions,
> correction topology, fail-closed behavior, and all existing projections?

That question requires a new observation because the physical authority commit
moves from EventMemory to the complete Actual generation.

## Decision boundary

Observation 149 closes with:

```text
KEEP CURRENT for production today

SEMANTIC DIRECTORY IS NOT EARNED
WHOLE HOUSEHOLD SNAPSHOT IS NOT EARNED
UNIFIED ACTUAL DESERVES NEXT OBSERVATION
```

DD-006 readable-journal publication remains paused until the Unified Actual
question is qualified or deliberately declined.
