# Observation 150 — Can Actual become one atomic generation?

## Pressure inherited from Observation 149

Observation 149 compared the current sidecar topology with three alternatives.
Private scratch pressure against the current canonical generation found:

```text
production today
    KEEP CURRENT

semantic directory
    not earned

whole-household snapshot
    not earned

unified Actual
    deserves the next observation
```

The attractive property was specific. A scratch unified-Actual specimen could be
fully staged beside the old generation and then exposed by one atomic replacement:

```text
old complete Actual
-> new complete Actual staged but invisible
-> one authority switch
-> new complete Actual
```

That removes the current multi-file Actual publication shape from the physical
commit protocol without requiring Scheduled, QuantityBasis, or view configuration
to share the same failure domain.

Observation 149 did not authorize implementation or migration. Observation 150
asks whether that physical simplification is semantically admissible at all.

## Question

> Can Event, ActualValidity, EventDescription, and EventCorrection remain distinct
> typed facts while one complete Actual generation becomes the physical authority
> commit unit?

This is deliberately not the same claim as flattening all Actual information into
one undifferentiated record format.

## Candidate semantic shape

One physical generation contains four typed facets:

```text
ActualGeneration
  Events
  ActualValidity
  EventDescription
  EventCorrection
```

The generation is admissible only when all retained identity-bearing references
close over the same authoritative Event set.

Representative rules:

- Event identities are unique;
- occurrence-date endpoints resolve to Events in the generation;
- description endpoints resolve to Events in the generation;
- EventCorrection target and replacement endpoints both resolve to Events in the
  same generation;
- a malformed or incomplete candidate is refused before it can enter publication.

The current core semantics of those fact families are not merged merely because
they share one physical commit unit.

## Candidate publication protocol

Observation 150 models a sibling-stage protocol:

```text
1. read old authoritative Actual generation
2. construct complete candidate in memory / sibling stage
3. validate cross-facet closure
4. keep old generation authoritative while candidate is staged
5. atomically replace the authoritative generation
```

The reader-visible sequence sought is exactly:

```text
old complete
old complete
new complete
```

There is no reader-visible partial or mixed generation in the qualified path.

## Lean qualification

`Loam/Observations/Observation150.lean` checks the following boundaries.

### 1. Complete generation admission

Representative old and new generations are accepted when every retained endpoint
closes over the Event authority inside that same generation.

### 2. Fail closed before staging

The candidate is rejected when it contains:

- orphan ActualValidity evidence;
- orphan EventDescription evidence;
- an EventCorrection endpoint outside the candidate Event set;
- duplicate authoritative Event identity.

These are staging refusals, not partially published states.

### 3. Typed facets remain distinct

A description-only candidate mutation does not silently mutate Event,
ActualValidity, or EventCorrection facets. Physical unification therefore does not
imply semantic coalescing.

### 4. Staged candidate is invisible

Staging a complete new generation leaves the old generation reader-visible.

The authority changes only on the modeled atomic commit.

### 5. Exact old-old-new path

The qualified path exposes:

```text
old authoritative -> old while new is staged -> new after commit
```

and never classifies a reachable phase as mixed / partial.

### 6. Non-Actual families remain outside

Scheduled, QuantityBasis, and view configuration are modeled outside the Actual
store. Committing Actual changes only the Actual authority and leaves those
families unchanged.

## What this observation does not prove

This is still not a production persistence format.

It does not choose:

- concrete wire syntax;
- section encoding;
- checksums;
- on-disk index structure;
- streaming versus whole-file decoding;
- whether current sidecars are migrated at all;
- how a one-time canonical cutover would be performed;
- whether Git diffs remain pleasant enough under one generated file.

It also does not claim that losing sidecar-level corruption isolation is free.
Observation 149 already showed that a unified Actual container increases the
failure radius inside Actual. That tradeoff must remain explicit.

## Result sought

If the Lean qualification succeeds, the next pressure should remain small:

1. do not change production storage yet;
2. compare a few concrete unified-Actual wire candidates against the current
   sidecar bytes using public synthetic data first;
3. require lossless typed reconstruction and deterministic bytes;
4. measure corruption refusal and Git diff locality;
5. only then decide whether a production persistence implementation has earned
   its complexity.

No canonical household data is changed by Observation 150.
