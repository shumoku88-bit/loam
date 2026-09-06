# Observation 204 — Does one-to-many correction force EventCorrection to change shape?

Status: **OBSERVING / UNTESTED**

Concept-pressure source: **F113 — one historical Event -> two jointly effective replacement Events**

## Question

Current production `EventCorrection` is deliberately one-to-one:

```text
target : EventId
replacement : EventId
```

`CorrectionFrontier` admits only disjoint finite paths. In particular, two sibling corrections from the same target are rejected as an unresolved competing shape rather than treated as two jointly effective descendants.

Current `EventResolution` covers the opposite topology:

```text
several current candidate parents
  -> one replacement Event
```

F113 asks whether a legitimate correction can instead mean:

```text
one historical Event
  -> replacement Event A
  -> replacement Event B

A and B are jointly effective
```

The selected query includes provenance, not merely the resulting quantity or the accidental fact that A and B both happen to be remembered. A valid representation must be able to answer that **both A and B are replacement children of the historical Event**.

## Why mere Event presence is insufficient

Suppose Event memory already contains:

```text
Parent
ChildA
ChildB
```

An ordinary Correction `Parent -> ChildA` can leave `ChildB` on a frontier simply because `ChildB` is untargeted. That does not establish that `ChildB` belongs to the correction of `Parent`.

Therefore F113 is not falsified or satisfied merely by observing two Events in the same derived frontier. The relation provenance itself is selected information.

## Attack 1 — current Correction only

The Alloy model retains the structural part of current `CorrectionFrontier` admission relevant here:

```text
one target has at most one replacement
one replacement has at most one target
correction paths are acyclic
```

It then constructs two raw sibling correction facts:

```text
Parent -> ChildA
Parent -> ChildB
```

Expected result:

- the raw sibling topology exists;
- current Correction admission rejects it;
- there is no admitted Correction-only representation in which `Parent` explicitly names both `ChildA` and `ChildB` as correction children.

This is an intended boundary of current Correction, not yet evidence that the boundary is wrong.

## Attack 2 — conservative additive relation

The model then introduces one experiment-local relation shape:

```text
RefinementFact
  parent   : one Event
  children : some Event
```

with the selected witness:

```text
Parent -> {ChildA, ChildB}
```

At the same time, an unrelated ordinary Correction remains admitted under the existing Correction rules.

If this witness is SAT, the narrow architectural result is:

```text
F113 information is missing from Correction
but
it can be represented beside Correction
without weakening or changing Correction itself
```

That is B-level conservative-extension evidence, not C-level Core-shape pressure.

The experiment-local name `RefinementFact` is deliberately disposable. A successful witness does **not** earn a production `EventRefinement`, `SplitCorrection`, graph framework, or generic relation ontology.

## Relation to Structural S003

Structural S003 already established a separate, query-relative quantity fact:

```text
one Effect carrying q1 + q2
vs
two distinct Effects carrying q1 and q2 at the same coordinate
```

are indistinguishable to `Event.quantityAt` while their retained representation remains different.

Observation 204 therefore does not need to rediscover scalar quantity decomposition. Its selected pressure is Event identity and correction provenance across a one-to-many replacement topology.

## C-level decision rule

Observation 204 reaches C only if the selected F113 query cannot be represented while preserving the existing meaning and shape of `EventCorrection` through a separate additive evidence family.

A bounded additive witness is sufficient to defeat that C claim for this specimen, though it does not prove one universal refinement design for all future one-to-many cases.

## Boundary

Research only.

No Core/Application/Persistence/CLI/TUI/canonical-data change.

No production relation type is introduced.

The observation does not decide:

- who has authority to declare a split/refinement;
- whether child quantities must sum to the parent;
- whether Effects are partitioned, copied, or newly observed;
- chronology between parent and children;
- nested refinements;
- interaction between refinement and later Correction;
- generic graph semantics.
