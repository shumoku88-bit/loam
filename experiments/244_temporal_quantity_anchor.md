# Observation 244 — Temporal quantity anchor compression

Status: **QUALIFIED — one qualified temporal quantity anchor can represent both zero-origin and later non-zero support in the bounded model**

Baseline:

```text
1fa89531029d4ef3cc6a33ed34e0a7875932c39c
experiment: separate current and historical balance support (#816)
```

Qualified CI:

```text
workflow: Observation 244
run:      34743725455
job:      103687673906
result:   SUCCESS
Alloy:    6.2.0 / Sat4j
```

## Trigger

Observation 243 established that two temporal support questions cannot be collapsed:

```text
current/as-of quantity support
!=
full zero-origin historical support
```

A later non-zero anchor may justify the current quantity while refusing earlier boundaries. That result raised a new compression question:

> Must LOAM retain two different support ontologies, or can one small temporal quantity anchor represent both cases without weakening historical refusal, missing-vs-zero, or correction-aware derivation?

The tempting candidate is conceptually:

```text
TemporalQuantityAnchor
  coordinate
  boundary
  quantity
```

with exact zero-origin as the special case:

```text
boundary = retained-history origin
quantity = 0
```

and a reconstructed opening debt as another case:

```text
boundary = later admitted boundary
quantity = known non-zero quantity
```

This looks similar to retired `QuantityBasis`, so the experiment also tests whether the time coordinate and qualification semantics carry genuinely new information rather than merely renaming the old basis machinery.

## Prior pressure kept fixed

Observation 085 already established a query-relative scalar basis shape:

```text
basis : Coordinate -> lone Int
AnchoredCurrent = basis + Event quantity
```

Later production compression retired the general QuantityBasis / BasisCut path after real-household dogfood found that the live practical balances only needed five explicit exact-zero origins. The current production replacement deliberately keeps a smaller fact:

```text
ZeroOriginCoverage
```

and delegates quantity arithmetic to the existing correction-aware Event frontier.

Observation 244 therefore does **not** ask whether QuantityBasis should return. It asks whether a later non-zero support witness can be represented with less machinery while preserving the properties that justified `ZeroOriginCoverage`.

## Candidate meanings under test

The model distinguishes three ideas that must not be conflated.

### Bare observed quantity

```text
ObservedQuantity
  coordinate
  boundary
  quantity
```

This says only that a value was observed at one boundary. By itself it does not establish that every later household change is retained.

### Qualified temporal anchor

```text
TemporalQuantityAnchor
  coordinate
  boundary
  quantity
```

with the stronger semantic contract:

> from this boundary onward, the selected correction-aware retained frontier is complete enough for this coordinate to derive later quantities.

The qualification is semantic, not a new arithmetic engine. Later quantity remains:

```text
anchor quantity
+
correction-selected frontier changes after the anchor
```

### Old scalar basis

```text
Coordinate -> Quantity
```

with no temporal coordinate. This is enough only when the application origin is globally fixed. Once later anchors are admitted, the boundary at which the scalar applies can change the answer.

## Alloy model

`244_temporal_quantity_anchor.als` models:

```text
Coordinate
Moment with total ordering

bare observation:
  observedMoment
  observedValue

qualified anchor:
  anchorMoment
  anchorValue

movement:
  rawDelta
  frontierDelta

model-side counterexample witness:
  hiddenDelta
```

`frontierDelta` represents the already selected correction-aware movement frontier. `rawDelta` is retained separately so the model can test whether anchor semantics accidentally bypasses correction selection.

`hiddenDelta` is not a proposed production concept. It exists only to construct two possible worlds that share the same bare observation and retained movement but differ in an unretained later change. Qualified anchors rule such later hidden changes out by definition.

## Executed result

Alloy produced the expected matrix:

```text
zeroOriginAsUnifiedAnchor                    SAT
laterNonzeroAnchorSupportsCurrentOnly        SAT
missingAnchorWithZeroNetStillUnsupported     SAT
scalarBasisCannotPlaceLaterAnchor             SAT
bareObservationDoesNotDetermineCurrent        SAT
correctionsRemainRelevant                     SAT

ZeroOriginEncodingPreservesAnswer             UNSAT counterexample
LaterAnchorNeverSupportsEarlierBoundary       UNSAT counterexample
BareObservationDeterminesCurrentReality       SAT counterexample
ScalarBasisDeterminesTemporalAnswer            SAT counterexample
RawDeltaDeterminesAnchoredAnswer               SAT counterexample
QualifiedAnchorAndFrontierDetermineAnswer     UNSAT counterexample
```

The expected-result checker passed in CI.

## Findings

### 1. Zero-origin can be represented as one temporal-anchor special case

The model found a unified anchor at the first boundary with quantity zero, and found no counterexample to equivalence with the old zero-origin answer in the selected bounded arithmetic.

So the abstract information can be written as:

```text
zero-origin support
=
TemporalQuantityAnchor(coordinate, origin, 0)
```

without introducing a second zero-specific quantity arithmetic rule.

This is an information-shape result only. It does not yet authorize deleting production `ZeroOriginCoverage`.

### 2. The same anchor shape can represent later non-zero support

Alloy found a later non-zero anchor that supports the current boundary while refusing the origin boundary.

Therefore the same three coordinates are sufficient to express both cases:

```text
coordinate
boundary
quantity
```

The distinction between strong origin history and later-only support is preserved by the anchor boundary itself rather than by two unrelated support vocabularies.

### 3. Missing anchor remains different from zero

The model found a coordinate whose retained net change is numerically zero while no anchor exists, and the coordinate remains unsupported.

Therefore unified anchors do not require the dangerous rule:

```text
no evidence -> zero
```

The existing fail-closed law survives:

```text
missing anchor != anchor quantity 0
```

### 4. Time is not decorative and scalar QuantityBasis is insufficient for later anchors

Two worlds can have:

```text
same anchor quantity
same correction-selected movement
```

but apply that quantity at different boundaries and therefore derive different current answers.

Alloy found this witness and a counterexample to `ScalarBasisDeterminesTemporalAnswer`.

This is the central distinction from Observation 085's old scalar basis:

```text
Coordinate -> Quantity
```

is not sufficient once a basis need not live at one globally fixed application origin.

The time coordinate is independently observable information.

### 5. Bare observation is too weak

Two worlds can share:

```text
same observed boundary
same observed quantity
same retained frontier
```

while differing in an unretained later change. Their real current quantities differ.

Therefore a generic `ObservedQuantity` fact does **not** by itself justify later current balance derivation.

The useful candidate is stronger than measurement storage. It must mean something like:

> this quantity is an admitted derivation anchor and the selected movement frontier after it is complete enough for this coordinate.

This semantic strength must not be inferred from a description string, sign, AccountingRole, or mere Event presence.

### 6. Correction-aware frontier remains independently necessary

Alloy found worlds with identical anchor evidence and identical raw movement but different correction-selected frontiers, producing different anchored answers.

So temporal anchors do not absorb or replace correction semantics.

The surviving composition remains:

```text
TemporalQuantityAnchor
+
existing correction-frontier selection
+
existing quantity summation
    -> supported later quantity
```

not:

```text
TemporalQuantityAnchor
+
raw Event bytes
    -> quantity
```

### 7. Qualified anchor plus selected frontier is sufficient in the bounded model

Once anchor boundary, anchor quantity, and correction-selected frontier are fixed, Alloy found no world with a different supported anchored answer.

No separate `CurrentBalanceSupport`, `ZeroOriginQuantity`, or later-anchor arithmetic engine is earned by this bounded vocabulary.

The possible compression is therefore semantic:

```text
one temporal anchor relation
+
one existing correction-aware delta path
```

rather than parallel current/origin quantity engines.

## Real-data reading

The immediate household pressure remains `debt-friend-k`.

Canonical Actual retains a reconstructed opening entry with a non-zero liability quantity. Treating that coordinate as exact-zero-origin would be false, but its evidence shape is compatible with a later temporal anchor **if** an independent production rule can admit the boundary and quantity as a qualified anchor.

`debt-mother` remains the negative control. Visible borrow/repay activity with current net zero does not itself establish an anchor or a complete post-anchor stream. Observation 244 therefore gives no permission to mark it supported merely because its selected Effects cancel.

## Production gate

Observation 244 does not immediately add a Core type or canonical file.

The next production investigation is narrower:

1. identify whether current production already has a trustworthy boundary from which `debt-friend-k`'s retained movement is complete;
2. determine whether its non-zero opening quantity can be admitted without parsing human description text;
3. test whether a tiny anchor relation can reuse `QuantityInspection` / correction-frontier arithmetic directly;
4. preserve existing `StockFlowReview` behavior for zero-origin coordinates;
5. do not resurrect QuantityBasis identities, correction memories, BasisCut, or a generic anchor authority unless an independently changing fact requires them.

A likely minimal candidate, still not a production decision, is conceptually:

```text
EffectCoordinate -> lone (Boundary × Quantity)
```

with zero-origin coordinates encoded or projected as `(origin, 0)` and later anchors admitted only from explicit typed evidence.

## Important non-claims

This bounded result does not establish:

- how a production boundary is identified;
- that occurrence date alone is a valid anchor boundary;
- that an opening Event automatically becomes an anchor;
- provenance or reconciliation workflow;
- multiple anchors for the same coordinate;
- anchor correction/history semantics;
- cross-Measure valuation;
- conventional Balance Sheet completeness;
- that `ZeroOriginCoverage` should now be deleted;
- that retired QuantityBasis should return.

In particular, the candidate should stay much smaller than the retired basis subsystem unless new dogfood produces a concrete need for identity, correction, or publication machinery.

## Verdict

```text
one anchor shape can encode zero-origin and later non-zero support   YES (bounded)
time coordinate is independently necessary for later anchors        YES
bare observed quantity is sufficient                                NO
missing anchor can collapse to numeric zero                          NO
anchor can replace correction-frontier selection                     NO
qualified anchor + selected frontier determines answer               YES (bounded)
retired scalar QuantityBasis is sufficient                           NO
production anchor ontology currently earned                          NOT YET
next pressure                                                         production reuse seam
```

The useful generic abstraction is therefore not `BalanceSupport` and not bare `ObservedQuantity`.

It is a **qualified temporal quantity anchor**: a known quantity at a known boundary whose downstream retained frontier is strong enough to support derivation. That shape is accounting-neutral and can, in principle, apply to inventory, statement reconciliation, event-sourced snapshots, or other delta-derived state without making those domains share accounting ontology.
