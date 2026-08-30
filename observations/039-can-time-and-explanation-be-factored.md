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

Observation 038 already established the general representation intuition in a larger finite schedule. Observation 039 asks whether this sparse temporal projection can be separated from parentage while retaining the selected vocabulary.

## Structural tests

### 1. Non-trivial factorized witness

The first predicate requires a staggered history in which:

```text
C learned at T1
D learned at T2
R learned at T3
```

and checks that the final explanation through `R` reaches both immediate parents and earlier roots.

Expected: **SAT**.

### 2. Time index alone does not determine explanation

Hold the complete sparse frontier index equal between `Left` and `Right`, but allow the `C/D -> A/B` matching to differ.

When `C` and `D` appear together, both worlds can have exactly the same frontier timeline:

```text
T0 -> {A,B}
T1 -> {C,D}
T3 -> {R}
```

while explanation still distinguishes:

```text
C -> A
```

from:

```text
C -> B
```

Expected `sameSparseIndexDifferentExplanation`: **SAT**.

### 3. Explanation graph alone does not determine time

Hold the parent graph equal while changing when `C` and `D` are learned.

For example one world can learn `C` first and another `D` first. Their graph is identical, but the intermediate frontier differs.

Expected `sameGraphDifferentSparseIndex`: **SAT**.

### 4. Sparse index determines the frontier timeline

Within this bounded world, two worlds with the same sparse change index should have the same exact frontier at every modeled knowledge coordinate.

Expected check `SparseIndexDeterminesFrontier`: **UNSAT counterexample**.

This is not a global proof of change-point encoding. It is a consistency check that the sparse summary used in this experiment really carries the selected temporal projection.

### 5. A timeless backward graph must not leak future knowledge

Although the whole parent graph is retained without per-edge timestamps, explaining a frontier at time `t` must never reach an event that was not yet known at `t`.

Because parent edges point from later interpretations to earlier causes, following ancestors from an as-of frontier should remain inside the known set for that time.

Expected check `TimelessGraphDoesNotLeakFuture`: **UNSAT counterexample**.

This is the key safety condition that makes a timeless stored graph compatible with historical as-of explanation in this bounded model.

### 6. The pair determines the selected vocabulary

Finally, if two worlds have both:

```text
same sparse temporal index
same parent graph
```

then they should agree on:

```text
frontier(w,t)
whyAsOf(w,t)
```

for every modeled knowledge time.

Expected check `FactorizedMemoryDeterminesSelectedVocabulary`: **UNSAT counterexample**.

## Intended interpretation

If all six results hold, the bounded conclusion is:

> Chronology and explanation carry different observable distinctions, but they can compose: a sparse frontier index answers “what was current when?”, while a separate backward parent graph answers “why?”, and the pair is sufficient for the selected historical vocabulary.

The resulting shape is not one monolithic event log:

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
