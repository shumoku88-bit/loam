# Structural S003 — split / merge representation invariance

Status: **DONE / SURVIVED**

Structural specimen: **S003**

## Why this record uses the S namespace

The structural falsification corpus is intentionally separate from the domain Observation sequence. During the first S003 implementation, the proof was temporarily published as `Observation 200` while domain falsification work had already used Observation 200 for F055 and was advancing Observation 201 for F086.

That naming collision did not change the S003 theorem, but it made repository memory ambiguous. This record therefore follows the authority that already existed in `LOAM_STRUCTURAL_FALSIFICATION_ATLAS.md`:

```text
structural specimen identity = S003
```

The proof and CI are now named by S003 rather than borrowing the domain Observation number sequence.

## Question

If one quantity-bearing Effect is replaced by two distinct Effects at the same `Locus × Measure` coordinate whose exact quantities sum to the original quantity, does the existing `Event.quantityAt` projection change?

The tested law is query-relative.

```text
World A
  one Effect at c carrying q1 + q2

World B
  two distinct Effects at c carrying q1 and q2

selected query
  Event.quantityAt c
```

The positive boundary is:

```text
quantity-only observation
  ignores quantity-preserving decomposition
```

The negative boundary is equally important:

```text
retained Effect representation / identity / provenance
  may still distinguish the worlds
```

So S003 does **not** say that split and merged Events are interchangeable for all future questions.

## Why Lean

The relevant production semantics already exist in `Loam.Core.Event`:

- Effects have stable identity independent of `(LocusId, MeasureId)`;
- distinct Effects may occupy the same coordinate;
- `Event.quantityAt` sums every matching exact quantity;
- `Event.quantityAt_perm` already removes list order from the selected quantity answer;
- `Event.quantityAt_sameCoordinate_two` already proves additive contribution for two Effects at one coordinate.

The missing structural statement was a direct equality between two different retained decompositions. It is an unbounded exact-integer law over arbitrary `Quantity` values, so Lean is smaller and stronger than enumerating examples in Alloy or J.

## Lean result

`Loam/Observations/StructuralS003.lean` defines two structural-test-local constructors:

```text
mergedEvent
  one Effect carrying left + right

splitEvent
  two distinct Effects carrying left and right
```

It proves `quantityAt_split_merge` for arbitrary Event identity, Effect identities, Locus, Measure, and exact signed `left` and `right` quantities.

The second theorem, `split_merge_representation_remains_distinct`, proves the retained Effect lists are still different representations. The quantity projection forgets the decomposition; retained evidence does not.

## Finding

S003 survives at the selected query boundary:

```text
quantity-preserving Effect split / merge
  -> invisible to Event.quantityAt at the decomposed coordinate
```

while:

```text
Effect decomposition / identity
  -> remains retained and observable to other questions
```

This is a genuine representation-invariance result only after naming the query that induces the equivalence. It fits the earlier Observation 029 / S009 principle that query vocabulary induces observational equivalence.

## Boundaries

S003 does **not** qualify:

- provenance invariance;
- identity invariance;
- Scheduled realization split/merge;
- relation apportionment;
- arbitrary decomposition trees;
- Event normalization;
- replacing retained Effects with aggregate quantities;
- persistence or runtime changes.

Observation 120 remains important counterpressure: split/merged realization topology can require independently observable apportionment information. S003 applies only where the selected query genuinely forgets decomposition.

## Production impact

None.

No Core, Application, Persistence, CLI, TUI, canonical data, or writer change is introduced. No new domain primitive is earned. No existing primitive is deleted.
