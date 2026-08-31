# Observation 054: canonical fact topology

## Question

Should LOAM eventually treat Events, Corrections, and Resolutions as one canonical history, or persist them as separate fact streams?

The question has two distinct parts:

1. Does splitting the fact kinds lose semantic information needed for correction interpretation?
2. Does putting every fact into one serialized history accidentally introduce a global cross-kind order that the domain has not earned?

This observation compares those questions without choosing a file format, database, transaction protocol, or production source-of-truth schema.

## Model

The model gives every remembered item one explicit fact kind:

- `Event`
- `Correction`, with explicit `target` and `replacement` Event references
- `Resolution`, with explicit `parents` and `replacement` Event references

Two representations are compared.

### Unified representation

`UnifiedImage.members` is one set containing all fact kinds.

`UnifiedImage.placed` additionally models one possible physical serialization order. As in Observation 053, placement order is representation only unless some later law explicitly promotes it into meaning.

### Split representation

`SplitImage` retains three typed memberships:

- `events`
- `corrections`
- `resolutions`

It has no global order relating the three streams.

The explicit identity links inside Correction and Resolution are unchanged by the split.

## Commands

Expected Alloy results:

- `equivalentClosedRepresentations`: SAT
- `TypedPartitionEquivalent`: UNSAT
- `ClosureEquivalent`: UNSAT
- `CorrectionCandidatesEquivalent`: UNSAT
- `sameFactsDifferentGlobalOrder`: SAT
- `sameFactsCanChangeFirstKind`: SAT
- `SplitFactsDetermineGlobalOrder`: SAT

## Interpretation

For the questions modeled here, one unordered tagged fact set and three typed fact sets carry the same semantic information.

If the representations agree on fact membership:

- partitioning the unified set by fact kind recovers the split memberships exactly;
- referential closure is preserved;
- a correction candidate query returns the same Events.

So splitting Events, Corrections, and Resolutions does **not** inherently lose correction meaning. The explicit identity relations carry that meaning, not co-location in one container.

The difference appears when a "single canonical history" is also given one global serialization order. Alloy finds witnesses where the same facts have different unified orders, including witnesses where the first serialized fact changes kind. The split representation cannot recover that global order.

That loss is desirable **if global cross-kind order is not semantic**. Observation 053 already established that physical storage order must not silently become chronology, priority, or authority.

Therefore "one canonical history" and "one ordered log" should not be treated as synonyms.

## Practical consequence

This observation does not yet choose a production source of truth.

A useful distinction is now available:

- **logical canonical basis**: the admitted facts and their explicit identity relations;
- **physical storage topology**: one bundle, several streams, a database, or another representation;
- **derived projections**: recorded totals, effective totals, reports, and other readings.

The current semantics do not force the logical canonical basis to be stored in one ordered file. A future persistence decision should instead be earned by operational questions such as atomic publication, crash recovery, synchronization, compaction, or human inspectability.

Until those pressures exist, LOAM can preserve the fact/projection boundary without declaring either a unified ordered history or separate files to be the canonical source of truth.
