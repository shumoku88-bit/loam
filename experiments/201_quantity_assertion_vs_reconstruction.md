# Observation 201 — Does reconstructed history determine a physical quantity assertion?

Status: **F086 completed — COUNTEREXAMPLE / RESEARCH_ONLY**

## Question

F086 asks about a physical or externally observed quantity that conflicts with the quantity reconstructed from retained history.

LOAM already has work on external-source provenance and reconciliation, but this specimen is more primitive. Before asking whether an assertion is reconciled, authoritative, or repaired into history, ask whether the assertion itself is information already contained in the reconstructed history.

The selected question is:

> If retained history and its reconstructed quantity are fixed, can a physical/external quantity assertion still differ and therefore change whether a conflict is observed?

## Candidate compression under attack

A too-small candidate says:

```text
retained history
  -> reconstructed quantity
  -> current quantity knowledge
```

That silently assumes a physical count or external quantity assertion carries no information beyond the history-derived result.

F086 attacks that assumption directly.

## Why Alloy

This is an information-independence question, not an arithmetic one.

The observation deliberately abstracts away the summation mechanics. `LedgerHistory.reconstructed` stands for the deterministic projection already produced from retained history. Both worlds share the exact same `LedgerHistory` atom, so they necessarily share the same reconstructed quantity.

Only the independently observed assertion may differ.

## Observation-local vocabulary

```text
LedgerHistory
Quantity
World

history.reconstructed : Quantity
world.asserted        : Quantity
```

Two specimen quantities are enough:

```text
Q10
Q8
```

The names are arbitrary bounded values, not production denominations or account balances.

The selected conflict view is:

```text
conflict(world)
  iff
world.asserted != world.history.reconstructed
```

## Selected probes

### 1. Representative conflict

Can two worlds share exactly the same retained history and reconstructed quantity while one assertion agrees and the other assertion conflicts?

Representative bounded shape:

```text
reconstructed = Q10

Left.asserted  = Q10  -> no conflict
Right.asserted = Q8   -> conflict
```

Expected: **SAT**.

### 2. Same history, different assertion

Can equal retained history coexist with different physical/external assertions?

Expected: **SAT**.

### 3. Same reconstruction, different conflict answer

Can the reconstructed quantity be identical while the selected conflict query differs?

Expected: **SAT**.

## Deliberately too-strong checks

### History determines physical assertion

Does equal retained history force the same assertion?

Expected check result: **SAT counterexample**.

### Reconstructed quantity determines conflict

Does equal reconstructed quantity force the same conflict answer?

Expected check result: **SAT counterexample**.

## Positive sufficiency check

### Explicit assertion + retained history determine the conflict view

Once both the retained history and the explicit assertion are fixed, can the selected conflict answer still differ?

Expected counterexample: **UNSAT**.

## Executed result

Alloy 6.2.0 + Sat4j produced exactly the selected matrix:

```text
representativeConflict                         SAT
sameHistoryDifferentAssertion                  SAT
sameReconstructionDifferentConflict            SAT
HistoryDeterminesPhysicalAssertion             SAT counterexample
ReconstructedQuantityDeterminesConflict        SAT counterexample
ExplicitAssertionAndHistoryDetermineConflict   UNSAT counterexample
```

The central witness keeps the retained history and reconstructed quantity identical while the independently observed assertion changes from agreement to disagreement.

## Finding

The bounded information boundary is:

```text
reconstructed history
    !=
physical / external quantity assertion
```

and:

```text
same retained history + same reconstructed quantity
    -/->
same observed quantity knowledge
```

An explicit assertion can therefore carry information that reconstruction alone does not contain. Once retained history and the explicit assertion are both fixed, the selected conflict answer has no remaining degree of freedom.

F086 closes as:

```text
Work     DONE
Finding  COUNTEREXAMPLE
Runtime  RESEARCH_ONLY
```

This does **not** say which value is true or authoritative when they disagree. The earned result is only the independence of the assertion evidence for this query.

## Boundaries

Observation 201 does not establish:

- a production `BalanceAssertion`, `Count`, or `Reconciliation` type;
- that a physical/external assertion overrides retained history;
- that reconstructed history overrides an assertion;
- automatic adjustment Events;
- repair or padding of missing history;
- trust ranking among sources;
- assertion revision over time (F085);
- broker/institution holding semantics (F087);
- whether a discrepancy should remain unknown or be repaired (F088);
- multi-assertion conflict resolution;
- persistence, CLI, TUI, or household-data changes.

The observation intentionally preserves epistemic conflict instead of resolving it.

Runtime remains `RESEARCH_ONLY`. Production waits for real dogfood pressure.
