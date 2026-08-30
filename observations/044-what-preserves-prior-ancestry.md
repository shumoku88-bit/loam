# Observation 044 — What Preserves Prior Ancestry?

## Question

Observation 042 found, in bounded Alloy, that a whole-frontier settlement preserved every previously known revision in the new tip's ancestry when the prior graph was acyclic.

Observation 043 then proved the sole-frontier settlement law without a finite bound.

The remaining question is:

> Is acyclicity itself enough to preserve all prior-known ancestry in an unbounded graph, or did the finite Alloy scope hide another condition?

## Why Lean

This is exactly where bounded search and unbounded proof can separate if a hidden finiteness assumption exists.

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

## The missing condition — frontier coverage

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

## Proved unbounded law

Lean accepted:

```text
AllPriorKnownInAncestry newNode
    <->
FrontierCovered priorView
```

under exact whole-frontier settlement and the rule that direct parents of the new settlement node come from the prior frontier.

The two directions are preserved separately:

```text
FrontierCovered
  + consume whole frontier
  -> every prior-known node remains under the new tip

Every prior-known node under new tip
  + new parents come from frontier
  -> prior view was FrontierCovered
```

The first direction needs no finiteness, acyclicity, freshness, or parent-closure assumption.

This means frontier coverage is not merely one convenient sufficient condition in this formulation. Under the exact parent/frontier rules above, it is equivalent to preservation of every prior-known node in the new tip's ancestry.

## Infinite counterexample to acyclicity alone

Lean also accepted an infinite counterexample:

```text
old 0 < old 1 < old 2 < old 3 < ...
```

where every later old node parents every earlier old node.

The proof establishes all of the following together:

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

A separate theorem proves that this endless prior view is not `FrontierCovered`.

## Observed Lean result

Lean 4.33.1 built and checked the Observation 044 proof successfully after one proof-script repair.

The first run reached the intended theorem but left one trivial rank goal open:

```text
hParent : p < c
⊢ p < c
```

Adding the explicit `exact hParent` closed that goal without changing any definition, theorem statement, or counterexample.

The successful proof therefore establishes:

```text
allPriorKnownInAncestry_iff_frontierCovered   PROVED
acyclicityAloneDoesNotPreserveAncestry        PROVED
endlessNotFrontierCovered                     PROVED
```

## Interpretation

Observation 042's bounded ancestry result must be refined.

The bounded observation suggested:

```text
acyclic
  + whole-frontier settlement
  -> preserve all prior ancestry
```

Observation 044 shows that this does not generalize to arbitrary infinite graphs.

The corrected unbounded statement is:

> Whole-frontier settlement preserves all prior-known ancestry exactly when the prior known region is covered by its frontier.

And:

> Acyclicity prevents loops, but it does not prevent an infinite chain from escaping every frontier.

This separates two structural questions:

```text
acyclicity        : can revision ancestry loop back?
frontier coverage : does every known branch eventually reach a current tip?
```

Finite acyclic graphs can make the second property look automatic. Unbounded reasoning shows that it is not.

## Tool choice

**Lean only.**

The purpose was to expose the finite-scope boundary and preserve the corrected unbounded law. That distinct role was achieved; another Alloy, J, or TLA+ model is not needed for this observation.
