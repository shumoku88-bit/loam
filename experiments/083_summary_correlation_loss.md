# Observation 083 — Do separate summaries preserve their joint correlation?

## Question

Observation 082 established that the privacy-safe realization matrix does not reconstruct Plan → Actual provenance.

The current private realization observer nevertheless retains one useful joint shape:

```text
time bucket × physical-delta bucket
```

A tempting further compression would publish only two separate marginal summaries:

```text
time counts
+
physical-delta counts
```

The question is:

> If two worlds have the same summary for dimension A and the same summary for dimension B, must they have the same joint A × B summary?

In the current realization setting this asks whether separate time totals and physical-delta totals preserve which physical deltas occurred in which time buckets.

No private canonical values are required for this question.

## Why this follows Observation 082

Observation 082 tested:

```text
joint privacy-safe aggregate
    -/->
identity provenance
```

Observation 083 tests a different loss boundary one projection step later:

```text
joint aggregate
    ↓ marginalize
separate summaries
```

and asks whether the separate summaries can recover the joint aggregate.

This is correlation loss, not identity-provenance loss.

## Smallest useful model

The experiment uses only:

- four anonymous Links;
- two time buckets;
- two physical-delta buckets;
- two Worlds;
- one time classification and one delta classification per Link in each World.

The witness deliberately fixes the per-Link time classification across the two Worlds while allowing the delta classification to differ. Both Worlds must occupy both marginal buckets.

The model retains no Plan, Event, quantity, date, Locus, Measure, description, account-like noun, or private source value.

## Alloy question

For each World the model computes:

```text
timeCount(time bucket)
deltaCount(delta bucket)
jointCount(time bucket, delta bucket)
```

It then asks for two Worlds with:

```text
same time marginals
same delta marginals
different joint summary
```

Expected Observation 083 receipt:

```text
sameMarginalsDifferentJoint              SAT
SeparateMarginalsDetermineJoint           SAT counterexample
JointSummaryDeterminesMarginals           UNSAT counterexample
SameLinkClassificationsDetermineJoint     UNSAT counterexample
```

The first two results establish the negative boundary. The final two are only bounded model checks and are not promoted here into unbounded Lean theorems.

## J shape observation

J makes the same loss visible as array reduction using two synthetic 2 × 2 matrices:

```text
Left          Right
2 0           0 2
0 2           2 0
```

Both have the same row marginals:

```text
2 2
```

and the same column marginals:

```text
2 2
```

but the joint matrices differ.

So reducing the joint array along each axis independently discards the association between the axes.

## Finding

The boundary under observation is:

```text
summary(A × B)
    ->
summary(A) + summary(B)

but

summary(A) + summary(B)
    -/->
summary(A × B)
```

Equivalently:

```text
separately sufficient summaries
for separate questions
    !=
a sufficient summary
for a cross-dimension question
```

This matters to LOAM because privacy-safe and query-specific observations are intentionally lossy. Two safe summaries should not be silently treated as though their lost correlation were still present merely because both summaries came from the same canonical source.

## Tool boundary

Alloy is used because the question is relational: can two worlds preserve both marginals while differing in the joint relation?

J is used because the information loss is also an array-shape operation: row and column reductions can agree while the original matrix differs.

Lean is deliberately not added in this observation. The central claim is negative, and one exact counterexample is sufficient to refute the universal implication. A future positive law should be moved to Lean only if a real operation or retained query needs that law generally.

## Non-goals

Observation 083 does not earn:

- a generic `Summary` type;
- a generic `Correlation` primitive;
- a generic privacy framework;
- a universal observer algebra;
- a Plan or realization store in Practical Core;
- a requirement to retain every joint projection;
- a claim that marginal summaries are unsafe or useless;
- a new Persistence, CLI, or wire-format primitive.

The result only constrains later reuse: if a later query asks about cross-dimension association, separately retained marginals are not enough evidence for that answer.

## Practical Core impact

None.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no private canonical data committed;
- no source mutation.
