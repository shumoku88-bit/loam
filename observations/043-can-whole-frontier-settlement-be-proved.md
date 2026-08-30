# Observation 043 — Can Whole-Frontier Settlement Be Proved?

## Question

Observation 042 removed household-event and explanation-claim vocabulary and found the same bounded law in a generic revision graph:

```text
frontier(later) = {r}
    iff
r.parent = frontier(prior)
```

The next question is no longer whether a small Alloy scope contains a counterexample.

> Can the whole-frontier settlement equivalence be proved without a finite graph bound?

## Why Lean

Alloy already did its job in Observation 042: it searched arbitrary bounded graph shapes and found no counterexample up to 6 Revision atoms / 4 View atoms.

Lean now adds a distinct result: an unbounded theorem over an arbitrary node type.

J, TLA+, and miniKanren do not add a separate answer to this static law.

## Representation

The proof deliberately avoids finite-set infrastructure.

A node set is only a predicate:

```text
Node -> Prop
```

and parentage is only a relation:

```text
Node -> Node -> Prop
```

The frontier is:

```text
known(node)
and
no known child parents node
```

A one-node step changes membership from:

```text
known
```

to:

```text
known + newNode
```

with three structural assumptions inherited from Observation 042:

1. `newNode` is fresh;
2. the prior known set is parent-closed;
3. every parent chosen by `newNode` lies on the prior frontier.

The theorem does not assume a finite node type, a bounded graph, chronology, meaning, quantity, source, authority, or domain-specific event kinds.

## Logical boundary

The direction

```text
sole later frontier
  ->
new node consumed every prior frontier node
```

needs to turn the impossibility of a surviving old frontier node into the positive fact that `newNode` parents it.

Instead of silently importing classical choice, the theorem makes this small operational assumption explicit:

```text
for every node,
parent newNode node is decidable
```

This does not make the graph finite. It only says the parent relation from the newly added node can be decided.

## Intended theorem

```text
SoleFrontier parent known newNode
  <->
ConsumesWholeFrontier parent known newNode
```

where:

```text
SoleFrontier
  = every later frontier node is exactly newNode

ConsumesWholeFrontier
  = newNode's parents are exactly the prior frontier
```

Two helper laws expose the mechanism:

```text
newNode is always on the later frontier
```

and, for every old node distinct from `newNode`:

```text
old node is on later frontier
  <->
(old node was on prior frontier
 and newNode does not parent it)
```

The second statement is the algebraic hinge of the proof.

## Boundary

Observation 043 intentionally proves only the settlement equivalence first.

Observation 042 also found bounded evidence that whole-frontier settlement preserves all prior known nodes in the new tip's ancestry under acyclicity. That is a separate theorem candidate and is not required here.

## Tool choice

**Lean only.**
