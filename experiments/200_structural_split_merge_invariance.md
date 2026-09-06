# Observation 200 — Structural S003 split / merge representation invariance

Status: **OBSERVING / UNTESTED**

Structural specimen: **S003**

## Question

`LOAM_STRUCTURAL_FALSIFICATION_PROGRESS.md` selected S003 as the first unresolved structural specimen.

The question is deliberately narrower than global Event equivalence:

> If one quantity-bearing Effect is replaced by two distinct Effects at the same `Locus × Measure` coordinate whose exact quantities sum to the original quantity, does the existing `Event.quantityAt` projection change?

The candidate law is query-relative.

```text
World A
  one Effect at c carrying q1 + q2

World B
  two distinct Effects at c carrying q1 and q2

selected query
  Event.quantityAt c
```

The intended positive boundary is:

```text
quantity-only observation
  ignores quantity-preserving decomposition
```

The intended negative boundary is equally important:

```text
retained Effect representation / identity / provenance
  may still distinguish the worlds
```

So this observation does **not** ask whether split and merged Events are interchangeable for all future questions.

## Why Lean

The relevant production semantics already exist in `Loam.Core.Event`:

- Effects have stable identity independent of `(LocusId, MeasureId)`;
- distinct Effects may occupy the same coordinate;
- `Event.quantityAt` sums every matching exact quantity;
- `Event.quantityAt_perm` already removes list order from the selected quantity answer;
- `Event.quantityAt_sameCoordinate_two` already proves additive contribution for two Effects at one coordinate.

The missing structural statement is a direct equality between two different retained decompositions. It is an unbounded exact-integer law over arbitrary `Quantity` values, so Lean is smaller and stronger than enumerating examples in Alloy or J.

## Lean specimen

`Loam/Observations/Observation200.lean` defines only two observation-local constructors:

```text
mergedEvent
  one Effect carrying left + right

splitEvent
  two distinct Effects carrying left and right
```

It then states:

```text
quantityAt_split_merge
```

for arbitrary:

- Event identity;
- Effect identities;
- Locus;
- Measure;
- exact signed `left` and `right` quantities.

The second theorem:

```text
split_merge_representation_remains_distinct
```

records the negative boundary by proving that the retained Effect lists are not the same representation.

## Expected qualification

The dedicated Observation 200 workflow builds only the new Lean observation and its current Core dependencies.

A successful exact-head build qualifies this narrow law:

```text
one Effect (q1 + q2)
    ~quantityAt
 two Effects (q1, q2)
```

at the selected decomposed coordinate.

It does **not** qualify:

- provenance invariance;
- identity invariance;
- Scheduled realization split/merge;
- relation apportionment;
- arbitrary decomposition trees;
- Event normalization;
- replacing retained Effects with aggregate quantities;
- persistence or runtime changes.

Observation 120 remains the important counterpressure: split/merged realization topology can require independently observable apportionment information. S003 therefore applies only where the selected query genuinely forgets decomposition.

## Production impact

None.

No Core, Application, Persistence, CLI, TUI, canonical data, or writer change is introduced.

The only intended result is to make one representation-invariance law explicit and falsifiable against the existing Core.
