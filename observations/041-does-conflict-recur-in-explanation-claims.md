# Observation 041 — Does Conflict Recur in Explanation Claims?

## Question

Observation 040 moved the timeless boundary downward:

```text
effective explanation edge
  -> time-dependent projection

append-only interpretation / supersession graph
  -> candidate timeless memory
```

That observation admitted only one linear correction:

```text
e0 : K -> A

e1 : K -> B
     supersedes e0
```

This observation asks what happens when the explanation interpretation itself can receive two sibling corrections.

> Does the frontier / resolution structure previously seen for corrected household meaning recur one level higher, over claims about an explanation edge?

## Why Alloy

The new question is structural rather than temporal.

We want to compare graph shapes:

```text
        KA
       /
E0 ---
       \
        KB
```

and ask what counts as current when both siblings supersede the same prior interpretation.

Observation 040 already established the distinct role of learned time with TLA+. No additional transition result is needed here. Alloy is therefore the smallest tool for the collision / frontier question.

J adds no new quotient question. Lean is deferred until a genuinely generic revision-graph law is visible. miniKanren has no distinct role.

## Bounded interpretation graph

The claims describe interpretations of one conceptual explanation edge from `K`.

```text
E0       original interpretation
KA, KB   sibling corrections of E0
Partial  correction of KA only
Resolve  resolution of both KA and KB
```

The parent relation points from a new interpretation claim to the claim or claims it supersedes:

```text
KA      -> E0
KB      -> E0
Partial -> KA
Resolve -> {KA, KB}
```

The experiment deliberately does not choose a winner by arrival order, timestamp, claim name, or target meaning.

## Frontier

For a view containing a set of known claims, the current frontier is defined as:

```text
known claims
minus
claims directly superseded by another known claim
```

So the intended conflict view is:

```text
known = {E0, KA, KB}
frontier = {KA, KB}
```

The siblings remain simultaneously current because neither supersedes the other.

## Partial resolution

A partial interpretation claim supersedes only `KA`:

```text
Partial -> KA
```

With `KB` still untouched, the intended frontier is:

```text
{Partial, KB}
```

So adding a new claim is not enough to settle a conflict. It must consume the whole prior frontier if it is to become the sole current interpretation in a one-claim step.

## Whole-frontier resolution

The full resolution claim has:

```text
Resolve -> {KA, KB}
```

The intended frontier then becomes:

```text
{Resolve}
```

while the ancestry of both sibling branches remains reachable through the resolution node.

## Commands

The Alloy model asks for three witnesses:

```text
explanationSiblingConflict
partialExplanationResolutionStillConflicts
wholeFrontierExplanationResolutionSettles
```

and two checks:

```text
SettlementRequiresWholeExplanationFrontier
WholeResolutionPreservesBothBranches
```

The first check is a small structural law for a step that adds exactly one new claim whose parents are chosen from the prior frontier:

> If that new claim becomes the only frontier node, it must parent the whole prior frontier.

The second checks that the whole-frontier resolution keeps both sibling branches and the original interpretation in its ancestry.

## What this would mean

If the witnesses exist and both checks have no counterexample in the bounded model, then the notable result is not merely another conflict example.

The same shape seen earlier over corrected household meaning has reappeared over **claims about explanation itself**:

```text
sibling revisions
    -> frontier

partial resolution
    -> unresolved frontier

whole-frontier resolution
    -> settled frontier
```

That would suggest the structure is less about a particular household concept and more about correctable interpreted meaning.

It would still be too early to claim a universal theorem. A natural next observation would erase the names “household event” and “explanation claim” entirely and ask whether a generic revision graph captures both as instances.

## Important boundaries

- no learned-time coordinate is varied here;
- no sibling arrival order is given authority;
- no provenance source, trust, evidence, or authority semantics;
- the resolution meaning itself is supplied rather than derived from graph shape;
- one partial and one whole-frontier resolution shape only;
- no claim yet that every correction system must use this graph;
- no general Lean theorem yet.

## Tool choice

**Alloy only.**
