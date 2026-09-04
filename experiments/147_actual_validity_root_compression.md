# Observation 147 — Can current ActualValidity provenance compress to an Event-rooted history?

## Question

Observation 146 separated structural identity from historical-admission spelling and found one strong compression candidate:

```text
current V1
FactId -> Event -> initial date

candidate
Event -> initial date
  -> identified revision only when correction occurs
```

This observation asks the production-shaped follow-up:

> Can an already-admitted `ActualValidityHistory` be converted to that rooted form without using storage order, without changing the current occurrence date, and without turning currently-invalid history into readable history?

No production type, persistence format, CLI, or canonical data changes in this PR.

## Current production boundary

The present system retains every occurrence date as an identified `ActualValidityFact`, then relates fact identity to fact identity for corrections. The Application frontier rejects:

- duplicate correction targets;
- shared replacements;
- dangling references;
- cross-Event replacement;
- cycles;
- more than one current date for an Event.

Practical writers also allocate one fresh `ActualValidityFactId` for every newly recorded Event, even before any date correction exists.

A repository-wide usage audit found `ActualValidityFactId` confined to the ActualValidity history/frontier and practical writers that allocate or target those facts. No separate household evidence family currently targets an ActualValidity fact identity. EventDescription, EventCorrection, Scheduled relations, quantity evidence, and readable journal projection join through `EventId`, not `ActualValidityFactId`.

That makes the first fact identity a plausible compression target, but only if the existing correction semantics survive exactly.

## Candidate conversion

For an already-admitted V1 history:

1. a fact that is **not** the replacement endpoint of any validity correction is a path source;
2. that source fact becomes the Event-rooted base and loses its separate FactId;
3. every replacement fact remains an identified revision;
4. a correction whose target was the source fact now targets `root(EventId)`;
5. corrections between later facts target revision identity as before;
6. existing `ActualValidityCorrectionId` is retained here. This observation does not ask whether correction identity is removable.

So one Event changes from:

```text
f0(A) -> f1(B) -> f2(A)
```

to:

```text
Event(A) -> f1(B) -> f2(A)
```

The later return to `A` stays distinguishable because `f2` remains an identified revision.

## Admission boundary

The compressor is deliberately downstream of the current production admission:

```text
V1 raw history
  -> current `actualValidityFrontierAdmissible`
  -> only then root compression
```

It therefore must not repair, choose a winner for, or otherwise reinterpret sibling corrections, dangling endpoints, cross-Event replacement, or cycles.

## Lean qualification

`Loam/Observations/Observation147.lean` checks the candidate directly against the existing production `ActualValidityFrontier` using synthetic data only.

The specimens cover:

- uncorrected Event: initial FactId disappears and current date is unchanged;
- one correction: only the replacement retains revision identity;
- `A -> B -> A`: current date and both later revision identities survive;
- reordered fact/correction storage: the same root fact and current answer are selected;
- two independent Events: both current answers survive;
- sibling correction conflict: refused before compression;
- dangling replacement: refused before compression;
- cross-Event replacement: refused before compression;
- cycle: refused before compression.

The file also models the physical rewrite boundary. Existing ActualValidity persistence already writes a complete sibling stage file and performs one rename. A future V1-to-V2 rewrite of this **single canonical stream** can therefore expose either the complete old image or complete new image at the canonical path, not a mixed row generation. This does not earn another multi-file transaction layer.

## What a positive result would earn

If the exact-head Lean qualification succeeds, the next production slice may be kept narrow:

1. introduce a rooted ActualValidity persistence shape (V2);
2. add an explicit V1 -> V2 converter that first requires current V1 admission;
3. make new practical Events retain `EventId -> initial date` without allocating a date FactId;
4. allocate revision identity only when an Actual date is corrected;
5. preserve relation-defined correction authority and fail-closed conflict handling;
6. convert canonical data only after a dry-run proves current-date parity and exact reference closure;
7. retire V1 compatibility after the canonical conversion rather than preserving migration machinery forever.

A positive result would **not** earn re-keying EventId/EffectKey, removal of revision identity, removal of correction identity, mutation-in-place of historical dates, or last-write-wins semantics.
