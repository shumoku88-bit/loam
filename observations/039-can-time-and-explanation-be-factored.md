# Observation 039 — Can Time and Explanation Be Factored?

## Question

Observation 038 showed that exact frontier-at-every-knowledge-time answers do not require a dense time table. A sparse change-point representation can preserve every selected as-of frontier answer.

Earlier observations showed a different pressure:

- current state does not recover provenance;
- correction provenance can remain append-only;
- explanation may require relationship shape rather than merely the set of participating events.

That leaves a new structural question:

> Can historical meaning be factored into a sparse temporal index for “when/what was current?” and a separate timeless parent graph for “why was it current?”

The candidate memory is:

```text
sparse temporal index
KnowledgeTime -> Frontier

plus

explanation graph
Event -> parent Event
```

The graph is called “timeless” only in the narrow storage sense that parent edges are not duplicated once per knowledge-time slot. The world still constrains parents to be earlier causes of the frontier nodes that expose them.

## Why Alloy only

Observation 038 already used J to establish the bounded change-point round trip. Repeating that counting experiment would add no new result.

The present question is relational:

- can two worlds have the same sparse time index but different explanation graphs and therefore different historical explanations?
- can two worlds have the same graph but different sparse time indexes and therefore different as-of frontiers?
- does the pair determine both selected answers?

Alloy directly searches those collisions.

No new transition policy is introduced, so TLA+ is unnecessary. No general theorem is yet claimed, so Lean is premature. miniKanren adds no distinct synthesis result here.

## Bounded raw world

There are four knowledge coordinates:

```text
T0 < T1 < T2 < T3
```

and five event identities:

```text
A B C D R
```

Every world follows this bounded shape:

```text
T0:
  A   B

later:
  C -> one of {A,B}
  D -> the other of {A,B}

T3:
  R -> {C,D}
```

`C` and `D` may each be learned at `T1` or `T2`. `R` is learned at `T3`.

The matching between `C,D` and `A,B` is not fixed globally. One world may have:

```text
C -> A
D -> B
```

while another has:

```text
C -> B
D -> A
```

This gives the model room to vary chronology independently from explanation shape.

## Derived raw projections

At each knowledge time the model derives the known events and then the current frontier:

```text
known(w,t)
frontier(w,t)
```

A known event is superseded when another known event names it as a parent.

Historical explanation is the strict ancestor relation reachable from the current frontier:

```text
whyAsOf(w,t)
  = frontier(w,t) <: ^parent
```

So explanation preserves relationship shape rather than collapsing to a set of events.

## Sparse temporal index

The candidate time memory stores a frontier only when that frontier differs from the previous knowledge coordinate.

Conceptually:

```text
(knowledge time, new frontier)
```

The Alloy relation is:

```text
sparseIndex(w) : Time -> Event
```

Observation 038 already established the representation intuition in a larger finite schedule. Observation 039 asks whether this sparse temporal projection can be separated from parentage while retaining the selected vocabulary.

## Observed Alloy result

Alloy 6.2.0 with Sat4j returned:

```text
factorizedMemoryCarriesHistoricalMeaning       SAT
sameSparseIndexDifferentExplanation            SAT
sameGraphDifferentSparseIndex                  SAT
SparseIndexDeterminesFrontier                  UNSAT
TimelessGraphDoesNotLeakFuture                 UNSAT
FactorizedMemoryDeterminesSelectedVocabulary   UNSAT
```

Both lower-bound witnesses expose their first differing selected answer at `T1`.

## What the witnesses show

### Sparse time alone loses explanation

`sameSparseIndexDifferentExplanation` is SAT.

Two worlds can retain exactly the same sparse frontier timeline while assigning the sibling revisions to different roots:

```text
world L                world R
C -> A                 C -> B
D -> B                 D -> A
```

If `C` and `D` appear together, the frontier timeline is unchanged by that swap, but `whyAsOf` distinguishes the worlds at `T1`.

So the temporal index answers **what was current when**, but not **why those named events were current**.

### Explanation graph alone loses chronology

`sameGraphDifferentSparseIndex` is SAT.

Two worlds can keep exactly the same parent graph while learning `C` and `D` on different schedules. Alloy finds an intermediate distinction at `T1`.

So the graph answers ancestry but does not determine which frontier was visible at each knowledge time.

### Sparse change points recover the selected frontier timeline

`SparseIndexDeterminesFrontier` has no counterexample in this scope.

Thus the sparse temporal relation used here is sufficient for the modeled exact frontier-at-time vocabulary. This is a bounded consistency result, not a replacement for Observation 038's larger finite representation experiment.

### The timeless graph does not leak future events backward

`TimelessGraphDoesNotLeakFuture` has no counterexample.

Even though the full parent graph is retained once, without copying edges into every time slot, traversing ancestors from an as-of frontier reaches only events already known at that time.

The reason is directional: parent edges point backward from later interpretations to earlier causes. Future descendants are present elsewhere in the stored graph, but an ancestor traversal cannot reach them.

This is the safety condition that lets one stored explanation graph serve multiple historical views in this bounded world.

### The pair determines the selected historical vocabulary

`FactorizedMemoryDeterminesSelectedVocabulary` has no counterexample.

Within the scope, equality of both:

```text
sparse temporal index
parent graph
```

forces equality of every modeled:

```text
frontier(w,t)
whyAsOf(w,t)
```

answer.

## Finding

The bounded result supports a factorized memory:

```text
                 sparse time index
history meaning --------------------> as-of frontier
        |
        |
        +------ parent graph -------> as-of explanation
```

The explanation query composes the two:

```text
WhyAsOf(t)
  = ancestors(FrontierAsOf(t))
```

Chronology and explanation are therefore neither interchangeable nor necessarily one monolithic stored history.

A useful sharpened form is:

> The time index locates a historical view; the explanation graph gives that view depth.

The two structures carry different observable distinctions, while their composition is sufficient for the selected bounded vocabulary.

## Important boundaries

This observation does **not** establish that:

- a production system should discard its raw event records;
- parent edges never need their own provenance, authorship, or validity metadata;
- arbitrary parent graphs are safe without the backward-causality condition;
- the sparse index and graph are globally minimal representations;
- quantity, purpose, locus, measure, or valuation memories can all be factored in exactly the same way;
- concurrent graph publication or distributed ordering is solved;
- a graph edge can be corrected without additional history.

The bounded graph is intentionally small and every parent points backward to an already-known cause.

## Tool choice

**Alloy only.**
