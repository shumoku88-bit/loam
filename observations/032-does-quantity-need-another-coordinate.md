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

For Alloy representation only, each `(Locus, Measure)` pair is reified as a unique neutral `Cell`. This reduces the world-indexed effect relation from arity five to arity four without changing the modeled coordinate geometry:

```text
Cell = Locus × Measure
World.effect : Event -> Cell -> Quantity
```

`Cell` is therefore not proposed as an additional household-domain primitive.

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

This sum is **not** proposed as meaningful arithmetic between heterogeneous measures. It exists only as the hypothesis under test: what becomes observationally indistinguishable if the Measure coordinate is forgotten and only one signed scalar per event/locus is retained?

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

Observed: **SAT**.

### Nominal measure names

Can two worlds have exactly the same event/locus/measure semantic core, different `MeasureName` assignments, and the same selected answers?

Observed: **SAT**.

Names add no observational power once neutral measure identity is already retained.

### Forgetting measure distribution

Can two worlds preserve exactly the same collapsed scalar amount for every event/locus pair while differing in current `(Locus, Measure)` balances?

Observed: **SAT**.

A single event/locus scalar can therefore merge histories that the selected future vocabulary distinguishes by measure.

### Forgetting cross-measure shape

Can two worlds preserve the same collapsed scalar amount for every event/locus pair while one has a conversion-like current event and the other does not?

Observed: **SAT**.

A coarse scalar can erase a change that remains visible once quantity kinds are distinguished.

### Whole measure-core sufficiency

If two worlds have the same present events, measure-indexed locus effects, purposes, and parent relation, can any selected answer differ?

Observed check result: **UNSAT** counterexample.

## Alloy result

Alloy 6.2.0 + Sat4j, exactly 4 Events / 2 Loci / 2 Measures / 4 coordinate Cells / 2 MeasureNames / 2 Purposes / 2 Worlds / 6-bit Ints:

```text
measureCoreExpressesDistinctQuantityAxes       SAT
differentMeasureNamesSameCoreSameAnswers      SAT
forgettingMeasureCanLoseDistribution           SAT
forgettingMeasureCanLoseConversionShape        SAT
MeasureCoreDeterminesSelectedVocabulary        UNSAT
```

The complete expected result set passed in CI.

Two representation fixes preceded the semantic run. First, a nested Alloy sum needed explicit parentheses. Second, the direct world-indexed `Event -> Locus -> Measure -> Int` field became an arity-five relation and exceeded Alloy/Kodkod translation capacity at this scope. Reifying the unique `(Locus, Measure)` product as `Cell` reduced only the representation arity; the selected vocabulary and hypothesis were unchanged.

## Interpretation

The bounded conclusion is narrower than “commodity is primitive”:

> A conventional `Commodity` or `Currency` object need not yet be primitive, but distinguishable measure identity becomes necessary as soon as future questions distinguish kinds of quantity.

That separates another pair of ideas that bookkeeping systems often fuse:

```text
Commodity as domain noun
    ≠
Measure as observable coordinate
```

Combined with Observation 031, the candidate effect geometry becomes:

```text
Event
  -> Locus
  -> Measure
  -> signed Quantity
```

without yet committing to `Account`, `Currency`, `Commodity`, `Transfer`, or `Conversion` as primitive event/state kinds.

Observation 031 said that asking **where** forces a location coordinate. Observation 032 adds the parallel result:

> Asking **what kind of quantity** can force a second independent coordinate.

The generic event core is therefore not merely accumulating familiar bookkeeping nouns. It is gaining only those distinctions that the future vocabulary proves observable.

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

With both `Locus` and `Measure` surviving as observable coordinates, the next pressure point is likely not another familiar bookkeeping noun but **relation between quantities**:

> When the future asks for value, exchange, or equivalence across measures, must a rate/valuation relation become primitive, or can it remain an external observation layered over the event core?

That question should be asked separately rather than smuggling valuation semantics into the Measure coordinate itself.
