# Observation 046 — Does Coverage Need a Stored Witness?

## Question

Observation 045 left `FrontierCovered` as the weakest condition needed by the selected ancestry-preservation vocabulary:

```text
for every known node,
there exists some frontier tip that covers it
```

The next question is:

> Does the system need to remember which frontier tip is the witness, or can the existential law remain separate from any selected witness?

## Why Lean

This is a distinction between proposition and choice.

There is no new finite quotient question for J, no transition question for TLA+, and no bounded-shape search needed from Alloy.

Lean can express both:

1. the existential coverage law;
2. a selector obtained from that law by classical choice;
3. a graph where two different frontiers both validly cover the same node.

## Neutral vocabulary

Define:

```text
Covers tip node
  := tip is frontier
     and
     (tip = node or tip is an ancestor of node)
```

Then `FrontierCovered` is exactly:

```text
for every known node,
there exists a tip such that Covers tip node
```

## First pressure

Classical choice can produce:

```text
chooseCoveringFrontier : known node -> Node
```

with a proof that the selected node covers the requested node.

This selector is intentionally `noncomputable` and adds no canonical-choice semantics to the graph.

## Second pressure

Use a tiny fork:

```text
      left
       |
      root
       |
      right
```

More precisely, both `left` and `right` directly parent `root`, and neither has a known child.

Then both are frontier nodes and both cover `root`.

So the graph can satisfy `FrontierCovered` while failing:

```text
there exists exactly one covering frontier for root
```

## Interpretation if both proofs hold

The memory boundary depends again on future vocabulary.

If the future asks only:

```text
is every known node covered?
```

then no selected witness needs to be part of semantic memory.

If the future asks:

```text
which frontier covers this node?
```

then the graph plus coverage law may be insufficient to determine a unique answer. A production system would need some additional selection structure if a stable answer matters: for example an explicit witness, an ordering, or another selection policy.

This does not imply that a witness must be stored per node. It separates existence from chosen identity.

## Tool choice

**Lean only.**
