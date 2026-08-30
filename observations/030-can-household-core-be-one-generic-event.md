# Observation 030 — Can the Household Core Be One Generic Event?

## Question

Do household concepts such as `Actual`, `Commit`, `Release`, `Correction`, and `Resolution` need to be primitive stored event kinds?

Or can a smaller event shape carry the distinctions needed by the current future vocabulary, while those familiar names become derived roles?

This observation deliberately does not start from Account, Category, Envelope, or a final household schema.

## Starting point

Observations 018–029 have separated several kinds of identity and memory pressure:

- resource identity can disappear when the future cannot name individual resource units;
- event identity can remain necessary for targeted reversal and explanation;
- append-only parentage can preserve correction and resolution history;
- provenance can be compressed only relative to the future distinctions that remain observable;
- richer future vocabulary preserves or refines the required memory quotient, but need not refine it when a new question is derivable from existing retained information.

That makes a new question possible:

> Are the *names of household event kinds* part of the irreducible memory, or are the underlying semantic relations enough?

## Candidate generic event

The bounded Alloy model gives every event only these semantic facets:

```text
Event identity
  + delta       : quantitative effect
  + purpose     : optional intentional destination
  + parent      : zero or more earlier events this event continues/revises/settles
```

A nominal `tag` field is also present, but the selected future vocabulary never reads it. It exists only so the model can ask whether different stored labels can coexist with exactly the same semantic core and answers.

Every present event has one integer delta; zero means no quantitative effect for this experiment. Purpose is optional. Parentage is acyclic.

## Derived roles

No primitive `Actual`, `Commit`, `Release`, `Correction`, or `Resolution` signature is introduced.

Instead the model derives role-like views:

- **physical-like**: non-zero delta;
- **intentional-like**: has a purpose;
- **revision-like**: has at least one parent;
- **withdrawal-like**: has a parent, zero delta, and no purpose;
- **resolution-like**: has more than one parent.

An event may satisfy more than one role. The experiment does not assume these roles must form a disjoint sum type.

## Selected future vocabulary

The generic history must answer three concrete projections and support the revision shapes above:

1. **Balance** — sum the deltas of current tips.
2. **Current commitments** — read purposes from current tips.
3. **Explanation** — observe the ancestry relation from current tips to the events they descend from.

A tip is a present event that has not been named as a parent by another present event.

This is intentionally small. It does not yet claim to cover every future household question.

## Structural tests

The Alloy experiment asks for seven results.

### Positive core witness

Can one generic event relation contain physical-like, intentional-like, revision-like, withdrawal-like, and resolution-like events while producing non-trivial Balance, Commitment, and Explanation projections?

Expected: **SAT**.

### Nominal kinds

Can two worlds have the exact same generic semantic core but different nominal tags and still answer every selected question identically?

Expected: **SAT**.

If so, stored event-kind labels add no observational power for this vocabulary.

### Lower-bound collisions

For each semantic facet, can two worlds agree on the other retained information while the selected future vocabulary distinguishes them?

- forget `delta` → Balance can differ;
- forget `purpose` → Current commitments can differ;
- forget `parent` → current Balance or Commitment can differ because revision changes which events are tips;
- forget `parent` while keeping Balance and Commitment equal → Explanation can still differ.

Each is expected **SAT**.

### Whole-core sufficiency

If two worlds have exactly the same present events, deltas, purposes, and parent relation, can any selected answer differ?

Expected check result: **UNSAT** counterexample.

## Observed results

With exactly 4 Events, 2 Purposes, 2 Worlds, and 4-bit Ints, Alloy 6.2.0 + Sat4j returned:

```text
genericCoreExpressesHouseholdRoles          SAT
differentNominalKindsSameCoreSameAnswers   SAT
forgettingDeltaCanLoseBalance               SAT
forgettingPurposeCanLoseCommitment          SAT
forgettingParentCanLoseCurrentMeaning       SAT
forgettingParentCanLoseExplanationOnly      SAT
GenericCoreDeterminesSelectedVocabulary     UNSAT
```

The bounded witnesses therefore support all six positive searches, while Alloy finds no counterexample to whole-core sufficiency in this scope.

### A useful failed formulation

The first version represented Explanation only as the **set of events** reachable from current tips. Alloy returned UNSAT for `forgettingParentCanLoseExplanationOnly`.

That was not evidence that parentage was unnecessary for explanation. In a finite acyclic parent graph, every present event eventually lies below some tip, so the reachable-event set collapses to the whole present set. The projection had accidentally erased the shape it was meant to observe.

After Explanation was changed to the **tip-to-ancestor relation**, Alloy found the expected SAT witness while Balance and Current commitments remained equal.

This sharpens the household requirement:

> Explanation is not merely remembering which events participated. It may require remembering how those events are related.

## Finding

For the selected future vocabulary, the experiment does not need primitive stored event-kind names.

A bounded candidate core is:

```text
Event identity
+ delta
+ optional purpose
+ parent relation
```

The familiar household words can be derived as roles over that structure. In contrast, each of `delta`, `purpose`, and `parent` carries a future-visible distinction that can be lost when that facet is forgotten.

The nominal `tag` field can vary while the semantic core and all selected answers remain identical, so it adds no observational power here.

## What the result means

This does not establish a final household database schema.

It establishes a smaller bounded claim:

> For this future vocabulary, named event kinds are not required as primitive memory. Event identity plus quantitative effect, intentional purpose, and revision parentage can carry the selected distinctions, while household event names can be derived roles.

This makes a possible core look less like:

```text
Actual | Commit | Release | Correction | Resolution
```

and more like:

```text
Event {
  delta
  purpose?
  parents*
}
```

with role names appearing at projection/API boundaries rather than necessarily in the primary representation.

## Important boundaries

This observation does **not** yet prove:

- that integer delta alone is the right quantity model;
- that Account or commodity dimensions are unnecessary;
- that every household correction can be expressed by tip replacement;
- that chronology/order is unnecessary;
- that concurrent append behavior is safe;
- that event identity can be removed;
- that the three semantic facets are globally minimal for every future vocabulary;
- that a production system should serialize events in this exact shape.

Event identity is intentionally retained. Its explanation value was already exposed by Observations 018 and 019; this experiment does not repeat that lower-bound argument.

## Tool choice

**Alloy only.**

The question is structural: remove or vary one relation and ask for a counterexample in which future-visible projections change. Alloy directly supplies those bounded witnesses.

- J is unnecessary because the object of interest is not a finite quotient table.
- Lean is premature until a reusable law emerges from this event shape.
- TLA+ is unnecessary because no append transition system is being changed here.
- miniKanren is unnecessary because the experiment is not yet synthesizing arbitrary event schemas backwards from a grammar.

## Next question

The next pressure point is quantitative and structural rather than nominal:

> What additional relation, if any, becomes unavoidable when Balance must be split across multiple loci/commodities and commitments must coexist with physical movement without conflating the two?

That is where `Account`, `Commodity`, or some more neutral coordinate may either reappear as necessary structure or dissolve into another projection.
