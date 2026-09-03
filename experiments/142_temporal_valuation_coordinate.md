# Observation 142 — Temporal valuation coordinate

Status: **qualified bounded experiment**

## Question

Observation 033 established that a Measure-to-Measure relation can remain an overlay over physical Event history. It deliberately left rate source, timestamp, validity, historical-versus-current selection, conflict resolution, and arithmetic conversion outside its boundary.

The September external accounting pressure survey then identified temporal FX valuation as a remaining partial gap.

Observation 142 asks the smallest next question:

> If several relation observations for the same Measure pair exist at different time coordinates, can occurrence-time booked valuation, settlement-time realised comparison, and current unrealised comparison be treated as different projections over the same retained relation history rather than one timeless rate attached to the subject?

The vocabulary is experiment-local. `ForeignMeasure`, `BaseMeasure`, `RelationObservation`, and `ValuationSubject` are not proposed Practical Core types.

## Minimal specimen

One Measure pair is fixed:

```text
ForeignMeasure -> BaseMeasure
```

Three relation observations exist:

```text
R0 effective C0, value V5
R2 effective C2, value V6
R3 effective C3, value V7
```

Two subjects share occurrence C0:

```text
SettledSubject
  occurred C0
  settled  C2

OpenSubject
  occurred C0
  not settled
```

The current query coordinate is C3.

The relation values are symbolic. This observation tests applicability and retained information, not multiplication, decimal representation, rounding, or residual allocation.

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

In the full-history world:

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

It can answer the current C3 query, but it cannot reconstruct the C0 booked input or C2 settlement input.

So the specimen distinguishes:

```text
current relation observation
    !=
retained temporal relation history
```

This observation does not yet model knowledge-time corrections to rates. It only asks whether effective-time history itself is observable.

## Qualified Alloy result

Alloy 6.2.0 + Sat4j produced the complete expected result set.

SAT witnesses:

```text
fullHistoryUsesThreeTemporalObservations
realisedAndUnrealisedUseDifferentInputs
currentOnlyLosesHistoricalInputs
```

SAT counterexamples to deliberately too-strong assertions:

```text
OneTimelessRelationValueAnswersAllTemporalQuestions
CurrentOnlyCanReconstructHistoricalSelections
```

UNSAT counterexample:

```text
FullHistoryTemporalSelectionIsUnambiguous
```

The UNSAT result is intentionally bounded by the specimen's exact one-observation-per-relevant-coordinate shape. It does not establish uniqueness when several sources or conflicting observations exist at one coordinate.

Qualification head:

```text
94606f707ed3a9aa0759bd65a10ea5797c8d2387
```

Workflow job `100724243346` completed SUCCESS, including Alloy execution and the expected-result checker.

## Interpretation

The bounded candidate is:

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

The same subject and Measure pair can therefore participate in different valuation questions whose selected relation depends on the question's time coordinate.

Observation 142 also shows that retaining only the current relation is too small if historical booked or settlement inputs must remain reconstructable.

This extends Observation 033 without turning `Currency` or `ExchangeRate` into mandatory primitives.

## What remains open

Observation 142 does not decide:

- multiple relation sources at the same effective coordinate;
- external-source versus user override authority;
- missing-rate fallback;
- nearest-prior / nearest-next / interpolation rules;
- correction of a previously observed relation;
- knowledge-time / as-known relation queries;
- validity intervals;
- inverse or transitive relation laws;
- arithmetic conversion;
- decimal precision;
- rounding and residual allocation;
- realised or unrealised gain/loss accounting-role classification;
- persistence or canonical relation identity.

Those are separate pressure points.

## Not earned

Observation 142 does not establish:

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

Observation 033 suggested TLA+ once relation observations evolve through learned time. The present question is smaller: static applicability over explicit effective coordinates and whether discarding historical relation observations loses selected answers. Alloy is sufficient for that distinguishability boundary.

TLA+ becomes appropriate for learned-time correction, concurrent rate publication, or historical as-known valuation. Lean becomes appropriate when exact conversion, rounding, and conservation laws are the pressure.
