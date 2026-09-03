# Observation 128 — Can one budget-reallocation shape serve Capacity and Backing without a new Envelope concept?

Status: qualified bounded Alloy observation

## Question

Observation 106 already qualified one important compression:

```text
Actual movement
Capacity movement

share signed movement algebra
but do not share semantic authority
```

Observation 126 then separated Capacity authority from Backing support, and Observation 127 showed that Backing needs quantity-bearing apportionment rather than only relation topology.

That makes a stronger practical compression tempting:

> Can an ordinary household action such as "move 2 from Food to Travel" reuse one balanced signed movement shape across Capacity and Backing, distinguished only by semantic authority, without introducing `EnvelopeTransfer`, stored envelope balances, or another budget object family?

Observation 128 attacks that idea rather than protecting it.

## Strong hypothesis under attack

An aggressive design would retain only:

```text
Food   -2
Travel +2
```

plus a semantic plane such as:

```text
Capacity
Backing
```

If that were sufficient, a shared Purpose-vector plus plane would determine all relevant budget answers.

Backing makes that suspicious because these two operations have the same signed Purpose vector and the same Backing authority:

```text
Bank: Food -> Travel 2
Cash: Food -> Travel 2
```

but they do not change the same physical support.

So the observation asks:

1. Is one semantic plane per user-facing reallocation sufficient?
2. If not, can LOAM still reuse the existing balanced movement algebra by giving each semantic domain the smallest coordinate it actually observes?

The candidate rescue is:

```text
Capacity coordinate
  Purpose

Backing coordinate
  Holding x Purpose
```

rather than a new canonical `EnvelopeTransfer` concept.

## Why Alloy

This is a static distinguishability / minimum-sufficiency problem. The model compares several readings of one household-facing phrase:

```text
move 2 from Food to Travel
```

No ordering, retry, concurrency, or liveness question is needed, so Alloy is the smallest instrument.

## Bounded before-state

Physical holdings:

```text
Bank = 5
Cash = 5
```

Capacity:

```text
Food   = 6
Travel = 4
```

Backing:

```text
Bank:
  Food   4
  Travel 1

Cash:
  Food   2
  Travel 3
```

Initially both purposes are exactly backed:

```text
Food   Capacity 6, Backed 6
Travel Capacity 4, Backed 4
```

## Three authority readings

### Capacity only

```text
Capacity:
  Food   -2
  Travel +2
```

Backing does not move.

```text
Food   Capacity 4, Backed 6, Gap 0
Travel Capacity 6, Backed 4, Gap 2
```

### Backing only on Bank

```text
Bank Backing:
  Food   -2
  Travel +2
```

Capacity does not move.

```text
Food   Capacity 6, Backed 4, Gap 2
Travel Capacity 4, Backed 6, Gap 0
```

### Capacity and Backing together

Apply both evidence changes.

```text
Food   Capacity 4, Backed 4, Gap 0
Travel Capacity 6, Backed 6, Gap 0
```

The same household-facing phrase therefore admits three observably different authority readings.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
sameSurfaceTransferSupportsThreeAuthorityReadings       SAT
sameBackingPurposeVectorDifferentHoldingAnswer          SAT
composedCapacityAndBackingClosesDifferentGaps           SAT
inhabitedTypedDeltaCopy                                  SAT

OneSemanticPlanePerReallocationIsEnough                 SAT counterexample
BackingPlanePurposeVectorDeterminesSelectedBacking      SAT counterexample

CapacityPurposeDeltaDeterminesEntitlement               UNSAT counterexample
HoldingPurposeBackingDeltaDeterminesBackingAnswers      UNSAT counterexample
TypedDeltasDetermineBudgetProjection                    UNSAT counterexample
```

The complete expected result set passed on the PR merge ref against `main`.

## Finding 1: the strong compression is false

The first design intuition was too aggressive.

```text
signed Purpose vector
+ semantic plane
```

is not enough for Backing.

`BackingBank` and `BackingCash` retain the same aggregate Backing Purpose vector:

```text
Food   -2
Travel +2
```

but differ on a selected-Bank query:

```text
BackingBank:
  Bank supports Food 2, Travel 3

BackingCash:
  Bank supports Food 4, Travel 1
```

So the Holding coordinate carries independently observable information.

The bounded separation is:

```text
Backing authority
+ Purpose delta
    !=
Holding-specific Backing change
```

This is a real counterexample to the idea that a `Plane` tag alone could make one Purpose-vector representation sufficient across Capacity and Backing.

## Finding 2: one authority per user operation is also too small

`BothBank` changes Capacity and Bank Backing together and closes the different gaps left by the single-authority readings.

Therefore a model that insists one household-facing reallocation belongs to exactly one semantic authority loses an admitted world.

This does **not** earn a third `CombinedBudgetPlane` or canonical `EnvelopeTransfer` fact. A smaller interpretation remains available:

```text
one convenience operation
    -> one Capacity evidence change
    + one Backing evidence change
```

The UI may compose them while canonical authority remains separate.

## Finding 3: the smaller shared-algebra candidate survives

The counterexample does not force a new movement algebra.

Within this bounded model Alloy found no counterexample after retaining domain-specific coordinates:

```text
Capacity movement
  coordinate = Purpose

Backing movement
  coordinate = Holding x Purpose
```

Once those signed deltas are fixed, the selected bounded projection is fixed:

```text
Capacity
Backed
selected-Holding Backing
Funded
Gap
```

`BothBank` and `CopyBothBank` provide an inhabited same-evidence pair, so the sufficiency result is not merely vacuous.

The useful compression is therefore narrower than the original guess:

```text
shared balanced signed movement mechanics     yes
one universal Purpose coordinate              no
one semantic Plane tag as sufficient context  no
new EnvelopeTransfer concept                  not earned

domain-specific coordinate information       required
```

This fits the existing `BalancedMovement` design particularly well because its movement changes are already parameterized by caller-chosen semantic coordinate type.

## Relationship to Observation 106

Observation 106 established that Actual and Capacity may reuse one signed Effect algebra while their semantic distinction remains explicit.

Observation 128 does not reopen or contradict that result. It adds Backing pressure and sharpens the rule:

```text
shared algebra can survive
only if each domain retains all coordinates later household questions observe
```

For Capacity, Purpose is sufficient in this bounded question.

For Backing, Purpose alone is not sufficient; Holding x Purpose is the smaller surviving coordinate.

## Product interpretation

The result supports a future envelope-like UI without making `Envelope` the owner of truth.

A budget screen may eventually project:

```text
Food
  Capacity
  Backed
  Remaining
  Gap
```

while an operation such as:

```text
move 2 from Food to Travel
```

may choose to change:

```text
Capacity only
Backing only
Capacity + Backing
```

The user-facing interaction can stay compact even though the retained evidence meanings remain separate.

The important candidate remains:

```text
Capacity evidence
Backing evidence
physical holdings
eligibility
Actual / Scheduled evidence
        |
        v
budget projections
```

without storing `EnvelopeBalance`, `Funded`, `Gap`, or a generic `BudgetTransfer` as additional canonical truth.

## Boundaries

Observation 128 does not establish:

- a production Backing writer;
- a production Backing coordinate type;
- that Backing deltas rather than some finer evidence should be persisted;
- an `Envelope` or `EnvelopeTransfer` object;
- automatic Capacity + Backing coupling;
- rebalancing priority rules;
- whether Backing follows spending automatically;
- whether credit or liabilities may permit physical over-commitment;
- multi-Measure / currency valuation;
- historical Backing correction or time semantics;
- ownership / Agent semantics;
- Practical Core, persistence, CLI, or canonical household-data changes.

The qualified result is only that the strongest `Purpose vector + plane` compression loses household information, while shared balanced movement mechanics with domain-specific coordinates preserve the selected bounded answers.
