# Observation 038 — Can Frontier History Be Kept as Change Points?

## Question

Observation 037 separated two different notions of compression:

```text
semantic compression
  which histories may be treated as equivalent?

representation compression
  how compactly can the distinctions that must remain be encoded?
```

For the vocabulary that can ask the exact frontier at every knowledge time, Observation 037 found that all 15 tiny histories remained semantically distinguishable.

That does **not** imply that a dense table with one frontier value per time coordinate is the required representation.

This observation asks:

> If exact as-of frontier answers must remain available, can the same meaning be carried by recording only the times at which the frontier changes?

## Why J only

This is a finite representation experiment rather than a new relation search or transition-safety question.

J can enumerate the bounded history space, derive dense timelines, encode change points, reconstruct every as-of answer, and count the retained records directly.

A generic theorem that run-length/change-point encoding round-trips a piecewise-constant sequence would be elementary but is not yet a LOAM-specific law worth adding to Lean.

No Alloy, TLA+, or miniKanren adds a distinct result here.

## Bounded history space

The valid coordinate remains fixed. Knowledge time is lengthened to six later slots:

```text
t1 t2 t3 t4 t5 t6
```

At each slot there may be no new interpretation or one of:

```text
kA  correction of c0
kB  independent correction of c0
r0  whole-frontier Resolution of {kA,kB}
```

Each interpretation may occur at most once. `r0` may occur only after both sibling Corrections have already been learned.

J observed exactly **83 admissible schedules**.

The longer horizon deliberately introduces idle knowledge times. This lets the experiment distinguish a dense time grid from the semantic moments at which the frontier actually changes.

## Dense projection

Each schedule projects to an exact frontier for every one of the six knowledge slots.

Frontier codes are:

```text
0 = {c0}
1 = {kA}
2 = {kB}
3 = {kA,kB}
4 = {r0}
```

The 83 schedules produce 83 distinct dense frontier timelines and:

```text
83 * 6 = 498 dense frontier cells
```

This number is only a record-count baseline, not a byte-size claim.

## Change-point projection

A change-point representation emits a record only when the frontier differs from the preceding knowledge time.

Conceptually each retained record is:

```text
(knowledge time, new frontier)
```

The J implementation uses a fixed-width matrix with `_1` as a temporary sentinel for “no change here” so the experiment stays rank-stable. Only non-`_1` positions count as conceptual change-point records.

Decoding carries the last known frontier forward through idle slots.

## Observed J result

The final J run observed:

```text
admissible six-slot histories:       83
dense frontier cells:               498
change-point records:               192

distribution by change count:
  0 changes :  1 history
  1 change  : 12 histories
  2 changes : 30 histories
  3 changes : 40 histories

distinct dense timelines:            83
distinct change-point encodings:     83
round trip exact:                      1
all emitted change points irredundant: 1
```

Two implementation mistakes were found before this result and were corrected without changing the question:

1. the mixed-radix schedule matrix was accidentally transposed, so schedules were presented along the wrong axis;
2. change-point counting used an ambiguous J expression, so the comparison mask was named explicitly before row summation.

The final run therefore compares the intended 83 row-major histories and the intended per-row change masks.

## Exact round trip

For every admissible schedule:

```text
decode(encode(dense frontier timeline))
  =
dense frontier timeline
```

So every exact as-of frontier answer selected by this observation survives the representation change.

## Distinguishability is preserved

All 83 dense timelines are distinct and all 83 change-point encodings are distinct.

Representation compression therefore did not perform additional semantic quotienting in this scope.

Observation 037's semantic distinctions remain intact even though idle time cells disappear from the representation.

## Idle time is omitted

Across all 83 histories, the dense projection contains 498 time-indexed frontier cells while the sparse projection contains 192 semantic change records.

In this clean model every admitted interpretation changes the exact frontier, and the J experiment confirms:

```text
change-point count = admitted interpretation count
```

So change points remove idle knowledge-time cells. They do not erase meaningful interpretation changes.

Again, 498 versus 192 compares logical record counts, not bytes. A sparse record must carry its knowledge coordinate as well as its frontier value.

## Every emitted point is necessary for this vocabulary

For every emitted change point in every history, J deletes that one point and decodes again.

Every deletion changes at least one reconstructed exact as-of frontier answer.

Thus, relative to the vocabulary asking the exact frontier at every knowledge time, the emitted change points are irredundant in this bounded representation.

This is not a global minimum-bit proof. It says only that no emitted semantic change can be dropped while preserving the selected dense answer timeline under this decoder.

## Interpretation

The bounded conclusion is:

> Exact historical distinguishability does not require a dense historical table. A piecewise-constant frontier can preserve every selected as-of answer by retaining only its semantic change points.

This sharpens Observation 037:

```text
future vocabulary determines
  which distinctions must survive

representation determines
  how economically those distinctions are carried
```

The two questions are related but not identical.

A history may be semantically impossible to quotient any further for a chosen vocabulary while still admitting a much sparser representation.

## Important boundary

This model is deliberately clean:

- every admitted interpretation changes the exact frontier;
- there is only one valid coordinate;
- frontier identity is the only selected historical answer;
- no provenance invisible to the frontier is retained;
- no duplicate or semantically redundant observations occur.

Therefore the experiment shows that idle time cells are unnecessary for the selected frontier vocabulary. It does **not** show that event history, parentage, provenance, or all temporal metadata can always be reconstructed from frontier change points.

In particular, a future vocabulary that asks **why** a frontier has a certain value may require a second retained structure even when the frontier timeline itself is represented sparsely.

## Tool choice

**J only.**
