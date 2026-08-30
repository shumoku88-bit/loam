# Observation 045 — Is Frontier Coverage More Primitive?

## Question

Observation 044 proved that exact whole-frontier settlement preserves every prior-known node in ancestry exactly when the prior view is `FrontierCovered`.

The next question was:

> Must `FrontierCovered` be kept as its own structural condition, or can it be replaced by a more familiar condition such as well-foundedness?

## Why Lean

This is an unbounded implication question.

Alloy cannot distinguish a genuinely infinite branch from a very long finite one. J has no new quotient question. TLA+ has no new transition question.

Lean can prove the sufficient implication and also construct an infinite counterexample to the converse.

## Neutral vocabulary

Observation 045 keeps Observation 044's generic graph and defines only:

```text
KnownChild child prior
  := known child and parent child prior
```

This relation points from an older known node toward one of its known children.

## Observed sufficient law

Lean proves:

```text
WellFounded KnownChild
  ->
FrontierCovered
```

The proof needs no finiteness, parent-closure, freshness, settlement-node, or acyclicity assumption.

The proof follows well-founded induction. At each known node:

- if it has no known child, it is itself a frontier;
- otherwise choose one known child and apply the induction hypothesis;
- append the current direct parent step to the ancestry path returned above that child.

Observed theorem:

```text
wellFoundedKnownChild_implies_frontierCovered   PROVED
```

## Converse boundary

`FrontierCovered` asks only for at least one frontier route above each known node. It does not say that every possible child path terminates.

Lean proves the converse false with an infinite graph:

```text
spine 0 < spine 1 < spine 2 < ...

and for every n:

tip n -> spine n
```

Each `tip n` is a frontier node. Therefore every `spine n` is frontier-covered immediately by its own tip, while every tip covers itself.

At the same time, the spine gives the infinite known-child chain:

```text
spine 0 <- spine 1 <- spine 2 <- ...
```

so `KnownChild` is not well-founded.

Observed theorems:

```text
escapingFrontierCovered                         PROVED
escapingNotWellFounded                         PROVED
frontierCoverageDoesNotImplyWellFounded        PROVED
```

The first Lean run failed only in the auxiliary ancestry concatenation helper: the induction hypothesis still expected the final direct parent argument. Changing `ih` to `ih hParent` repaired the proof script without changing the law or counterexample.

## Result

```text
WellFounded KnownChild
          |
          v
   FrontierCovered

but not conversely.
```

Well-foundedness is therefore a sufficient global discipline, but strictly stronger than the ancestry-preservation vocabulary requires.

`FrontierCovered` is more permissive and more exact for Observation 044's question:

> Does every known node have some route into the current frontier?

An unrelated infinite route does not matter if a frontier route still exists.

This continues LOAM's recurring rule: retain the weakest structure that preserves the future questions actually selected.

## Boundary

This observation does not claim that well-foundedness is unhelpful operationally. A production representation may intentionally choose it, finiteness, or another stronger condition because those properties simplify traversal or storage.

The narrower result is semantic:

> For preserving every prior-known node under whole-frontier settlement, global termination of every known-child path is more than the selected vocabulary needs.

## Tool choice

**Lean only.**
