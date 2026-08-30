# Observation 031 — Is Account a Primitive?

## Question

Observation 030 found a bounded generic event core in which familiar event-kind names can be derived from semantic relations.

The next pressure point is spatial rather than nominal:

> If the future asks not only how much exists, but where it is, must `Account` become a primitive household object?

This observation does not assume bank accounts, cash accounts, assets, liabilities, debit/credit sides, categories, envelopes, or commodities.

Instead it introduces only a neutral coordinate called **Locus**.

## Candidate extension

Observation 030 used one scalar event delta.

Observation 031 replaces that scalar with a sparse signed effect indexed by Locus:

```text
Event identity
  + effect : Locus -> Quantity
  + purpose?
  + parents*
```

A positive quantity at a locus increases the current quantity there. A negative quantity decreases it. No explicit `from`, `to`, `transfer`, or `Account` event kind is primitive.

An `AccountName` relation is included only as an intentionally semantically-unused nominal label, so the model can distinguish a coordinate identity from a conventional account name.

## Selected future vocabulary

The bounded vocabulary asks five things:

1. **Total balance** — sum current tip effects across every locus.
2. **Balance by locus** — preserve the current quantity at each distinct locus.
3. **Current commitments** — preserve purposes from current tips.
4. **Explanation** — preserve the tip-to-ancestor revision relation.
5. **Transfer shape** — derive a current event as transfer-like when it has two non-zero locus effects, opposite signs, and total zero.

This deliberately asks more than Observation 030. A single anonymous scalar may still answer total balance, but it cannot automatically answer where that quantity is or whether a zero-total event moved quantity between places.

## Structural tests

### Positive locus witness

Can the neutral coordinate core represent:

- at least two distinct loci with different current balances;
- a transfer-like event without primitive `from`, `to`, or `transfer` fields;
- an event that is simultaneously physically located and purpose-bearing;
- revision ancestry from the generic event core?

Observed: **SAT**.

### Nominal account names

Can two worlds have exactly the same event/locus semantic core, different `AccountName` assignments, and the same selected answers?

Observed: **SAT**.

Conventional account naming adds no observational power to this bounded vocabulary.

### Forgetting locus identity

Can two worlds preserve the same anonymous total quantity for every event while differing in balance by locus?

Observed: **SAT**.

A scalar event total is too coarse once the future may ask where quantity resides.

### Forgetting transfer shape

Can two worlds preserve the same anonymous total for every event, and the same household total balance, while one contains a derived transfer-like current event and the other does not?

Observed: **SAT**.

A zero-total event can therefore still carry household-visible structure when quantity is redistributed between loci.

### Whole coordinate-core sufficiency

If two worlds have the same present events, locus-indexed effects, purposes, and parent relation, can any selected answer differ?

Observed check result: **UNSAT** counterexample.

## Alloy result

Alloy 6.2.0 + Sat4j, exactly 4 Events / 2 Loci / 2 Purposes / 2 AccountNames / 2 Worlds / 5-bit Ints:

```text
locusCoreExpressesHouseholdPlacement          SAT
differentAccountNamesSameCoreSameAnswers     SAT
forgettingLocusCanLoseDistribution            SAT
forgettingLocusCanLoseTransferShape           SAT
CoordinateCoreDeterminesSelectedVocabulary   UNSAT
```

The complete expected result set passed in CI.

One unrelated Observation 018 run initially failed because two TLC invocations created the same timestamp-based state directory in the same second. Its semantic checks before the collision passed, and rerunning that unchanged job succeeded. No Observation 031 code change was needed for it.

## Interpretation

The bounded conclusion is deliberately narrower than "accounts do not exist":

> A conventional `Account` object need not yet be primitive, but distinguishable locus identity becomes necessary as soon as the future vocabulary can ask where quantity resides.

That separates two ideas often fused in bookkeeping software:

```text
Account as domain object
    ≠
Locus as an observable coordinate
```

The first may still be derived or application-facing. The second cannot be forgotten if future questions distinguish locations.

Likewise, a transfer does not require a primitive transfer record shape in this model. It emerges from a signed event effect over multiple loci:

```text
Locus A  -q
Locus B  +q
-------------
Total     0
```

The total says "nothing changed overall" while the coordinate relation says "something moved".

This sharpens the memory boundary from earlier observations:

> Future questions about **how much** need quantity. Future questions about **where** additionally need distinguishable coordinates.

## Important boundaries

This observation does **not** yet establish:

- that `Locus` is globally the right production term;
- that every real account is only a locus;
- that asset/liability/equity distinctions are unnecessary;
- that ownership, institution, access, legal claim, or settlement status can be derived from locus alone;
- that commodity identity can be omitted;
- that signed integer quantity is the final quantity model;
- that every transfer is exactly a two-locus zero-sum event;
- that event effects should be serialized as a sparse matrix;
- that chronology or concurrent append behavior is irrelevant.

The result is bounded to the selected future vocabulary and the finite Alloy scope.

## Tool choice

**Alloy only.**

The question is structural: preserve anonymous totals while varying a relation and ask whether future-visible answers collide.

- J is unnecessary because this is not primarily quotient counting over a fixed table.
- Lean would currently restate the vocabulary-sufficiency law already preserved by Observation 029 rather than add a new law.
- TLA+ is unnecessary because no temporal transition or concurrency property is changing.
- miniKanren is unnecessary because the experiment is not synthesizing arbitrary coordinate schemas backwards from a grammar.

## Next question

If a neutral locus coordinate survives, the next likely pressure comes from quantity identity itself:

> Can one quantity dimension serve every locus, or does a future vocabulary that distinguishes commodities/currencies force another independent coordinate?

That is where `Commodity`, `Unit`, or a still more neutral quantity coordinate may become unavoidable.
