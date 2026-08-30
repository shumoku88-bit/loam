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

The next question is:

> If exact as-of frontier answers must remain available, can the same meaning be carried by recording only the times at which the frontier changes?

## Why J only

This is a finite representation experiment rather than a new relation search or transition-safety question.

J can enumerate the bounded history space, derive dense timelines, encode change points, reconstruct every as-of answer, and count the retained records directly.

A generic theorem that run-length/change-point encoding round-trips a piecewise-constant sequence would be elementary but is not yet a LOAM-specific law worth adding to Lean. If a later observation discovers a stronger domain law, it can be promoted then.

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

Under those constraints the expected bounded space contains **83 admissible schedules**.

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

A dense representation therefore stores six frontier cells per history.

Across 83 histories that is expected to produce:

```text
83 * 6 = 498 dense frontier cells
```

This number is only a convenient record-count baseline, not a byte-size claim.

## Change-point projection

A change-point representation emits a record only when the frontier differs from the preceding knowledge time.

Conceptually each retained record is:

```text
(knowledge time, new frontier)
```

The J implementation uses a fixed-width matrix with `_1` as a temporary sentinel for “no change here” so the experiment stays rank-stable. Only non-`_1` positions count as conceptual change-point records.

Decoding carries the last known frontier forward through idle slots.

## Expected checks

The experiment asks for four things.

### 1. Exact round trip

For every admissible schedule:

```text
decode(encode(dense frontier timeline))
  =
dense frontier timeline
```

So every exact as-of query must return the same answer after representation compression.

### 2. Distinguishability is preserved

If all 83 dense timelines are distinct, all 83 change-point encodings should also remain distinct.

This checks that representation compression does not accidentally perform semantic quotienting.

### 3. Idle time is omitted

Because there are at most three semantic interpretation changes, each six-slot history should need only zero to three change-point records.

The expected distribution is:

```text
0 changes :  1 history
1 change  : 12 histories
2 changes : 30 histories
3 changes : 40 histories
```

for a total of:

```text
192 change-point records
```

rather than 498 dense frontier cells.

Again, this compares logical record counts, not bytes: a sparse record must also carry its time coordinate.

### 4. Every emitted point is necessary for this vocabulary

For every change point in every encoded history, delete that one point and decode again.

If the future vocabulary may ask the exact frontier at **every** knowledge time, the modified encoding should differ from the target timeline somewhere.

This is a bounded irredundancy claim about emitted change points, not a global minimal-bit theorem.

## Expected interpretation

If all checks hold, the bounded conclusion is:

> Exact historical distinguishability does not require a dense historical table. A piecewise-constant frontier can preserve every selected as-of answer by retaining only its semantic change points.

This would sharpen Observation 037:

```text
future vocabulary determines
  which distinctions must survive

representation determines
  how economically those distinctions are carried
```

The two questions are related but not identical.

## Important boundary

This model is deliberately clean:

- every admitted interpretation changes the exact frontier;
- there is only one valid coordinate;
- frontier identity is the only selected historical answer;
- no provenance invisible to the frontier is retained;
- no duplicate or semantically redundant observations occur.

Therefore change-point count equals admitted semantic-event count in this scope.

The experiment may show that idle time cells are unnecessary. It does **not** show that event history, parentage, provenance, or all temporal metadata can always be reconstructed from frontier change points.

## Tool choice

**J only.**
