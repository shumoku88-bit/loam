# Observation 042 — Can the Revision Graph Be Generic?

## Question

Observation 041 reproduced the same sibling-conflict / frontier / whole-resolution shape one level above household meaning, over claims about explanation itself.

This observation removes those layer names entirely.

> If we retain only revisions, parentage, and a known-set view, does the same frontier / settlement law remain?

The candidate memory is deliberately small:

```text
Revision identity
  + parent : Revision -> set Revision

View
  + known : set Revision
```

No household event kind, explanation kind, meaning, purpose, quantity, account, locus, measure, valuation, source, authority, timestamp, or winner rule appears in the model.

## Why Alloy

The immediate question is still structural and finite: whether the law survives after removing the domain names that motivated it.

Alloy is the smallest tool for testing arbitrary bounded graph shapes and looking for counterexamples.

Lean is deliberately deferred until this generic bounded check succeeds. If it does, the resulting law is finally small and domain-independent enough to justify preserving as a theorem.

J, TLA+, and miniKanren do not add a distinct answer to this static graph question.

## Generic projection

For a view `v`, the current frontier is:

```text
frontier(v) = known(v) - known(v).parent
```

A one-revision step adds exactly one new revision `r` whose parents are chosen from the prior frontier:

```text
r not in prior.known
later.known = prior.known + r
r.parent subset frontier(prior)
```

The prior view is closed under parentage, so already-known revisions do not point to unknown parents.

## Concrete witness

A five-revision witness asks only for this shape:

```text
        left
       /
root --
       \
        right

partial -> left
settle  -> {left, right}
```

and checks that:

```text
fork frontier       = {left, right}
partial frontier    = {partial, right}
settled frontier    = {settle}
```

The names are only structural positions inside the witness, not domain roles.

## Generic bounded laws

The model then checks three laws over arbitrary bounded graphs rather than only the witness shape.

### 1. Sole frontier requires the whole prior frontier

If one new revision becomes the only frontier node after a one-revision step, then its parent set must equal the whole prior frontier.

### 2. The whole prior frontier is sufficient to settle

Conversely, if the new revision parents the entire prior frontier, then it becomes the sole new frontier.

Together these say, under the one-step assumptions:

```text
frontier(later) = {r}
    iff
r.parent = frontier(prior)
```

### 3. Whole settlement preserves prior ancestry

For a closed acyclic prior graph, if the new revision settles the whole frontier, every previously known revision remains reachable in the new revision's parent ancestry.

This distinguishes resolution from destructive winner-selection. Settlement can make one current tip without erasing the branches that led to it.

## Observed Alloy result

Alloy 6.2.0 + Sat4j produced:

```text
genericForkPartialAndSettlement               SAT
SoleFrontierRequiresWholePriorFrontier        UNSAT
WholePriorFrontierIsEnoughToSettle            UNSAT
WholeSettlementPreservesPriorKnownAncestry    UNSAT
```

The witness exists, and no counterexample was found for any of the three generic laws in scopes up to 6 `Revision` atoms and 4 `View` atoms.

So the layer names were not carrying the frontier / settlement behavior. The bounded structure survives with only revision identity, parentage, and a known-set view.

The first two checks combine into the bounded equivalence:

```text
frontier(later) = {r}
    iff
r.parent = frontier(prior)
```

for one-revision steps from a parent-closed prior view.

The ancestry check also survived: with an acyclic prior graph, whole-frontier settlement makes one current tip while retaining every previously known revision in that tip's ancestry.

This is the first point in the observation sequence where the law is both domain-independent in statement and small enough to merit an unbounded proof attempt.

## Interpretation

Observations 022, 023, 041, and 042 now line up around the same structure:

```text
revision graph
  -> frontier

partial frontier consumption
  -> unresolved multiplicity

whole frontier consumption
  -> one current tip
  -> prior branches remain ancestry
```

This does not prove every correction system in reality must use this graph. It shows that the LOAM observations no longer need household or explanation vocabulary to state the structural law.

Lean now has a distinct role: preserve the whole-frontier settlement equivalence, and possibly the ancestry result, without a finite scope bound.

## Important boundaries

- parentage is treated as the revision relation under study;
- only one-revision additions are considered;
- the prior view is parent-closed;
- ancestry preservation additionally assumes acyclicity;
- no temporal arrival or learned-time coordinate appears;
- no resolution meaning is derived from graph shape;
- no provenance authority, trust, evidence, or source semantics;
- no claim yet that this is the final storage schema;
- bounded Alloy success is not itself an unbounded mathematical proof.

## Tool choice

**Alloy only for Observation 042.** The generic bounded laws survived, so Lean is now justified as a separate next observation.
