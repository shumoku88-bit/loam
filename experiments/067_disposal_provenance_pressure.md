# Observation 067 — Does aggregate holding determine disposal provenance?

## Question

Observation 066 separated acquisition basis from valuation history. Observation 052 had already established a more general identity boundary:

```text
Effect identity
    !=
Locus x Measure coordinate
```

The next external-accounting pressure asks what happens when several acquisition-specific contributions share one Measure and are then aggregated into one holding.

> If the current aggregate holding and disposal quantity are known, can a later question recover which acquisition-specific effects supplied the disposed quantity?

This observation deliberately does **not** begin by importing a conventional `Lot` object.

Instead it asks whether existing acquisition / Effect identity plus an explicit quantity-bearing correspondence is enough for the selected vocabulary.

## External pressure

Accounting systems with lot or cost-basis tracking preserve acquisition-specific origin because a later disposal may need to answer which acquired units were disposed and which acquisition basis applies.

LOAM borrows only that question. It does not import FIFO, LIFO, average cost, tax law, security identifiers, or a conventional lot ontology.

## Minimal bounded shape

The model has exactly two acquisition-specific effects. Each contributes three units of the same otherwise-implicit Measure and carries a distinct acquisition-basis marker:

```text
Acquisition A: quantity 3, basis A
Acquisition B: quantity 3, basis B

aggregate before disposal = 6
```

One disposal removes three units:

```text
Disposal: quantity 3
aggregate after disposal = 3
```

Each world independently records how much of that disposal came from each acquisition identity:

```text
consumesFrom : AcquisitionEffect -> Quantity
```

Examples that all produce the same aggregate result include:

```text
A -> 3, B -> 0
A -> 0, B -> 3
A -> 1, B -> 2
A -> 2, B -> 1
```

The relation is bounded so every consumed amount is non-negative, does not exceed the source acquisition quantity, and the total consumed quantity equals the disposal quantity.

## Selected questions

The observation asks:

1. what is the aggregate holding after disposal?
2. which acquisition identities contributed to the disposal?
3. which acquisition-basis markers are therefore implicated?
4. how many units were consumed from each acquisition identity?

The fourth question is important: even retaining only the set of participating acquisition identities can still lose information when one disposal consumes different quantities from the same source set.

## Probes

### Representative disposal

Can three units be disposed entirely from one acquisition while the aggregate moves from six to three?

Expected: **SAT**.

### Same aggregate, different source identity

Can two worlds have the same aggregate after disposal but different acquisition identities supplying the disposal?

Expected: **SAT**.

### Same aggregate, different basis provenance

Can the same aggregate after disposal implicate different acquisition-basis markers?

Expected: **SAT**.

### One disposal can draw from more than one acquisition

Can one disposal consume positive quantity from both acquisition identities?

Expected: **SAT**.

This is only an external-pressure witness. It does not by itself earn practical many-source disposal support.

### Same source set, different quantity allocation

Can both worlds use the same two acquisition identities while consuming different quantities from each?

Expected: **SAT**.

With a three-unit disposal, for example, `1 + 2` and `2 + 1` preserve the same source set while changing the quantity-bearing provenance.

### Does aggregate holding determine disposal sources?

Expected check result: **SAT counterexample**.

### Does aggregate holding determine basis provenance?

Expected check result: **SAT counterexample**.

### Does the set of source identities determine the quantity allocation?

Expected check result: **SAT counterexample**.

### If the explicit per-acquisition consumption relation is fixed, are selected answers fixed?

Expected check result: **UNSAT counterexample**.

## Intended interpretation

If the expected results hold, the bounded distinction is:

```text
aggregate holding
    !=
disposal source provenance
```

and, for the richer selected vocabulary:

```text
set of source acquisition identities
    !=
quantity consumed from each source
```

This would explain why lot-like bookkeeping pressure appears without yet showing that LOAM needs a new `Lot` identity.

The selected answers can instead be expressed with identities LOAM has already learned to preserve:

```text
Acquisition / Effect identity
        +
explicit quantity-bearing disposal-to-acquisition relation
```

That is a narrower claim than "lots are unnecessary." A future vocabulary might still distinguish a lot from its acquisition Event or Effect, require lot splitting/merging independent of acquisition identity, or impose operational selection rules. Observation 067 does not test those questions.

## Relation to the Practical Core

The practical `Effect` already carries an opaque stable `EffectKey`, specifically so later overlays can refer back to an effect without using list position or `(Locus, Measure)` as identity.

Observation 067 therefore pressure-tests whether that already-earned identity can serve as the endpoint of disposal provenance before inventing another identity layer.

This experiment does **not** modify `Effect`, `Allocation`, `Rate`, Event persistence, or any CLI command.

The existing practical `Allocation` module is not reused automatically. Similar relation shape does not establish identical semantics.

## Important boundaries

Observation 067 does not establish:

- a Practical Core `Lot` type;
- that every acquisition corresponds one-to-one with one practical Effect;
- a production disposal relation;
- FIFO, LIFO, average-cost, or specific-identification policy;
- tax basis selection rules;
- realized or unrealized gain calculation;
- fees or basis adjustments;
- short positions or negative holdings;
- transfers of acquisition provenance between loci;
- stock splits, mergers, spin-offs, or corporate actions;
- correction/conflict semantics for disposal provenance;
- persistence identity for the provenance relation;
- that one disposal must be allowed to consume several acquisitions in the practical system.

## Tool choice

**Alloy only.**

The question is structural: hold acquisition facts and aggregate quantity behavior fixed, vary only the provenance relation, and ask whether selected answers diverge.

J could display the allocation as an array, but would not add a distinct answer to this bounded independence question. Lean should wait until a practical representation or reusable law is earned. TLA+ and SPIN are unnecessary because ordering and interleaving are not yet the pressure point.
