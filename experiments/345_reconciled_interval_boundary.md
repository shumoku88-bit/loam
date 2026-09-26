# Observation 345 - Reconciled interval and adjustment boundary

Status: **CANDIDATE - bounded Alloy qualification pending**

Tracks: #1372

## Trigger

Household dogfooding exposed a gap between current quantity support and useful
historical reconstruction.

For the current household data, `cash/jpy`, `yucho/jpy`, and
`all-country/jpy` have:

- retained dated Actual changes;
- a user-confirmed claim that household changes have been recorded since the
  bookkeeping start boundary;
- an independently observed current quantity in `CurrentQuantityAnchor`;
- an endpoint quantity computed from retained effects that agrees with that
  external observation.

Observation 243 already established that current support and historical support
must not be collapsed. Observation 244 qualified the temporal-anchor information
shape. Observation 246 qualified the reflected-root cut for one reconciliation
session. Observation 286 showed that a later anchor can support current quantity
without inventing unknown earlier history.

The remaining question is narrower:

> What evidence is sufficient to justify one bounded historical interval, and
> what does an explicit adjustment repair without retroactively certifying
> unknown detail?

## Model boundary

The Alloy model deliberately separates four things:

```text
asserted opening quantity
retained LOAM deltas
accepted completeness claim for one bounded interval
external observed quantity at a later checkpoint
```

It also contains two model-only witnesses:

```text
true opening quantity
hidden real-world deltas
```

Those witnesses are not proposed production data. They exist so Alloy can search
for worlds in which visible ledger evidence has the same endpoint while the
unobserved intermediate reality differs.

An explicit `adjustmentDelta` is ledger evidence. It closes a discrepancy at
the observation boundary. It does not rewrite or invent the physical cause of
the discrepancy.

## Questions

The model asks for these positive witnesses:

1. a declared start after an unknown earlier world can still support a bounded
   interval;
2. omitted positive and negative changes can cancel and preserve endpoint
   equality;
3. an unadjusted nonzero omission can create a reconciliation mismatch;
4. one explicit adjustment can establish the observed balance boundary;
5. that adjustment can coexist with an earlier historical gap;
6. two worlds can expose the same visible endpoint evidence while differing at
   an intermediate real quantity.

The model also checks these laws:

```text
qualified interval
  = accepted completeness from start
  + no adjustment inside that claimed interval
  + matching later observation

qualified interval
  -> ledger quantity = reality quantity at every boundary in the interval

endpoint match alone
  -/-> complete history

same visible endpoint
  -/-> same intermediate reality

repair equation
  -> observed boundary matches

adjustment reconciliation
  -/-> prior detailed completeness

qualified historical support
  -/-> any boundary before the declared start
```

## Why adjustment is not a failure

An adjustment is useful evidence when the physical cause of a discrepancy is
unknown.

```text
computed ledger  1200
observed reality 1259
difference        +59

explicit adjustment +59
  -> later balance boundary is usable again
```

The adjustment must remain visible as an adjustment. It must not be rewritten as
an invented food purchase, transfer, income source, or other historical detail.

This yields an intentionally asymmetric result:

```text
before adjustment
  detailed completeness may remain unknown

at and after a qualified adjustment boundary
  balance continuity may be re-established
```

## Production gate

No production type is earned by this candidate yet.

If the bounded model succeeds, the next question is whether the current
production vocabulary can express the result with a minimal relation over
existing evidence:

```text
declared start boundary + opening quantity
Actual Event frontier
CurrentQuantityAnchor checkpoint
optional explicit Adjustment Event
```

Only if that cannot preserve the qualified distinction should LOAM introduce a
new persistent history-support family.

In particular, do not:

- weaken `BalanceReview` merely to make historical reports appear;
- infer completeness from numeric endpoint equality;
- treat adjustment as proof of the preceding categories or purposes;
- synthesize hidden historical Events;
- restore the retired QuantityBasis subsystem;
- introduce a generic HistoryCompleteness object without additional pressure.

## Expected Alloy matrix

```text
qualifiedIntervalWithUnknownEarlierHistory                 SAT
matchingEndpointWithOffsettingOmissions                    SAT
mismatchWithoutAdjustment                                  SAT
adjustmentEstablishesObservedBoundary                      SAT
adjustmentLeavesEarlierGapVisible                          SAT
sameVisibleEndpointDifferentIntermediateReality            SAT

QualifiedIntervalMatchesReality                            UNSAT counterexample
EndpointMatchImpliesCompleteHistory                        SAT counterexample
SameVisibleEndpointDeterminesIntermediateReality           SAT counterexample
RepairEquationEstablishesObservedBoundary                  UNSAT counterexample
AdjustmentReconciliationImpliesPriorCompleteness           SAT counterexample
QualifiedIntervalNeverSupportsBeforeStart                  UNSAT counterexample
```

## Tool choice

Alloy is the right first tool because the pressure is information-shape and
counterexample discovery.

Lean is reserved for a production invariant only after the evidence relation is
settled.

TLA+ is deliberately not used: no concurrency or lifecycle ordering question is
required by this observation.
