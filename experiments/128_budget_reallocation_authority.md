# Observation 128 — Can one budget-reallocation shape serve Capacity and Backing without a new Envelope concept?

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

This observation tries to refute that idea rather than protect it.

## Strong hypothesis under attack

A very aggressive design would retain only:

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

Backing makes that suspicious.

These two operations have the same signed Purpose vector and the same Backing authority:

```text
Bank: Food -> Travel 2
Cash: Food -> Travel 2
```

but they do not change the same physical support.

So Observation 128 asks two separate questions:

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

This is a static distinguishability / minimum-sufficiency problem.

The model keeps one bounded before-state and compares several possible readings of the same household-facing phrase:

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

So initially:

```text
Food   Capacity 6, Backed 6
Travel Capacity 4, Backed 4
```

Both are fully funded.

## Three authority readings

### Capacity only

```text
Capacity:
  Food   -2
  Travel +2
```

Backing does not move.

Afterward:

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

Afterward:

```text
Food   Capacity 6, Backed 4, Gap 2
Travel Capacity 4, Backed 6, Gap 0
```

### Capacity and Backing together

Apply both of the above evidence changes.

Afterward:

```text
Food   Capacity 4, Backed 4, Gap 0
Travel Capacity 6, Backed 6, Gap 0
```

The user-facing phrase can therefore correspond to three different household answers.

The observation does not assume these must become three command names. It asks which distinctions must survive below the UI.

## Holding identity pressure

The stronger attack on the "plane is enough" hypothesis compares:

```text
BackingBank:
  Bank Food -2
  Bank Travel +2

BackingCash:
  Cash Food -2
  Cash Travel +2
```

Both have the same aggregate Backing Purpose vector:

```text
Food   -2
Travel +2
```

and both have Backing authority.

But a selected-Bank query differs:

```text
BackingBank:
  Bank supports Food 2, Travel 3

BackingCash:
  Bank still supports Food 4, Travel 1
```

If Alloy finds this distinction, then:

```text
Backing plane
+ signed Purpose vector
```

is too small.

Information equivalent to the Holding coordinate remains observable.

## Candidate compression after the attack

The smaller proposal is not a new universal budget object.

It is:

```text
reuse balanced signed movement mechanics

Capacity movement coordinate:
  Purpose

Backing movement coordinate:
  Holding x Purpose
```

A convenience UI operation may submit both a Capacity movement and a Backing movement together, but the two evidence meanings remain separate.

That would preserve the existing LOAM pattern:

```text
share mechanics where equal structure is sufficient
keep semantic coordinates where erasure changes household answers
```

## Qualification targets

Expected witnesses:

```text
sameSurfaceTransferSupportsThreeAuthorityReadings       SAT
sameBackingPurposeVectorDifferentHoldingAnswer          SAT
composedCapacityAndBackingClosesDifferentGaps           SAT
inhabitedTypedDeltaCopy                                  SAT
```

Expected counterexamples to the aggressive compression:

```text
OneSemanticPlanePerReallocationIsEnough                 SAT counterexample
BackingPlanePurposeVectorDeterminesSelectedBacking      SAT counterexample
```

Expected sufficiency checks for the smaller typed-coordinate candidate:

```text
CapacityPurposeDeltaDeterminesEntitlement               UNSAT counterexample
HoldingPurposeBackingDeltaDeterminesBackingAnswers      UNSAT counterexample
TypedDeltasDetermineBudgetProjection                    UNSAT counterexample
```

## What would refute the current design intuition?

There are several useful ways this experiment can disagree with the current intuition.

If `BackingPlanePurposeVectorDeterminesSelectedBacking` has no counterexample, the Holding coordinate may be unnecessary for the admitted household questions and the proposed Backing representation is too rich.

If `HoldingPurposeBackingDeltaDeterminesBackingAnswers` has a counterexample, then even `(Holding, Purpose)` quantity deltas are too small and another piece of Backing evidence is independently observable.

If `TypedDeltasDetermineBudgetProjection` has a counterexample, then reusing balanced movement mechanics at these coordinates is insufficient for the selected budget projection and a deeper model change is required.

So the experiment is not written to make the shared-algebra idea win.

## Practical interpretation if the expected boundary qualifies

A future budget UI could expose a simple operation such as:

```text
Move 2
From: Food
To:   Travel

[ ] move permission only
[ ] move backing too
```

or choose a more automatic interaction later.

Internally, the important candidate would remain smaller:

```text
Capacity evidence
Backing evidence
physical holdings
eligibility
Actual / Scheduled evidence
        |
        v
Capacity / Backed / Remaining / Gap projections
```

without storing an `EnvelopeBalance`, `Funded`, `Gap`, or generic `BudgetTransfer` as additional canonical truth.

This UI sketch is illustrative only. Observation 128 changes no practical surface.

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

The question is only which information a budget reallocation must preserve for the selected bounded household answers.
