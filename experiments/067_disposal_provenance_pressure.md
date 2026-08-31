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

## Observed Alloy result

Alloy 6.2.0 + Sat4j, exactly 2 AcquisitionEffects / 2 BasisValues / 2 Worlds / 4-bit Ints:

```text
representativeDisposalPressure                     SAT
sameAggregateDifferentSource                       SAT
sameAggregateDifferentBasisProvenance              SAT
splitDisposalCanConsumeMultipleAcquisitions        SAT
sameSourcesDifferentAllocation                     SAT
AggregateHoldingDeterminesDisposalSources          SAT counterexample
AggregateHoldingDeterminesBasisProvenance          SAT counterexample
SourceSetDeterminesConsumptionAllocation           SAT counterexample
ExplicitConsumptionDeterminesSelectedAnswers       UNSAT counterexample
```

The complete expected result set passed in CI after one syntax-only fix that parenthesized an Alloy `sum` expression. That fix changed no semantic hypothesis.

### Representative disposal

A witness disposes all three units from one acquisition, moving the aggregate from six to three.

Observed: **SAT**.

### Same aggregate, different source identity

The bounded counterexample uses the same before/after aggregate while one world consumes `3 + 0` and the other consumes `0 + 3` from the two acquisition identities.

Observed: **SAT**.

### Same aggregate, different basis provenance

Because the two acquisitions carry distinct basis markers, the same aggregate after disposal can implicate different basis provenance.

Observed: **SAT**.

### One disposal can draw from more than one acquisition

A witness consumes positive quantity from both acquisition identities.

Observed: **SAT**.

This is an external-pressure witness, not a practical implementation requirement.

### Same source set, different quantity allocation

Alloy found the sharper collision:

```text
Left : A -> 2, B -> 1
Right: A -> 1, B -> 2
```

Both worlds retain the same source set `{A, B}`, the same disposal quantity, and the same aggregate result, while the quantity-bearing provenance differs.

Observed: **SAT**.

### Aggregate holding determines disposal sources?

Observed check result: **SAT counterexample**.

### Aggregate holding determines basis provenance?

Observed check result: **SAT counterexample**.

### Source identity set determines quantity allocation?

Observed check result: **SAT counterexample**.

### Explicit per-acquisition consumption determines selected answers?

Observed check result: **UNSAT counterexample**.

Within the bounded selected vocabulary, fixing the quantity-bearing correspondence fixes the aggregate-after, source-set, and implicated-basis answers.

## Interpretation

The bounded distinctions are:

```text
aggregate holding
    !=
disposal source provenance
```

and, once the vocabulary asks how much came from each origin:

```text
set of source acquisition identities
    !=
quantity consumed from each source
```

So lot-like bookkeeping pressure appears in two stages.

First, aggregation destroys acquisition identity provenance. Second, preserving only the identities that participated can still be too weak: the quantity assigned to each source is separately observable.

But the experiment does **not** force another stored identity named `Lot`.

The selected answers are already expressible using identities LOAM has learned to preserve:

```text
Acquisition / Effect identity
        +
explicit quantity-bearing disposal-to-acquisition relation
```

This is important because Observation 052 already earned stable Effect identity before coordinate collapse, and the current Practical Core already has `EffectKey` so later relations can refer to one Effect without using position or `(Locus, Measure)` as identity.

The bounded result therefore says:

> Before inventing a Lot object, preserve acquisition-specific Effect identity and the explicit quantity-bearing provenance relation that future disposal questions can observe.

That is still much narrower than "lots are unnecessary." A future vocabulary might distinguish a lot from its acquisition Event or Effect, require lot splitting/merging independent of acquisition identity, or impose operational selection rules.

## Relation to the Practical Core

The practical `Effect` already carries an opaque stable `EffectKey`, specifically so later overlays can refer back to an effect without using list position or `(Locus, Measure)` as identity.

Observation 067 therefore pressure-tests whether that already-earned identity can serve as the endpoint of disposal provenance before inventing another identity layer.

This experiment does **not** modify `Effect`, `Allocation`, `Rate`, Event persistence, or any CLI command.

The existing practical `Allocation` module is not reused automatically. Similar relation shape does not establish identical semantics.

No Practical Core change is earned yet because LOAM does not yet have a practical acquisition/basis/disposal workflow that needs this correspondence.

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

## Next pressure point

Observation 067 stops before any selection policy.

The next external question can ask whether rules such as FIFO or specific identification are facts about the acquisition/disposal history, or independent policy overlays that select one admissible provenance relation among several.

That would be a different distinction:

```text
possible disposal provenance
    !=
policy for choosing one provenance
```
