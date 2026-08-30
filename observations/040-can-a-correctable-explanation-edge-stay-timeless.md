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

This observation asks the next pressure point:

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

The interesting question is what can still be answered about `t0` after `e1` arrives. TLA+ therefore adds a distinct result: it can compare the mutable-current oracle and the append-only as-of interpretation throughout reachable transitions.

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

is semantic parentage between interpretation claims, not chronology-by-itself. `e1` wins only because it explicitly supersedes `e0`, not merely because it was learned later.

## As-of parent projection

For a knowledge time `k`, the model first selects claims learned by `k`, then removes any claim explicitly superseded by another claim already known by `k`.

The remaining claim determines:

```text
EffectiveParentAt(history, k)
```

So the intended path is:

```text
t0
  known claims {e0}
  effective parent A

later correction

t1
  known claims {e0,e1}
  effective parent B
```

but the old query remains:

```text
EffectiveParentAt(history, t0) = A
```

## Mutable comparison oracle

The model also maintains a destructive comparison projection:

```text
oracleParent
```

It starts unknown, becomes `A` when `e0` is learned, and is overwritten to `B` when `e1` arrives.

The positive model requires the append-only current projection to agree with this mutable oracle at the current knowledge time.

This does not make the oracle authoritative. It is only a comparison instrument for current effective meaning.

## Positive properties

The primary model checks:

- type correctness;
- interpretation claim identity is unique;
- `e1` can occur only after `e0` and at a later knowledge coordinate;
- current append-only projection matches the mutable-current oracle;
- after correction, the earlier as-of explanation still returns `A` while the later/current explanation returns `B`;
- history only extends.

The key intended asymmetry is:

```text
append-only claim history
      -> current effective parent
      -> historical effective parent as of k

mutable current parent
      -> current effective parent only
```

## Boundary 1 — current graph answers every historical query

The first deliberately strong hypothesis says that the one mutable current parent can answer every non-unknown past as-of query:

```text
EffectiveParentAt(history, k) = oracleParent
```

for every `k <= now`.

A correction should violate this:

```text
t0: e0 says K -> A
advance
t1: e1 says K -> B and supersedes e0

current graph      K -> B
as-of t0 graph     K -> A
```

Expected invariant violation:

```text
MutableCurrentGraphAnswersEveryAsOf
```

If found, it means a mutable timeless **effective** edge rewrites historical explanation when reused retroactively.

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

If learned time were unnecessary, the identical timeless claim graph would determine identical as-of explanations.

But at `t1` the expected answers differ:

```text
Early correction -> B
Late correction  -> A
```

Expected invariant violation:

```text
ClaimGraphWithoutLearnedTimeDeterminesAsOf
```

This tests a different loss from Boundary 1: even an append-only claim graph is insufficient for historical explanation-as-known if the knowledge coordinate at which claims became available is erased.

## Intended interpretation

If the positive model holds and both boundaries fail, the bounded conclusion is:

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

From those pieces the effective explanation graph can be projected as of any modeled knowledge time.

So Observation 039's “timeless graph” boundary sharpens rather than simply disappears:

```text
fixed effective parent graph
  is too small once edge meaning is correctable

append-only claim / supersession graph
  may still be stored once

knowledge time
  selects which interpretation was available as of the query
```

## Important boundaries

This experiment is deliberately linear:

- one conceptual explanation edge;
- one original interpretation and one explicit correction;
- no sibling competing corrections;
- no resolution frontier among edge interpretations;
- no provenance source, authority, or trust semantics;
- no valid-time coordinate distinct from learned time for the edge claim itself;
- no claim that every parent edge in production requires a timestamp field.

If competing corrections to the same explanation edge are later admitted, the correction/frontier work from Observations 022, 023, and 036 may need to recur one level higher, over explanation interpretations themselves.

## Tool choice

**TLA+ only.**
