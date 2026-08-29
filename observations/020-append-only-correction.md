# Observation 020: Append-only correction

## Question

Can a correction change the effective meaning of an earlier commitment while the original event remains intact in append-only provenance?

Observation 019 showed that a reversible present can be projected from append-only Commit / Reverse history. Observation 020 asks whether correction can use the same direction of travel:

```text
original observation stays
        +
later Correction event
        ↓
current effective meaning
```

The point is not to choose an event-sourcing architecture. The narrower question is whether correction itself requires mutation of the earlier provenance event.

## Tool choice

TLA+ only.

The question is temporal and provenance-sensitive: an earlier event exists, a later Correction refers to it, and current meaning must remain correct over all reachable orderings. Alloy, J, Lean, and miniKanren would not add a distinct answer to this experiment yet.

## Minimal vocabulary

The model uses two Commit events, two Correction events, and two Reverse events.

```text
c0: original Purpose p0, quantity 1
k0: correct c0 to Purpose p1, quantity 1

c1: original Purpose p1, quantity 1
k1: correct c1 to Purpose p1, quantity 2

r0 -> c0
r1 -> c1
```

`k0` isolates a Purpose correction. `k1` isolates a quantity correction.

A Correction never replaces its target Commit in `history`. It is appended as a new named event referring to the earlier Commit.

Only one Correction per Commit is present in this model. Correction chains and competing corrections are outside this observation.

## Derived meaning

For a Commit `c`:

```text
EffectivePurpose(history, c)
EffectiveQuantity(history, c)
```

use the original Commit meaning until its Correction appears in history, then use the corrected meaning.

The original fields remain separately available through:

```text
CommitPurpose[c]
CommitQuantity[c]
```

Current explanation therefore contains both coordinates:

```text
original Purpose / quantity
effective Purpose / quantity
Correction identity, when present
```

Current aggregate quantity and availability are projected from the effective meaning of active Commit events.

A mutable oracle is retained only as a comparison instrument. It updates Purpose and quantity in place when a Correction occurs. The append-only projection is required to agree with that oracle throughout the reachable graph.

## Positive result

TLA+ tools 1.7.4 / TLC 2.19 completed the positive model with no error:

```text
1 initial state
225 states generated
225 distinct states found
0 states left on queue
complete state graph depth: 7
```

The complete reachable graph preserved:

```text
ProjectionMatchesOracle
EffectiveMeaningMatchesOracle
CurrentAggregateMatchesOracle
CapacityOK
AvailableMatchesOracle
CorrectionFollowsOriginal
CorrectionKeepsOriginal
TargetedCorrectionIsExact
CurrentExplanationTruthful
ReversalKeepsCorrectedCause
TargetedReverseIsExact
HistoryOnlyExtends
```

Within this finite vocabulary, current effective Purpose, quantity, aggregate committed quantity, availability, and explanation can therefore be derived from append-only Commit / Correction / Reverse provenance without mutating the earlier Commit event.

## Purpose-correction witness

The CI deliberately asks TLC to violate `NoPurposeCorrectionWitness`.

It finds:

```text
State 1
history = <<>>
oraclePurpose[c0] = p0

State 2
history = <<c0>>
oraclePurpose[c0] = p0

State 3
history = <<c0, k0>>
oraclePurpose[c0] = p1
```

The original `c0` event remains in history. `k0` is appended after it and changes only the effective Purpose coordinate.

## Quantity-correction witness

The CI separately asks TLC to violate `NoQuantityCorrectionWitness`.

It finds:

```text
State 1
history = <<>>
oracleQuantity[c1] = 1

State 2
history = <<c1>>
oracleQuantity[c1] = 1

State 3
history = <<c1, k1>>
oracleQuantity[c1] = 2
```

Again, the original `c1` remains. `k1` changes the effective quantity without erasing the earlier observation.

## Boundary: the corrected present does not reveal that it was corrected

The boundary model fixes two histories:

```text
leftHistory  = <<c1>>
rightHistory = <<c0, k0>>
```

`c1` was originally Purpose `p1`, quantity 1.

`c0` was originally Purpose `p0`, quantity 1, then `k0` corrected its effective Purpose to `p1`.

When event identity and correction provenance are flattened away, both histories have the same current view:

```text
Purpose p1
quantity 1
```

Yet their correction histories differ.

TLC therefore violates `FlattenedCurrentDeterminesCorrectionHistory` immediately in the initial boundary state.

So:

> Effective current meaning does not determine whether that meaning was original or corrected.

A display or projection that keeps only the corrected value can answer "what is current?" but cannot truthfully answer "how did it become current?"

## Finding

> Correction need not rewrite an observation; it can be a later relation that changes effective interpretation.

In this finite single-correction model:

```text
original observation  ────────────────┐
                                      │
Correction ──refers to original───────┤
                                      ↓
                              effective meaning
```

The earlier observation and the later interpretation can remain distinct.

This gives a useful asymmetry:

```text
provenance + Correction -> current effective meaning
current effective meaning -/-> correction provenance
```

The correction relation is therefore semantically relevant even when it disappears from a flattened current report.

## What this does not establish

This observation does not establish that:

- every domain should use append-only correction,
- a Correction should be stored as a full replacement meaning rather than a field-level patch,
- multiple Corrections can be ordered safely,
- competing or concurrent Corrections have an obvious winner,
- correcting a Correction should target the root Commit or the immediately prior Correction,
- a historical correction should always be subject to current capacity/admission constraints,
- this model determines a storage technology or implementation architecture,
- the finite result is an unbounded proof.

In particular, the model deliberately gives each Commit at most one Correction. The meaning of a correction chain has not yet been earned.

## Next pressure point

If the same original event can be corrected twice, what determines current meaning?

For example:

```text
c0: p0, quantity 1
k0 -> c0: p1, quantity 1
k1 -> c0: p1, quantity 2
```

Is sequence order sufficient? Must `k1` correct `c0` directly, or should it correct `k0`? Can two different correction histories yield the same effective present while preserving different explanations?

That is a separate question about correction chains and precedence, not assumed by Observation 020.
