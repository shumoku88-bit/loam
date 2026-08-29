# Observation 010 — When Does a Purpose Become Envelope-Like?

## Question

When does a bare `Purpose` begin to behave like something we would later call an envelope?

The experiment does not introduce an `Envelope` primitive.

## Tool choice

Alloy alone was sufficient for this observation.

J was not needed because the question was structural rather than quantitative. Lean 4 was not needed because the result is a set of bounded witnesses and a counterexample to sufficiency, not yet a general law. TLA+ and miniKanren were not used.

## Candidate laws

The first pass tested three behavioral constraints:

1. **exclusive placement** — each resource unit has exactly one purpose at a time;
2. **use follows placement** — a use may name only a purpose currently holding that unit;
3. **purpose change is explicit** — cross-purpose movement is represented by a matching `Change` relation, and named changes correspond to actual movement.

The bounded world contains exactly three times, two purposes, and two resource units. `Use` and `Change` receive finite upper scopes only.

## Executed result

Alloy 6.2.0 + Sat4j produced all five requested witnesses:

```text
baselineEnvelopeLike              SAT
withoutExclusivePlacement         SAT
withoutUseBoundary                SAT
withoutNamedMovement              SAT
repeatedUseUnderCandidateLaws     SAT
```

The first execution attempt stopped before solving because `Use` and `Change` had no explicit scope while the other signatures used exact scopes. Adding finite upper scopes fixed only the execution boundary; the predicates were unchanged.

## What the missing-law witnesses show

### Without exclusive placement

A resource unit can belong to both purposes at the same time while use still follows placement and purpose changes remain named.

In the produced witness, one unit is placed in both purposes at the first time coordinate.

So use confinement plus explicit movement does not imply exclusive purpose membership.

### Without the use boundary

Placement can remain exclusive and movement can remain explicit while a `Use` names a purpose that does not currently hold its resource unit.

So exclusive membership plus explicit movement does not make purpose assignment authoritative for use.

### Without named movement

Placement can remain exclusive and every use can respect placement while a resource unit moves from one purpose to another with no matching `Change` relation.

So exclusive membership plus use confinement does not make reallocation observable.

## The more important counterexample

All three candidate laws can hold while the same resource unit is used at two different times.

```text
exclusive placement
+ use follows placement
+ explicit purpose movement
+ repeated use of one finite Unit
= SAT
```

Under a consumptive reading of household resources, that is not yet envelope behavior. The model knows where a unit belongs, but it does not know whether the unit is still available.

## Finding

The first three laws describe a **purpose boundary**, not an envelope.

They independently provide:

- exclusive purpose membership;
- authority of current placement over use;
- explicit observability of reassignment.

But they do not provide depletion or remaining capacity.

A tentative decomposition is therefore:

```text
Purpose boundary
  = exclusive placement
  + use confinement
  + explicit reassignment

Envelope-like resource
  = Purpose boundary
  + some law of availability / depletion
```

The second equation is a hypothesis for the next observation, not a result of this one.

## Boundary

This observation does not establish that:

- the three purpose-boundary laws are the only relevant laws;
- `Use` must always be consumptive in every resource domain;
- availability should be represented as stored state rather than derived from history;
- an envelope requires individual resource-unit identity;
- adding depletion will be sufficient to derive an envelope;
- the bounded witnesses constitute an unbounded proof.

## Next question

Can availability be derived from initial placement and uses, or must availability itself become primitive state?

That question should begin with Alloy. J becomes useful only if competing availability representations need quantitative comparison, and Lean 4 only if a general equivalence law emerges.
