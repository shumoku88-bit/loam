# Observation 044 — What Preserves Prior Ancestry?

## Question

Observation 042 found, in bounded Alloy, that a whole-frontier settlement preserved every previously known revision in the new tip's ancestry when the prior graph was acyclic.

Observation 043 then proved the sole-frontier settlement law without a finite bound.

The remaining question is:

> Is acyclicity itself enough to preserve all prior-known ancestry in an unbounded graph, or did the finite Alloy scope hide another condition?

## Why Lean

This is exactly where bounded search and unbounded proof should disagree if a hidden finiteness assumption exists.

No new Alloy run is needed. J has no distinct quotient question here. TLA+ has no new transition question.

Lean can both:

1. state an unbounded ancestry-preservation law;
2. construct an infinite acyclic counterexample if acyclicity alone is insufficient.

## Generic vocabulary

Observation 044 reuses Observation 043's neutral core:

```text
NodeSet = Node -> Prop
Parent  = Node -> Node -> Prop
Frontier
ConsumesWholeFrontier
ParentsFromFrontier
```

and adds only transitive ancestry:

```text
Ancestor parent child prior
```

No household, explanation, chronology, quantity, purpose, or meaning vocabulary appears.

## Candidate missing condition

Define a prior view as `FrontierCovered` when every known node is either itself a frontier node or lies below at least one frontier node in ancestry:

```text
for every known node x
there exists frontier tip f such that
  f = x
  or
  f is an ancestor of x
```

This says that following revision descendants upward from any known node eventually reaches some current frontier.

It is weaker and more precise than saying merely that the graph is finite.

## Target law

Under exact whole-frontier settlement:

```text
AllPriorKnownInAncestry newNode
    <->
FrontierCovered priorView
```

provided direct parents of the new settlement node come from the prior frontier.

The two directions have different roles:

```text
FrontierCovered
  + consume whole frontier
  -> every prior-known node remains under the new tip

Every prior-known node under new tip
  + new parents come from frontier
  -> prior view was FrontierCovered
```

Notably, the first direction needs no finiteness, acyclicity, freshness, or parent-closure assumption.

## Infinite counterexample to acyclicity alone

The Lean model also defines an infinite chain:

```text
old 0 < old 1 < old 2 < old 3 < ...
```

where every later old node parents every earlier old node.

Properties:

```text
- the relation is acyclic;
- the known set is parent-closed;
- newTip is fresh;
- newTip has no parents outside the frontier;
- the prior frontier is empty, because every old node has a later known child;
- therefore newTip vacuously consumes the whole prior frontier;
- nevertheless old 0 is not in newTip's ancestry.
```

So an infinite acyclic graph can fail ancestry preservation even under exact whole-frontier consumption.

The missing property is not acyclicity. It is frontier coverage, or some stronger condition such as finiteness / well-foundedness that implies frontier coverage.

## Expected interpretation

If Lean checks both the equivalence and the infinite counterexample, Observation 042's ancestry result should be refined to:

> Whole-frontier settlement preserves all prior-known ancestry exactly when the prior known region is covered by its frontier.

And:

> Acyclicity prevents loops, but it does not prevent an infinite chain from escaping every frontier.

This distinguishes two structural questions:

```text
acyclicity       : can revision ancestry loop back?
frontier coverage: does every known branch eventually reach a current tip?
```

## Tool choice

**Lean only.**

The purpose is to expose the finite-scope boundary and preserve the corrected unbounded law.
