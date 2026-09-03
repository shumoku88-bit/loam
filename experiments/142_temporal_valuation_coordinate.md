# Observation 142 — Temporal valuation coordinate

Status: **experiment under qualification**

## Question

Observation 033 established that a Measure-to-Measure relation can remain an overlay over physical Event history. It deliberately left rate source, timestamp, validity, historical-versus-current selection, conflict resolution, and arithmetic conversion outside its boundary.

The September external accounting pressure survey then identified temporal FX valuation as a remaining partial gap.

This observation asks the smallest next question:

> If several relation observations for the same Measure pair exist at different time coordinates, can occurrence-time booked valuation, settlement-time realised comparison, and current unrealised comparison be treated as different projections over the same retained relation history rather than one timeless rate attached to the subject?

The observation uses neutral experiment vocabulary. `ForeignMeasure`, `BaseMeasure`, `RelationObservation`, and `ValuationSubject` are not proposed Practical Core types.

## Minimal specimen

One Measure pair is held fixed:

```text
ForeignMeasure -> BaseMeasure
```

Three relation observations exist:

```text
R0 effective at C0, value V5
R2 effective at C2, value V6
R3 effective at C3, value V7
```

Two experiment-local subjects share the same occurrence coordinate:

```text
SettledSubject
  occurred C0
  settled  C2

OpenSubject
  occurred C0
  not settled
```

The current query coordinate is C3.

The relation values are intentionally symbolic. Observation 142 tests applicability and retained information, not multiplication, decimal representation, rounding, or residual allocation.

## Projection shape

For a retained relation history `H`:

```text
booked observation
  = relation effective at occurrence coordinate

settlement observation
  = relation effective at settlement coordinate

current observation
  = relation effective at current query coordinate
```

In the full-history world this yields:

```text
booked input            = R0 / V5
settlement input         = R2 / V6
current open input       = R3 / V7

realised comparison     = V5 -> V6
unrealised comparison   = V5 -> V7
```

No stored `FXGainLoss` fact is needed merely to expose those comparison inputs.

## Historical retention pressure

A second world keeps only the current relation observation:

```text
CurrentOnly.retained = R3
```

It can still answer the current query at C3, but it cannot reconstruct the C0 booked input or C2 settlement input.

This is deliberately parallel to LOAM's broader append-oriented historical reasoning:

```text
current relation observation
    !=
retained temporal relation history
```

Observation 142 does not yet model knowledge-time corrections to rates. It only asks whether effective-time history itself is observable.

## Positive witnesses

Expected SAT:

```text
fullHistoryUsesThreeTemporalObservations
realisedAndUnrealisedUseDifferentInputs
currentOnlyLosesHistoricalInputs
```

These witnesses establish that one retained relation history can expose distinct inputs for occurrence, settlement, and current valuation questions, while retaining only the current observation loses historical inputs.

## Deliberately too-strong boundaries

### One timeless relation value answers every valuation question

The assertion:

```text
OneTimelessRelationValueAnswersAllTemporalQuestions
```

claims that occurrence-time and settlement-time relation values are equal, and that occurrence-time and current relation values are equal.

Expected: **SAT counterexample**.

The specimen uses V5, V6, and V7 at distinct coordinates.

### Current relation alone can reconstruct historical selections

The assertion:

```text
CurrentOnlyCanReconstructHistoricalSelections
```

claims that retaining the current relation observation is sufficient to recover prior booked and settlement selections.

Expected: **SAT counterexample**.

The CurrentOnly world retains R3 but not R0 or R2.

## Sufficiency inside the bounded specimen

The assertion:

```text
FullHistoryTemporalSelectionIsUnambiguous
```

checks that, given the full retained history and the specimen's exact one-observation-per-relevant-coordinate shape:

- booked selection is unique;
- settlement selection is unique for the settled subject;
- no settlement selection exists for the open subject;
- current selection is unique.

Expected: **UNSAT counterexample**.

This is intentionally narrow. It does **not** show that effective time is sufficient once several sources or conflicting observations exist at one coordinate.

## Interpretation gate

If the expected result qualifies, the bounded candidate is:

```text
retained Measure-to-Measure relation observations
+ relation effective coordinate
+ occurrence / settlement / query coordinate
    -> booked relation input
    -> realised-comparison inputs
    -> current unrealised-comparison inputs
```

rather than:

```text
one subject
+ one timeless rate
```

The intended conceptual pressure is coordinate-like:

```text
same subject
same Measure pair

valuation relation depends on the question's time coordinate
```

This would extend Observation 033 without turning `Currency` or `ExchangeRate` into mandatory primitives.

## What is deliberately not modeled

Observation 142 does not yet decide:

- multiple relation sources at the same effective coordinate;
- external-source versus user override authority;
- missing-rate fallback;
- nearest-prior / nearest-next / interpolation rules;
- correction of a previously observed relation;
- knowledge-time / as-known relation queries;
- whether a rate has a validity interval rather than one effective coordinate;
- inverse or transitive relation laws;
- arithmetic conversion;
- decimal precision;
- rounding;
- residual allocation;
- realised or unrealised gain/loss accounting-role classification;
- persistence or canonical relation identity.

Those should remain separate pressure points.

## Not earned by this observation

Even if qualified, Observation 142 does not establish:

- canonical `Currency`;
- canonical `ExchangeRate`;
- canonical `ValuationSubject`;
- stored `FXGainLoss` facts;
- `RealisedGain` / `UnrealisedGain` Core objects;
- valuation-policy identity;
- source-priority policy;
- rate persistence format;
- CLI/TUI valuation commands;
- changes to Practical Core Events.

## Tool choice

**Alloy first.**

Observation 033 suggested TLA+ once relation observations evolve through time. The present question is smaller: static applicability over explicit effective coordinates and whether discarding historical relation observations loses selected answers. Alloy is sufficient for that distinguishability boundary.

TLA+ becomes appropriate if the next question is learned-time correction, concurrent rate publication, or historical as-known valuation. Lean becomes appropriate when exact conversion / rounding / conservation laws are the pressure.
