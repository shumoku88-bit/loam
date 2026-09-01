# Observation 080 — Can a checking regime be forgotten after the result is known?

## Question

Observation 079 showed that bare status tokens such as `SAT`, `UNSAT`, and workflow `SUCCESS` do not determine what was learned. It also showed, inside Alloy alone, that command mode is part of result interpretation.

LOAM already contains a stronger historical pressure across two different formal regimes.

Observation 042 asked a bounded Alloy model about the generic whole-frontier settlement law. Observation 043 then lifted that law into Lean without a finite node bound.

This observation asks:

> If the claim family and overall workflow success are retained, but the checking regime, scope, and premises are forgotten, is the epistemic result still recoverable?

## Why this is not another new domain model

No new household or revision semantics are introduced here.

The experiment reuses two retained artifacts that already exist on `main`:

```text
model/042_generic_revision_graph.als
Loam/Observation043.lean
```

They are useful precisely because LOAM already used them as two stages of one inquiry.

## The paired law

Observation 042 checks both directions of the bounded settlement equivalence:

```text
sole later frontier
    ->
new revision parents the whole prior frontier

whole prior frontier parented
    ->
sole later frontier
```

Alloy checks those assertions up to its declared finite scope.

Observation 043 states the corresponding equivalence as:

```text
SoleFrontier parent known newNode
    <->
ConsumesWholeFrontier parent known newNode
```

for an arbitrary `Node` type, under explicit premises including freshness, parent closure, parent selection from the prior frontier, and decidability of the new-node parent relation.

## Two receipts that must not collapse

The same law family therefore has two materially different formal receipts.

### Alloy receipt

```text
regime:      bounded counterexample search
commands:    assertion checks
raw result:  UNSAT counterexample
scope:       up to 6 Revision / 4 View
meaning:     no counterexample found in that bounded scope
```

This is not an unbounded proof.

### Lean receipt

```text
regime:      theorem elaboration / kernel checking
raw result:  accepted theorem
scope:       no finite Node bound
premises:    explicit theorem hypotheses, including parent decidability
meaning:     theorem established under those premises
```

This is not merely another spelling of Alloy `UNSAT`.

## Experiment

Observation 080 runs both retained artifacts again in one dedicated workflow.

The workflow must:

1. execute the Observation 042 Alloy model with Alloy 6.2.0 + Sat4j;
2. require the generic witness to remain SAT;
3. require both settlement-direction assertions to remain UNSAT for counterexamples in their declared bounded scope;
4. compile `Loam/Observation043.lean` with the repository Lean toolchain;
5. report one workflow `SUCCESS` only when both distinct formal receipts match those expectations.

The workflow intentionally does not translate either result into a generic `Proof`, `Evidence`, or `CheckReceipt` object.

## Expected boundary

If both tools succeed, then the following compression is unsafe for future interpretation:

```text
claim family + SUCCESS
```

because it loses at least:

```text
checking regime
bounded scope or theorem premises
formal interpretation of the raw result
```

The result should therefore extend Observation 079 from command-mode context to cross-tool regime context without yet designing a common cross-tool schema.

## Non-goals

This observation does not claim:

- that Alloy and Lean statements are definitionally identical;
- that one tool is stronger or more trustworthy in every use;
- that every Alloy result should later be proved in Lean;
- that `Tool` or `CheckingRegime` deserves a Practical Core type;
- that a universal semantic-OS `CHECK` primitive has been earned;
- that workflow `SUCCESS` is useless operationally.

The question is only whether later semantic interpretation survives after the regime-specific context is projected away.

## Practical Core impact

None.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no revision-model change;
- no theorem change;
- no generic proof-object change.
