# Observation 047 — Can Selection Policy Remain an Overlay?

## Question

Observation 046 separated two claims:

```text
there exists a covering frontier
```

and

```text
which covering frontier is selected?
```

The next question is:

> If multiple valid covers exist, does the graph itself determine a stable selected cover, or can selection policy remain a separate overlay on the same graph?

## Why Alloy

The missing question is static independence between two structures:

1. the revision graph that determines coverage;
2. a preference relation used only to select among already-valid covers.

This is the same kind of pressure that Observation 033 used to separate event history from a valuation relation. No transition semantics are needed, and there is not yet a general law worth lifting to Lean.

## Neutral model

Each world contains:

```text
known  : set Node
parent : Node -> Node
better : Node -> Node
```

`parent` determines frontier and coverage.

`better` is a strict total order over known nodes and is used only when a node has more than one valid covering frontier.

The selected cover is derived as the covering frontier with no better covering frontier above it in the policy order.

## Observed result

Alloy 6.2.0 + Sat4j, exactly 3 `Node` and exactly 2 `World`:

```text
selectionPolicyCanChangeOnlySelection          SAT
oppositePoliciesCanChooseDifferentForkTips    SAT
GraphDeterminesCoverage                       UNSAT
GraphDeterminesSelection                       SAT
GraphPlusPolicyDeterminesSelection            UNSAT
```

The first model version accidentally wrote transitivity as `w.better.w.better in w.better`; Alloy warned that the joins were empty, so that constraint was vacuous. It was replaced by an explicit three-node transitivity condition:

```text
all a, b, c: w.known |
  (a->b in w.better and b->c in w.better) implies
    a->c in w.better
```

The final model produced the same SAT/UNSAT results with no Alloy warnings.

## Interpretation

The same `known` / `parent` graph can have the same covering relation while different strict-total selection policies choose different covering tips.

So:

```text
coverage
  <- graph

selected identity
  <- graph + policy
```

The graph alone determines which tips are valid covers in this bounded model, but it does not determine which valid cover becomes the selected answer.

Adding the same policy to the same graph is sufficient to determine selection for the selected vocabulary.

This closes the current chain as three distinct layers:

```text
existence of a cover
    -> graph law

ability to return some witness
    -> existence + choice

stable selected identity
    -> graph + explicit selection policy
```

A need for a single answer does not cause the graph itself to generate authority for one candidate.

## Boundary

This observation does not claim that a production system needs a stored total order, nor that total order is the right policy form.

It establishes only that some explicit selection structure is semantically distinct from the coverage graph when multiple covers are admissible.

Time-varying policy, provenance of policy, authority for policy, and correction of policy remain possible future questions, but they are intentionally not pursued here. They would reopen a branch that is now sufficiently characterized for a first core-candidate discussion.

## Tool choice

**Alloy only.**
