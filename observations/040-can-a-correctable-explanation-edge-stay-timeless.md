# Observation 040 — Can a Correctable Explanation Edge Stay Timeless?

## Question

Observation 039 found that selected historical meaning could be factored into two memories:

```text
sparse time index
  -> what was current when?

parent graph
  -> why was it current?
```

The parent graph was intentionally stable. An edge such as:

```text
K -> A
```

was treated as a fixed explanatory relation.

This observation asks:

> If the explanatory edge itself can later be corrected, can one timeless effective parent graph still answer historical explanation-as-known queries?

The question is not whether the graph must be copied at every time coordinate. The narrower alternatives are:

```text
mutable effective graph only
```

versus

```text
append-only interpretation claims
+ learned-time coordinate
+ derived effective graph as of a query time
```

## Why TLA+

Observation 039 used Alloy to establish the static factorization when parentage was fixed.

Here the missing distinction is explicitly temporal:

```text
t0: learn e0, saying K -> A

t1: later learn e1, saying K -> B
    and explicitly superseding e0
```

The interesting question is what can still be answered about `t0` after `e1` arrives. TLA+ therefore adds a distinct result by comparing a mutable-current oracle and an append-only as-of interpretation throughout reachable transitions.

J adds no new quotient question yet. No general Lean theorem is claimed. miniKanren has no distinct role.

## Minimal interpretation vocabulary

There are two explanation-interpretation claims:

```text
e0
  target      A
  supersedes  nothing

e1
  target      B
  supersedes  e0
```

Both concern the same conceptual explanation edge from `K`.

The experiment does not mutate `e0` when `e1` arrives. Instead the history records claim identity and learned time:

```text
[claim |-> e0, learned |-> t0]
[claim |-> e1, learned |-> t1]
```

The relation:

```text
e1 supersedes e0
```

is semantic parentage between interpretation claims, not chronology-by-itself. `e1` wins because it explicitly supersedes `e0`, not merely because it was learned later.

## As-of parent projection

For a knowledge time `k`, the model first selects claims learned by `k`, then removes a claim only when another claim already known by `k` explicitly supersedes it.

The remaining claim determines:

```text
EffectiveParentAt(history, k)
```

So:

```text
t0
  known claims {e0}
  effective parent A

later correction

t1
  known claims {e0,e1}
  effective parent B
```

while the old query remains:

```text
EffectiveParentAt(history, t0) = A
```

## Mutable comparison oracle

The model also maintains a destructive comparison projection:

```text
oracleParent
```

It starts unknown, becomes `A` when `e0` is learned, and is overwritten to `B` when `e1` arrives.

The positive model requires the append-only current projection to agree with this mutable oracle at the current knowledge time. The oracle is only a comparison instrument for current effective meaning.

## Observed positive result

TLC 2.19 with TLA+ tools 1.7.4 completed the positive reachable graph with no error:

```text
9 states generated
9 distinct states
complete graph depth 5
```

The model preserved:

```text
TypeOK
UniqueClaims
CorrectionFollowsOriginal
CurrentProjectionMatchesOracle
PastExplanationSurvivesCorrection
HistoryOnlyExtends
```

So the append-only interpretation history can agree with a destructive current-parent projection while retaining the earlier explanation-as-known answer.

## Boundary 1 — current graph answers every historical query

The deliberately strong hypothesis:

```text
EffectiveParentAt(history, k) = oracleParent
```

for every non-unknown `k <= now` failed as intended.

TLC found the four-state behavior:

```text
State 1
  t0, no explanation claim

State 2
  t0, learn e0
  current parent A

State 3
  advance to t1
  current parent A

State 4
  at t1 learn e1, explicitly superseding e0
  current parent B
```

At State 4:

```text
current graph      K -> B
as-of t0 graph     K -> A
```

So `MutableCurrentGraphAnswersEveryAsOf` is violated.

A single mutable timeless **effective** edge therefore answers the present but rewrites historical explanation if reused retroactively.

## Boundary 2 — learned time is redundant once the claim graph is known

The second boundary fixes two append-only histories with the same claim identities, targets, and supersession shape:

```text
Early correction
  e0 learned at t0
  e1 learned at t1

Late correction
  e0 learned at t0
  e1 learned at t2
```

Their timeless claim graph is identical. Their as-of answer at `t1` is not:

```text
Early correction -> B
Late correction  -> A
```

TLC therefore reports:

```text
ClaimGraphWithoutLearnedTimeDeterminesAsOf = FALSE
```

So even the append-only claim / supersession graph is insufficient for historical explanation-as-known if the knowledge coordinate at which each interpretation became available is erased.

The first CI attempt exposed only a test-harness wording mismatch here: TLC reports this state-independent false invariant as `is equal to FALSE`, rather than using the capitalized `Invariant` wording emitted for a reachable-state violation. The workflow was corrected without changing the model or expected semantic result.

A separate earlier CI attempt also found a TLA+ set-comprehension binding mistake. The claim-set operators were rewritten as explicit predicate comprehensions over `Claims`; the observation question was unchanged.

## Finding

The bounded result is:

> A correctable explanation relation cannot remain only one timeless effective edge when the future vocabulary asks historical explanation-as-known questions.

But this does **not** force a dense graph copy at every knowledge time.

A smaller candidate survives:

```text
append-only interpretation graph
  e1 -> e0        supersession
  e0 -> A         offered parent
  e1 -> B         corrected parent

plus

learned-time index
  e0 -> t0
  e1 -> t1
```

From those pieces the effective explanation edge can be projected as of any modeled knowledge time.

Observation 039's “timeless graph” therefore sharpens rather than disappears:

```text
fixed effective parent graph
  too small once edge meaning is correctable

append-only claim / supersession graph
  may still be stored once

knowledge time
  selects which interpretation was available as of the query
```

The layer that can remain timeless has moved downward: from the **effective explanation graph** to the **graph of explanation interpretations and their semantic relations**.

## Important boundaries

This experiment is deliberately linear:

- one conceptual explanation edge;
- one original interpretation and one explicit correction;
- no sibling competing corrections;
- no resolution frontier among edge interpretations;
- no provenance source, authority, or trust semantics;
- no valid-time coordinate distinct from learned time for the edge claim itself;
- no claim that every parent edge in production requires a timestamp field.

If competing corrections to the same explanation edge are later admitted, the correction/frontier work from Observations 022, 023, and 036 may recur one level higher, over explanation interpretations themselves.

## Tool choice

**TLA+ only.**
