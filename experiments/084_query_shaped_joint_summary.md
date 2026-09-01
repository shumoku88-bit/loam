# Observation 084 — Is the extra evidence needed for a joint query shape-dependent?

## Question

Observation 081 established that a retained formal result is not context-free reusable evidence: applicability depends on the later question.

Observation 083 then established a concrete information-loss boundary:

```text
joint summary
    ->
separate marginals

but

separate marginals
    -/->
joint summary
```

A natural response would be to retain some additional cross-dimension evidence. The question is not merely whether more evidence helps, but whether there is one context-free amount or shape of extra evidence that repairs the loss.

Observation 084 asks the smallest useful version:

> If row and column marginals are retained together with one chosen joint cell, does that determine the whole joint table?

The experiment compares a 2 × 2 table with a 3 × 3 table.

No private canonical values are required.

## 2 × 2 positive law

For an exact 2 × 2 integer table

```text
a00 a01

a10 a11
```

one joint anchor `a00` plus three independent marginal totals determine the remaining cells:

```text
a01 = row0 - a00

a10 = col0 - a00

a11 = row1 - a10
```

The second-column marginal then follows from those same premises.

Lean checks this as an unbounded integer theorem in `084_query_shaped_joint_summary.lean`:

```text
anchor
+ row0 marginal
+ row1 marginal
+ col0 marginal
    ->
all four cells equal
```

This is stronger than saying that all row and column marginals plus one anchor are sufficient, because one of the four marginals is already redundant in the 2 × 2 case.

## 3 × 3 negative boundary

The same repair does not scale unchanged to 3 × 3.

J uses two synthetic tables:

```text
Left          Right
2 0 0         2 0 0
0 2 0         0 0 2
0 0 2         0 2 0
```

They have:

- the same row marginals;
- the same column marginals;
- the same chosen top-left joint cell;
- different joint matrices.

Alloy asks the same relational question with six anonymous Links, three row buckets, three column buckets, and two Worlds. It requires all marginal buckets to be occupied and the retained anchor count to be positive.

Expected Alloy receipt:

```text
sameMarginalsSameAnchorDifferentJoint                 SAT
MarginalsPlusOneAnchorDetermineThreeByThreeJoint      SAT counterexample
```

So one retained joint coordinate is enough for the fixed 2 × 2 shape, but is not enough for the fixed 3 × 3 shape.

## Finding

The earned boundary is:

```text
2 × 2:
  marginals + one joint anchor
      -> whole joint table

3 × 3:
  marginals + one joint anchor
      -/-> whole joint table
```

The important point is not the number one by itself. It is that the amount and arrangement of retained cross-dimension evidence required for a later query depends on the shape of that query.

This connects Observation 081 and Observation 083:

```text
081: later question participates in applicability
083: separate marginals lose cross-dimension association
084: sufficient retained cross-evidence is itself query-shape dependent
```

A privacy-safe observer therefore should not silently promote a fixed summary recipe into a universal sufficient state representation.

## Tool boundary

Lean is used for the positive 2 × 2 law because this is a general exact arithmetic implication, not merely a bounded search result.

Alloy is used for the 3 × 3 negative side because one relational counterexample is enough to refute the universal implication in that shape.

J is used to expose both sides as ordinary array operations: exact reconstruction in 2 × 2 and residual ambiguity in 3 × 3.

## Non-goals

Observation 084 does not earn:

- a generic `Summary` type;
- a generic `Anchor` or `Correlation` primitive;
- a universal minimal-summary formula;
- the general `(rows - 1) × (columns - 1)` degrees-of-freedom law;
- a privacy framework;
- a realization store;
- a new Practical Core primitive;
- a Persistence, CLI, or wire-format change.

The general contingency-table formula may be mathematically suggestive, but this observation deliberately earns only the 2 × 2 positive law and the 3 × 3 counterexample.

## Practical Core impact

None.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private canonical data committed;
- no source mutation.
