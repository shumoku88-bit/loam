# Observation 032 — Does Quantity Need Another Coordinate?

## Question

Observation 031 found that a single anonymous quantity is too coarse once the future asks **where** quantity resides. A neutral `Locus` coordinate became observable before a conventional `Account` noun did.

The next pressure point is the quantity itself:

> Can one undifferentiated quantity serve every locus, or does a future vocabulary that distinguishes kinds of quantity force another independent coordinate?

This observation does not begin with currency, commodity, security, inventory item, or unit-of-measure classes.

Instead it introduces only a neutral coordinate called **Measure**.

## Candidate extension

Observation 031 used:

```text
Event identity
  + effect : Locus -> Quantity
  + purpose?
  + parents*
```

Observation 032 asks whether the effect must sometimes retain one more axis:

```text
Event identity
  + effect : Locus -> Measure -> Quantity
  + purpose?
  + parents*
```

`MeasureName` is included only as an intentionally semantically-unused nominal label. It lets the model separate distinguishable measure identity from familiar names that an application might later attach to that identity.

## Selected future vocabulary

The bounded vocabulary asks five things:

1. **Balance by locus and measure** — preserve the current quantity at each `(Locus, Measure)` coordinate.
2. **Total by measure** — preserve each measure independently across loci.
3. **Current commitments** — preserve purposes from current tips.
4. **Explanation** — preserve the tip-to-ancestor revision relation.
5. **Conversion-like shape** — derive a current event when exactly two measures participate and one has a negative net delta while another has a positive net delta.

The fifth question is deliberately structural. It does not assert an exchange rate, conservation law, market price, or economic interpretation. It only asks whether a cross-measure decrease/increase pattern is observable without storing a primitive `conversion` event kind.

## The coarse alternative

To model the hypothesis that quantity is really one-dimensional, define a deliberately collapsed projection:

```text
collapsedAmount(event, locus)
  = sum over every Measure
```

This projection forgets which measure contributed each amount while retaining the signed scalar at every event/locus pair.

The question is then observational:

> Can two histories have the same collapsed event/locus quantities yet answer the selected future vocabulary differently?

If yes, the single scalar projection is insufficient for that vocabulary.

## Structural tests

### Positive measure witness

Can the neutral measure core express, in one bounded world:

- two distinct measures at the same locus with different current balances;
- a conversion-like current event without a primitive conversion field;
- an event that also carries a purpose;
- revision ancestry from the generic event core?

Target result: **SAT**.

### Nominal measure names

Can two worlds have exactly the same event/locus/measure semantic core, different `MeasureName` assignments, and the same selected answers?

Target result: **SAT**.

If so, names add no observational power once neutral measure identity is already retained.

### Forgetting measure distribution

Can two worlds preserve exactly the same collapsed scalar amount for every event/locus pair while differing in current `(Locus, Measure)` balances?

Target result: **SAT**.

### Forgetting cross-measure shape

Can two worlds preserve the same collapsed scalar amount for every event/locus pair while one has a conversion-like current event and the other does not?

Target result: **SAT**.

This is the important zero-looking case: a coarse scalar can erase a change that remains visible once quantity kinds are distinguished.

### Whole measure-core sufficiency

If two worlds have the same present events, measure-indexed locus effects, purposes, and parent relation, can any selected answer differ?

Target check result: **UNSAT** counterexample.

## Intended interpretation

If the target result set holds, the bounded conclusion is narrower than “commodity is primitive”:

> A conventional `Commodity` or `Currency` object need not yet be primitive, but distinguishable measure identity becomes necessary as soon as future questions distinguish kinds of quantity.

That would separate another pair of ideas that bookkeeping systems often fuse:

```text
Commodity as domain noun
    ≠
Measure as observable coordinate
```

Combined with Observation 031, the candidate effect geometry would become:

```text
Event
  -> Locus
  -> Measure
  -> signed Quantity
```

without yet committing to `Account`, `Currency`, `Commodity`, `Transfer`, or `Conversion` as primitive event/state kinds.

## Important boundaries

This observation does **not** establish:

- that `Measure` is the right production term;
- that JPY, USD, shares, kilograms, and other quantities all obey one common operational algebra;
- that quantities from different measures may meaningfully be added outside the deliberately coarse comparison projection;
- that exchange rates, prices, valuations, or dimensional conversions can be derived from measure identity alone;
- that every cross-measure decrease/increase is economically a conversion;
- that a measure coordinate is sufficient for ownership, valuation, settlement, or legal-claim questions;
- that signed integers are the final quantity representation;
- that locus and measure are the only coordinates future vocabulary may require;
- that chronology or concurrency is irrelevant.

The result is bounded to the selected future vocabulary and finite Alloy scope.

## Tool choice

**Alloy only.**

This is another structural collision question: hold a coarse projection fixed, vary the forgotten relation, and ask whether future-visible answers can diverge.

- J is unnecessary because the main task is not complete quotient counting over a fixed finite table.
- Lean is unnecessary because Observation 029 already preserves the general sufficiency/factorization law; this experiment asks which concrete coordinate the household vocabulary forces.
- TLA+ is unnecessary because no temporal transition or concurrency property is changing.
- miniKanren is unnecessary because no backwards schema synthesis is being requested.

## Next question

If both `Locus` and `Measure` survive as observable coordinates, the next pressure point is likely not another familiar bookkeeping noun but **relation between quantities**:

> When the future asks for value, exchange, or equivalence across measures, must a rate/valuation relation become primitive, or can it remain an external observation layered over the event core?

That question should wait until Observation 032 first establishes whether the measure coordinate itself survives.
