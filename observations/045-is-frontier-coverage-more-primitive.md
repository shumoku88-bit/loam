# Observation 045 — Is Frontier Coverage More Primitive?

## Question

Observation 044 proved that exact whole-frontier settlement preserves every prior-known node in ancestry exactly when the prior view is `FrontierCovered`.

The next question is:

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

## First hypothesis

If `KnownChild` is well-founded, then no traversal through known children can escape forever.

Expected law:

```text
WellFounded KnownChild
  ->
FrontierCovered
```

The proof should need no finiteness assumption and no settlement-specific assumptions.

## Converse pressure

`FrontierCovered` asks only for at least one frontier route above each known node. It does not say that every possible child path terminates.

So the converse may be too strong.

Use an infinite graph with nodes:

```text
spine 0 < spine 1 < spine 2 < ...

and for every n:

tip n -> spine n
```

Each `tip n` is a frontier node, so every `spine n` is covered immediately by its own tip. Yet the spine itself gives an infinite known-child path.

If Lean accepts both the implication and this counterexample, the result is:

```text
WellFounded KnownChild
          |
          v
   FrontierCovered

but not conversely.
```

## Expected interpretation

Well-foundedness is a sufficient global discipline, but stronger than the ancestry-preservation vocabulary requires.

`FrontierCovered` is more permissive and more exact for Observation 044's question:

> Does every known node have some route into the current frontier?

An unrelated infinite route need not matter if a frontier route still exists.

This would continue LOAM's recurring rule: retain the weakest structure that preserves the future questions actually selected.

## Tool choice

**Lean only.**
