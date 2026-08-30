# Observation 048 — Can Backing Eligibility Remain an Overlay?

## Question

Observation 031 separated a conventional `Account` object from a neutral `Locus` coordinate. Observation 032 added a neutral `Measure` coordinate, and later observations separated other semantics such as valuation and selection policy into overlays.

A remaining household question is:

> Does physical possession itself determine which held quantity may participate in household allocation, or can eligibility for allocation vary over the same physical history?

This observation does not introduce `Budget`, `Envelope`, `BackingPool`, `Asset`, or an account type primitive.

It introduces only one neutral overlay:

```text
eligible : set Locus
```

## Why Alloy

The missing question is static relational independence:

1. hold event / locus / measure history fixed;
2. vary only eligibility;
3. ask whether physical holdings stay the same while allocatable quantity changes.

No transition semantics are required yet, so TLA+ would add machinery without answering a different question. J is unnecessary because this is not quotient counting, and Lean is premature unless a reusable general law emerges.

## Neutral model

The physical core is deliberately small:

```text
Event identity
  + effect : Locus × Measure -> signed Quantity
  + parent*
```

Current physical balances are derived from current tips, as in earlier neutral coordinate observations.

Eligibility is not part of the event core:

```text
World.eligible : set Locus
```

For each Measure:

```text
totalByMeasure
  = quantity at every Locus

allocatableByMeasure
  = quantity only at eligible Loci
```

The model never sums different Measures together.

## Pressure

Use two worlds with exactly the same physical core.

Ask:

1. Can different eligibility overlays preserve every physical balance and total while changing allocatable quantity?
2. Can a positive held quantity remain outside the allocatable set?
3. Does the physical core alone determine physical answers?
4. Does the physical core alone determine allocatable quantity?
5. Does physical core plus the same eligibility overlay determine the selected vocabulary?

## Observed result

Alloy 6.2.0 + Sat4j, exactly 2 Events / 2 Loci / 1 Measure / 2 coordinate Cells / 2 Worlds / 5-bit Ints:

```text
eligibilityOverlayCanChangeOnlyAllocatable               SAT
heldQuantityCanRemainIneligible                         SAT
PhysicalCoreDeterminesPhysicalAnswers                   UNSAT
PhysicalCoreDeterminesAllocatableQuantity               SAT
PhysicalCorePlusEligibilityDeterminesSelectedVocabulary UNSAT
```

The final solver run emitted no Alloy warnings and the complete expected result set passed in CI.

The first execution attempt stopped before solving because the original conditional expression was placed directly inside an Alloy `sum` comprehension in a syntactically ambiguous form. The sum was rewritten through explicit contribution functions. That changed only expression plumbing, not the semantic question or expected result set.

## Interpretation

The first witness keeps `present`, `effect`, and `parent` identical across two worlds. Coordinate balances and total quantity therefore remain identical. Varying only `eligible` nevertheless changes `allocatableByMeasure`.

So, for this vocabulary:

```text
what is held
    ≠
what may participate in allocation
```

The second witness is the same distinction inside one world: positive quantity can exist at a Locus that is not eligible, so possession alone does not imply allocation eligibility.

`PhysicalCoreDeterminesPhysicalAnswers` has no bounded counterexample, while `PhysicalCoreDeterminesAllocatableQuantity` does. The eligibility overlay therefore adds no physical quantity but carries an additional future-visible distinction.

Finally, physical core plus the same eligibility overlay determines all selected answers in this bounded model.

A candidate decomposition is therefore:

```text
physical holding
  = Event × Locus × Measure × Quantity history

allocation view
  = physical holding + Eligibility
```

This does not yet say what makes a Locus eligible. It says only that the answer is not forced by physical possession in the selected vocabulary.

## Boundary

This observation is intentionally narrower than HRA's current Backing model or a production budgeting system.

It does **not** establish:

- that eligibility should be attached specifically to Locus in production;
- that an eligible Locus contributes every positive quantity without further constraints;
- that Backing pools, commitments, reservations, liquidity, ownership, access, or legal restrictions can be omitted;
- that negative balances or liabilities have allocation semantics;
- that current eligibility is sufficient for historical as-of questions;
- that eligibility is immutable or needs no provenance;
- that an `Envelope` is primitive;
- that `Asset` account classification is unnecessary.

The selected vocabulary asks only whether held quantity and allocation eligibility are distinct semantic information.

## Tool choice

**Alloy only.**

If eligibility later changes through time and the future asks what was allocatable as-of an earlier knowledge or valid time, that would create a separate transition/time question for TLA+.
