# Observation 346 - Backward reconstruction from a later anchor

Status: **QUALIFIED - bounded Alloy model retained in active research CI**

Tracks: #1372

## Trigger

Observation 345 qualified a bounded historical interval using completeness, an
opening quantity, retained deltas, and a matching later observation.

This observation asks whether the opening quantity is redundant when LOAM
already has an exact later CurrentQuantityAnchor.

The candidate equation is:

```text
quantity at t
  = exact later anchor
  - retained ordinary deltas after t through the anchor
```

If this determines every quantity inside a complete interval, the opening
quantity can be derived instead of persisted.

## Adjustment pressure

The bounded model uses an explicit adjustment witness to distinguish a later
reconciled quantity from prior detailed completeness.

That model witness does **not** require a production `Adjustment` Core
primitive. Production LOAM may instead retain an unexplained exact quantity
movement as ordinary Actual evidence and later refine its ActualValidity date,
as Observation 353 demonstrates.

The important law is epistemic:

```text
later exact anchor + accepted complete interval + dated current Actual deltas
  -> backward reconstruction inside the certified interval

endpoint agreement alone
  -/-> completeness
```

A balance repair or unexplained movement does not automatically certify an
earlier interval. Completeness remains independently asserted evidence.

## Executed bounded matrix

The active Alloy research manifest retains the qualified matrix:

```text
backwardReconstructionWithoutStoredOpening             SAT
sameAnchorAndDeltasForceSameOpening                     SAT
adjustmentBlocksBackwardTraversal                       SAT
samePostAdjustmentEvidenceDifferentEarlierReality       SAT

CleanCompleteAnchorDeterminesEveryBoundary              UNSAT counterexample
CleanCompleteAnchorDeterminesOpening                    UNSAT counterexample
SameCleanAnchorAndDeltasDetermineOpening                UNSAT counterexample
ExactLaterAnchorAloneDeterminesEarlierReality           SAT counterexample
AdjustmentCanBeTraversedBackwardAsOrdinaryDelta         SAT counterexample
```

The negative checks establish that, under the model's completeness hypotheses,
the later exact anchor and retained deltas determine the interval quantities and
derived opening quantity. The positive counterexamples preserve the separation
between an exact current observation and unknown earlier reality.

## Production implication

The minimal production shape does not need to persist an opening quantity.

It needs only:

```text
coordinate + complete-since start day
existing correction-aware dated Actual
existing exact CurrentQuantityAnchor
```

The complete-since claim is explicit household evidence. It must not be inferred
from endpoint equality or generated merely because a reconciliation matches.

Production promotion should therefore keep this evidence family narrow and give
ordinary users a writer/TUI path for setting, moving, or removing the start
boundary. Historical readers may then reconstruct only at or after that start
boundary and must fail closed when relevant current Actual cannot be placed in
time.
