# Observation 052: effect identity before coordinate collapse

## Question

Should the practical core permanently require at most one effect for each
`(Event, Locus, Measure)` coordinate, or should distinct effects retain their
own identity even when they share that coordinate?

The practical `Event` boundary introduced in PR #79 currently rejects repeated
`(LocusId, MeasureId)` coordinates inside one event. That matches Observation
032's `Event -> Locus -> Measure -> lone Int` relation, but it may be too strong
if a later question needs to distinguish pieces of one coordinate total.

## Experiment

`052_effect_identity_before_coordinate_collapse.als` compares two levels of
information:

1. a collapsed answer: total quantity at each `Event x Locus x Measure`, and
2. identity-preserving detail: distinct `Effect` identities carrying locus,
   measure, quantity, and a hypothetical per-effect `Purpose` overlay.

`Purpose` is not being added to the practical core here. It is only a witness
for the general class of future questions that may distinguish two effects
which currently occupy the same locus/measure coordinate.

## Alloy 6.2.0 / Sat4j results

```text
duplicateCoordinateCanCarryDistinctPurposes   SAT
sameCollapsedCanHidePurposeBreakdown          SAT
CollapsedCoordinatesDeterminePurposeBreakdown SAT
IdentityDetailDeterminesPurposeBreakdown      UNSAT
```

The SAT counterexample to `CollapsedCoordinatesDeterminePurposeBreakdown`
shows that equal coordinate totals do not determine a later effect-level
breakdown. Distinct effects at one coordinate can carry different future
meaning while summing to the same current amount.

The UNSAT result for `IdentityDetailDeterminesPurposeBreakdown` confirms that,
within this model, retaining effect identity and its explicit relations is
sufficient to determine that breakdown.

## Interpretation

The useful separation is:

```text
Effect identity
    !=
Locus x Measure coordinate
```

`Locus x Measure` remains a valid projection for questions such as current
quantity at a coordinate. It should not automatically be the identity key for
all facts that contributed to that quantity.

Therefore the current practical `coordinateNodup` constraint should be treated
as a temporary representation restriction, not a permanent domain law.

A likely next practical change is to introduce a stable opaque `EffectId`, make
identity uniqueness the admission rule, allow multiple distinct effects at the
same `(LocusId, MeasureId)`, and define coordinate totals as projections over
those effects.

This observation does not assert that `Purpose` must be effect-level, nor that
every event needs duplicate coordinates. It only shows that coordinate collapse
can destroy future observational power when such a distinction matters.
