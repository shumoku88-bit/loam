# Observation 066 — Does historical valuation determine acquisition basis?

## Question

Observation 033 established that valuation-like Measure-to-Measure relations can vary independently from the physical Event core. Observation 034 then established that one current relation cannot answer past, present, and future viewpoints without relation history.

That still leaves a different distinction untested:

> If the complete historical valuation relation at an acquisition time is retained, does it determine the acquisition basis of what was acquired?

This question is motivated by accounting systems that distinguish acquisition-specific cost information from later valuation:

- hledger's lot specification distinguishes transacted cost from cost basis, and preserves a lot's acquisition cost and date through its lifetime: https://hledger.org/SPEC-lots.html
- GnuCash investment reports distinguish basis from end value, where end value uses a selected end-date price: https://www.gnucash.org/docs/v5/C/gnucash-guide.pdf

LOAM does not import either system's ontology. Their behavior is used only as external pressure showing that "what was paid / carried as basis" and "what a valuation relation says" can answer different questions.

## Why Alloy

Observation 034 already used TLA+ for the genuinely temporal question of changing relation observations.

Observation 066 is narrower and structural. It holds time coordinates and valuation history fixed, then varies only acquisition basis and asks whether any selected answer changes.

The candidate compression is:

```text
Acquisition Event
+ complete valuation history

        derive

acquisition basis = valuation at acquisition time
```

If two worlds can share the acquisition record and complete valuation history but differ in acquisition basis, that compression loses observable information.

No transition ordering is needed, so repeating TLA+ would add no distinct answer. J has no separate array-loss question yet, and Lean should wait unless a reusable practical law is earned.

## Minimal vocabulary

The bounded model uses two time coordinates:

```text
AcquisitionTime
CurrentTime
```

and one acquisition identity.

Each world carries two independent relations:

```text
valuationAt : Time -> ComparisonValue

acquisitionBasis : Acquisition -> ComparisonValue
```

`ComparisonValue` is deliberately neutral. It does not claim that market price, exchange rate, transaction price, tax basis, or accounting basis are interchangeable production types.

The question is only whether two selected answers must collapse to one.

## Observed Alloy result

Alloy 6.2.0 + Sat4j returned:

```text
representativeAcquisitionPressure                 SAT
sameValuationHistoryDifferentBasis                SAT
currentValuationCanMoveWithoutRewritingBasis      SAT
sameAcquisitionTimeValuationDifferentBasis        SAT
basisCanDifferFromAcquisitionTimeValuation        SAT
ValuationHistoryDeterminesAcquisitionBasis        SAT counterexample
AcquisitionBasisEqualsHistoricalValuation         SAT counterexample
AcquisitionBasisDeterminesCurrentValuation        SAT counterexample
ExplicitBasisAndValuationDetermineSelectedAnswers UNSAT counterexample
```

The complete expected result set passed in CI.

## What the witnesses show

### Acquisition-time valuation, basis, and current valuation can all differ

`representativeAcquisitionPressure` is SAT.

The bounded world can assign three distinct selected answers to:

```text
valuation at AcquisitionTime
acquisition basis
valuation at CurrentTime
```

So neither temporal position nor shared comparison vocabulary forces these meanings to collapse.

### Complete valuation history still does not reconstruct basis

`sameValuationHistoryDifferentBasis` is SAT, and `ValuationHistoryDeterminesAcquisitionBasis` has a counterexample.

Two worlds can share the complete `Time -> ComparisonValue` valuation relation while differing only in the acquisition-basis answer for the same acquisition identity.

Thus even perfect retention of the modeled valuation history does not determine acquisition basis in this vocabulary.

### Historical valuation at the acquisition coordinate is not enough

`sameAcquisitionTimeValuationDifferentBasis` and `basisCanDifferFromAcquisitionTimeValuation` are SAT. The assertion `AcquisitionBasisEqualsHistoricalValuation` also has a counterexample.

This is the distinction Observation 034 did not test:

```text
past valuation
    !=
acquisition provenance
```

Both may refer to the same time coordinate and still answer different questions.

### Current valuation can move without rewriting basis

`currentValuationCanMoveWithoutRewritingBasis` is SAT, while `AcquisitionBasisDeterminesCurrentValuation` has a counterexample.

The same acquisition basis and the same acquisition-time valuation can coexist with different current valuations.

So the independence is observable in both directions for the selected vocabulary.

### Retaining both relations is sufficient for the selected answers

`ExplicitBasisAndValuationDetermineSelectedAnswers` has no counterexample in the bounded scope.

Once both the valuation relation and acquisition-basis relation are fixed, every selected historical, basis, and current answer is fixed.

## Finding

Observation 066 earns the bounded separation:

```text
historical valuation relation
        !=
acquisition basis
        !=
current valuation relation
```

This does not mean every acquisition needs a lot object. It means that a future vocabulary asking both "how was this acquired?" and "what is it worth under this valuation?" cannot generally recover the first answer from the second relation, even when the valuation history is complete.

The result also sharpens the meaning of the practical `Rate` type. `Rate` can remain a neutral exact Measure-to-Measure relation; Observation 066 is evidence against silently treating one supplied `Rate` as acquisition provenance merely because it was valid at the acquisition coordinate.

## Important boundaries

Observation 066 does **not** establish:

- a Practical Core `CostBasis` or `Lot` type;
- tax basis rules;
- fee capitalization rules;
- whether basis is per-unit or total;
- FIFO, LIFO, average-cost, or specific-identification selection;
- disposal semantics;
- realized or unrealized gain calculation;
- that basis always differs from acquisition-time valuation;
- identity or persistence for basis observations;
- correction or conflict semantics for basis;
- authority, source, confidence, or validity metadata for valuation relations;
- multi-acquisition aggregation.

Those require separate pressure.
