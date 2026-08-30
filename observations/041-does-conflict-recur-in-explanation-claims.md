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

So the conflict view is:

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

With `KB` still untouched, the frontier is:

```text
{Partial, KB}
```

So adding a new claim is not enough to settle a conflict. It must consume the whole prior frontier if it is to become the sole current interpretation in a one-claim step.

## Whole-frontier resolution

The full resolution claim has:

```text
Resolve -> {KA, KB}
```

The frontier then becomes:

```text
{Resolve}
```

while the ancestry of both sibling branches remains reachable through the resolution node.

## Observed Alloy 6.2.0 + Sat4j results

Exact bounded scope:

```text
exactly 5 Claim
exactly 3 Meaning
exactly 4 View
```

Observed commands:

```text
explanationSiblingConflict                  SAT
partialExplanationResolutionStillConflicts SAT
wholeFrontierExplanationResolutionSettles  SAT
SettlementRequiresWholeExplanationFrontier UNSAT counterexample
WholeResolutionPreservesBothBranches       UNSAT counterexample
```

The first witness confirms that sibling corrections of the same explanation interpretation recreate a two-node frontier.

The second confirms that superseding only one sibling does not settle the conflict: the untouched sibling remains current beside the new partial claim.

The third confirms that a claim whose parents are the entire prior frontier can become the sole current interpretation.

The `SettlementRequiresWholeExplanationFrontier` check found no counterexample to the small structural law used here:

> In a step that adds exactly one claim whose parents are chosen from the prior frontier, if the new claim becomes the sole frontier node, it must parent the whole prior frontier.

`WholeResolutionPreservesBothBranches` also found no counterexample: both sibling corrections and their common original interpretation remain in the resolution node's ancestry.

## Interpretation

The notable result is not merely another conflict example.

The same shape seen earlier over corrected household meaning has reappeared over **claims about explanation itself**:

```text
sibling revisions
    -> frontier

partial resolution
    -> unresolved frontier

whole-frontier resolution
    -> settled frontier
```

No explanation-specific conflict mechanism was added. The result follows from the same graph projection:

```text
frontier = known - known.parent
```

This strengthens the suspicion that frontier / resolution is less about a particular household concept and more about the structure of correctable interpreted meaning.

It is still too early to call that a universal theorem. The next clean pressure is to erase the names “household event” and “explanation claim” entirely and ask whether one generic revision graph captures both as instances. If that abstraction survives, a Lean statement may finally be worth preserving.

## CI plumbing note

Two initial runs failed before the solver could answer the semantic question because `after` and then `before` were used as identifiers. Alloy 6 reserves both as temporal-language keywords. They were renamed to neutral identifiers without changing the model's meaning.

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
