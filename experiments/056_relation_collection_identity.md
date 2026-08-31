# Observation 056: relation collection identity

## Question

Once Correction and Resolution facts are collected outside `EventMemory`, is referential closure alone enough to make those collections semantically usable?

In particular:

1. Can two admitted relations carry the same relation identity while disagreeing about their payload?
2. If duplicate identity is allowed, can physical list/storage order become an accidental tie-breaker?
3. Is per-kind relation identity uniqueness enough to make identity lookup single-valued without giving representation order semantic meaning?

This observation does not choose a persistence format or introduce a unified `FactId`.

## Model

The model keeps the practical distinction already present in Core:

- `CorrectionId` identifies one Correction fact.
- `ResolutionId` identifies one Resolution fact.
- Correction explicitly references target and replacement Events.
- Resolution explicitly references parent and replacement Events.
- referential admission keeps only relations whose explicit Event references are present.

A separate `CorrectionLayout` gives the same Correction membership two possible physical slot orders. Slot order exists only to test whether duplicate identity could tempt a consumer to choose a winner by position.

## Commands

Expected Alloy results:

- `admittedDuplicateCorrectionCanDisagree`: SAT
- `admittedDuplicateResolutionCanDisagree`: SAT
- `sameCorrectionFactsCanSwapFirstDuplicate`: SAT
- `sameUniqueCorrectionFactsCanReorder`: SAT
- `ReferentialAdmissionImpliesUniqueCorrectionIds`: SAT
- `ReferentialAdmissionImpliesUniqueResolutionIds`: SAT
- `UniqueCorrectionIdsMakeLookupSingle`: UNSAT
- `UniqueResolutionIdsMakeLookupSingle`: UNSAT
- `CorrectionIdentityLookupIgnoresLayoutOrder`: UNSAT

## Interpretation

Referential closure and identity uniqueness answer different questions.

A Correction or Resolution may reference only Events that are present and still collide in identity with another admitted relation. Alloy can produce two Corrections with one `CorrectionId` but different target/replacement payloads, and likewise two Resolutions with one `ResolutionId` but different parent/replacement payloads.

Therefore Observation 055's fail-closed admission law is necessary but not sufficient for a practical relation collection.

If duplicate relation identity remains in the collection, a consumer could try to recover one relation by choosing whichever duplicate appears first in physical storage. Alloy finds a witness where the same duplicate facts are serialized in two orders and the first relation changes. That would reintroduce the storage-order semantics rejected by Observation 053.

Per-kind identity uniqueness removes this ambiguity. Under unique Correction identity, lookup by `CorrectionId` is single-valued. Under unique Resolution identity, lookup by `ResolutionId` is single-valued. The same uniquely identified Correction facts can still be represented in different physical orders, while identity lookup remains unchanged.

So the useful law is not "relation order determines current meaning" but:

> Within each practical relation collection, one relation identity names at most one admitted relation fact.

This mirrors `EventMemory` without requiring Event, Correction, and Resolution to share one global identity namespace.

## Practical consequence

A future practical relation-memory structure can use deterministic lists for round-trip representation while rejecting repeated `EventCorrectionId` and repeated `EventResolutionId` within their respective collections.

That structure should preserve:

- per-kind identity uniqueness;
- representation-order independence of identity lookup;
- fail-closed Event-reference admission as a separate layer;
- no chronology, priority, or authority from list position.

This observation does **not** yet require:

- Correction / Resolution persistence;
- one combined relation memory;
- one global `FactId`;
- cross-kind token uniqueness;
- time, authority, evidence, or origin semantics.
