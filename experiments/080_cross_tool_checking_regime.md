# Observation 080 — Can a checking regime be forgotten after the result is known?

## Question

Observation 079 showed that bare status tokens such as `SAT`, `UNSAT`, and workflow `SUCCESS` do not determine what was learned. It also showed, inside Alloy alone, that command mode is part of result interpretation.

LOAM already contains a stronger historical pressure across different formal regimes.

Observation 042 asked a bounded Alloy model about generic whole-frontier settlement and ancestry laws. Observation 043 lifted the settlement equivalence into Lean without a finite node bound. Observation 044 then found an infinite Lean counterexample to an ancestry generalization that had no counterexample in Observation 042's finite Alloy scope.

This observation asks:

> If the claim family and overall workflow success are retained, but the checking regime, scope, and premises are forgotten, is the epistemic result still recoverable?

## Why this is not another new domain model

No new household or revision semantics are introduced here.

The experiment reuses three retained artifacts that already exist on `main`:

```text
model/042_generic_revision_graph.als
Loam/Observation043.lean
Loam/Observation044.lean
```

They are useful precisely because LOAM already used them as successive stages of one inquiry.

## Case A — bounded support that later becomes an unbounded theorem

Observation 042 checks both directions of the bounded settlement equivalence:

```text
sole later frontier
    ->
new revision parents the whole prior frontier

whole prior frontier parented
    ->
sole later frontier
```

Alloy found no counterexample for either assertion in the declared finite scope, up to 6 `Revision` atoms and 4 `View` atoms.

Observation 043 states the corresponding equivalence as:

```text
SoleFrontier parent known newNode
    <->
ConsumesWholeFrontier parent known newNode
```

for an arbitrary `Node` type, under explicit premises including freshness, parent closure, parent selection from the prior frontier, and decidability of the new-node parent relation.

The two receipts are materially different:

```text
Alloy:
  bounded assertion check + UNSAT counterexample
  -> no counterexample found in the declared finite scope

Lean:
  accepted theorem source
  -> theorem checked without a finite Node bound under explicit premises
```

Observation 043 did not merely rename the Alloy result. It strengthened the epistemic status by establishing a theorem under an explicit theorem contract.

## Case B — bounded support that fails to generalize

Observation 042 also checked:

```text
WholeSettlementPreservesPriorKnownAncestry
```

under acyclicity and the one-revision-step conditions.

The bounded Alloy result was:

```text
UNSAT counterexample
```

within the declared finite scope.

If that result token were retained without its regime and scope, it would be easy to misread it as support for an unrestricted law.

Observation 044 demonstrates why that compression is unsafe. Lean constructs an infinite old chain and proves:

```text
acyclicityAloneDoesNotPreserveAncestry
```

The counterexample is acyclic, parent-closed, uses a fresh settlement node, consumes the whole prior frontier vacuously, and still fails to preserve all prior-known nodes in the new tip's ancestry.

Observation 044 then identifies the missing unbounded condition as `FrontierCovered`, proving:

```text
AllPriorKnownInAncestry
    <->
FrontierCovered
```

under exact whole-frontier settlement and the stated parent condition.

So the stronger historical witness is:

```text
bounded Alloy: no counterexample found
        !=
unbounded claim established
```

and, in this concrete LOAM history, the attempted generalization is actually false.

## Executed experiment

Observation 080 runs the retained artifacts together in one dedicated workflow.

The first exact-head execution required:

```text
genericForkPartialAndSettlement                 SAT
SoleFrontierRequiresWholePriorFrontier          UNSAT counterexample
WholePriorFrontierIsEnoughToSettle              UNSAT counterexample
WholeSettlementPreservesPriorKnownAncestry      UNSAT counterexample
```

and then successfully:

```text
lake build
leanchecker
axiom-audit
lake env lean Loam/Observation043.lean
```

The workflow was then tightened to re-check `Loam/Observation044.lean` explicitly as well.

No new translation layer is inserted between Alloy and Lean. The workflow deliberately keeps their interpretations separate.

## Result

Observation 080 earns another negative boundary:

> A formal result cannot safely shed its checking regime, bounded scope, or theorem premises merely because the claim family and workflow status are retained.

Observation 079 established:

```text
raw result
    !=
semantic interpretation
```

Observation 080 extends that pressure across tools:

```text
claim family + SUCCESS
    !=
what was established
```

The concrete reason is not only that Alloy and Lean use different result words. Their checking contracts answer different epistemic questions.

For the settlement equivalence, bounded counterexample search and theorem checking agree directionally but establish different strengths.

For ancestry preservation, the finite Alloy scope hides an infinite counterexample that Lean can state and verify directly.

Therefore a future human/AI work surface that needs to revisit formal results must retain enough context to distinguish at least the relevant checking regime and the conditions under which its result should be interpreted.

## What this does not earn

This result does **not** yet earn a universal schema such as:

```text
CheckReceipt
Tool
CheckingRegime
Proof
Evidence
SemanticOS.Check
```

It also does not establish one universal minimal set of receipt fields. Observation 079 already showed that retained information should be relative to the later question being asked.

The current result only rules out a lossy compression that would identify bounded Alloy success, Lean theorem acceptance, and workflow success as one context-free semantic fact.

## Practical Core impact

None.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no revision-model change;
- no theorem change;
- no generic proof-object change.

## Next pressure

Do not build a cross-tool checking framework yet.

The next useful question should come from another concrete place where a human or AI needs to *reuse* a retained formal result. Only then ask which coordinates must survive for that later use.
