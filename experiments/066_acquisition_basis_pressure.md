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

## Probes

### 1. Can acquisition-time valuation, current valuation, and acquisition basis all differ?

Expected: **SAT**.

This is the representative external-pressure witness.

### 2. Can two worlds share the complete valuation history but differ in acquisition basis?

Expected: **SAT**.

If yes, retaining all valuation observations still does not reconstruct acquisition basis.

### 3. Can current valuation change while acquisition basis and acquisition-time valuation stay fixed?

Expected: **SAT**.

This separates later valuation movement from acquisition provenance.

### 4. Can the same acquisition-time valuation coexist with different acquisition basis?

Expected: **SAT**.

This is the narrow collision that rejects "basis = historical valuation" as a general derivation.

### 5. Can basis differ from acquisition-time valuation inside one world?

Expected: **SAT**.

### 6. Does complete valuation history determine acquisition basis?

Expected check result: **SAT counterexample**.

### 7. Must acquisition basis equal historical valuation at acquisition time?

Expected check result: **SAT counterexample**.

### 8. Does acquisition basis determine current valuation?

Expected check result: **SAT counterexample**.

The independence is two-way for the selected vocabulary.

### 9. If both valuation history and acquisition basis are fixed, are the selected answers fixed?

Expected check result: **UNSAT counterexample**.

## Intended interpretation

If the expected results hold, Observation 066 earns the bounded distinction:

```text
historical valuation relation
        !=
acquisition basis
        !=
current valuation relation
```

This does not mean every acquisition needs a lot object. It means that a future vocabulary asking both "how was this acquired?" and "what is it worth under this valuation?" cannot generally recover the first answer from the second relation, even when the valuation history is complete.

The result would also sharpen the meaning of the practical `Rate` type. `Rate` can remain a neutral exact Measure-to-Measure relation; Observation 066 would be evidence against silently treating one supplied `Rate` as acquisition provenance merely because it was valid at the acquisition coordinate.

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
