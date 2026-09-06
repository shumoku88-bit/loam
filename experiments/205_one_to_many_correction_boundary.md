# Observation 205 — Does one-to-many correction force EventCorrection to change shape?

Status: **COMPLETE / B — CONSERVATIVE EXTENSION; C NOT DEMONSTRATED**

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

Therefore F113 is not answered merely by observing two Events in the same derived frontier. The relation provenance itself is selected information.

## Model

The Alloy model retains the structural part of current `CorrectionFrontier` admission relevant here:

```text
one target has at most one replacement
one replacement has at most one target
correction paths are acyclic
```

It then attacks two candidate representations.

### Current Correction only

Raw sibling facts:

```text
Parent -> ChildA
Parent -> ChildB
```

can be stated, but they cannot be admitted simultaneously under the current Correction shape.

### Conservative additive relation

One experiment-local relation shape is added beside Correction:

```text
RefinementFact
  parent   : one Event
  children : some Event
```

with the selected witness:

```text
Parent -> {ChildA, ChildB}
```

An unrelated ordinary Correction remains admitted under the unchanged current rules.

The model also compares two worlds with **identical admitted Correction evidence** but different refinement evidence, so the F113 provenance difference cannot be reconstructed from Correction alone.

## Mechanical result

Dedicated Observation 205 Alloy CI succeeded on executable head:

```text
4363d402fe3148a8a314d258e78af3b71bb77cfa
```

Workflow run:

```text
34009186374
```

The PR merge ref used by that successful run already incorporated then-current main `f0cecbec9ef0cb81a3be258ffd15434c6dc4eedc`, so the witness was checked against the current main context rather than only the older branch base.

Observed matrix:

```text
rawSiblingF113                               SAT
siblingPairRejectedByCorrectionAdmission     SAT
correctionOnlyJointReplacement               UNSAT
AdmittedCorrectionNamesAtMostOneChild        UNSAT counterexample
additiveRefinementWitness                     SAT
sameCorrectionDifferentRefinementProvenance   SAT
```

The expected-result gate passed.

## Finding

F113 establishes a real information boundary:

```text
current admitted EventCorrection evidence
  -/-> one parent with two jointly effective replacement children
```

The same admitted Correction evidence can coexist with two worlds:

```text
WithoutSplit
  no one-to-many replacement provenance

WithSplit
  Parent -> {ChildA, ChildB}
```

So the one-to-many provenance is independently observable information.

However the stronger C-level claim does **not** survive this bounded attack.

A separate additive relation can retain exactly the missing provenance while leaving current `EventCorrection` meaning and admission unchanged:

```text
EventCorrection stays one target -> one replacement

separate additive evidence, if ever earned
  carries one parent -> several jointly effective children
```

Therefore the architectural result for this specimen is:

```text
Correction-only completeness     FALSIFIED
missing independent information  YES
conservative additive shape      SAT
Core-shape pressure C             NOT DEMONSTRATED
classification                    B
```

This is a stronger survival result for the existing Correction boundary than merely saying the current API lacks a case. The selected missing case can be represented without weakening sibling-conflict semantics or turning `EventCorrection` into a generic graph edge.

## What is not earned

The experiment-local name `RefinementFact` is disposable.

Observation 205 does **not** earn a production:

- `EventRefinement`;
- `SplitCorrection`;
- generic graph framework;
- generic relation ontology;
- new persistence syntax;
- new correction winner semantics.

If real dogfood later requires one-to-many correction provenance, the evidence says to begin with a separate narrow typed family rather than redesigning `EventCorrection` in advance.

## Relation to Structural S003

Structural S003 established a different, query-relative quantity result:

```text
one Effect carrying q1 + q2
vs
two distinct Effects carrying q1 and q2 at the same coordinate
```

are indistinguishable to `Event.quantityAt` while their retained representation remains different.

Observation 205 does not reinterpret that as Event identity equivalence. F113 concerns Event-level correction provenance, and the successful additive witness preserves both replacement Event identities explicitly.

## Boundary

Research only.

No Core/Application/Persistence/CLI/TUI/canonical-data change.

The observation does not decide:

- who has authority to declare a split/refinement;
- whether child quantities must sum to the parent;
- whether Effects are partitioned, copied, or newly observed;
- chronology between parent and children;
- nested refinements;
- interaction between refinement and later Correction;
- generic graph semantics.
