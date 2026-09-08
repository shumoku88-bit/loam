# Compression audit Phase 4 — dead production surface

Status: **IN PROGRESS — FIRST RETIREMENT APPLIED**

Phase 3 closed without earning a large architectural rewrite. It found only narrow reusable mechanics and explicitly rejected generic Memory, serializer, transaction, identity-service, revision-framework, and authority-framework designs.

Phase 4 now asks a simpler question:

> Which practical-source files are no longer needed by any current executable, current authority, or intentionally retained practical library boundary?

A file may be dead to production while still imported by historical experiments or dedicated historical CI. That does not make it current production. It means physical removal may need to be coordinated with Phase 5 research/CI compression so the archived evidence remains understandable without forcing obsolete production modules to stay alive forever.

## Phase 1 starting set

Phase 1 identified:

```text
11 candidate practical files unreachable from executable and practical-library roots
6 practical-library-only files not reached by any executable
```

The first 11 were:

```text
Loam/Application/BasisCut.lean
Loam/Application/CurrentQuantity.lean
Loam/Application/QuantityBasisFrontier.lean
Loam/Cli/QuantityBasisCorrectionCli.lean
Loam/Core/QuantityBasisCorrectionMemory.lean
Loam/Core/QuantityBasisMemory.lean
Loam/Persistence/AccountingRolePersistence.lean
Loam/Persistence/BasisCutPersistence.lean
Loam/Persistence/QuantityBasisCorrectionPersistence.lean
Loam/Persistence/QuantityBasisPersistence.lean
Loam/ScheduledCompletionUi.lean
```

## D4.1 — retire `ScheduledCompletionUi` immediately

Repository-wide search found no importer or consumer of `Loam/ScheduledCompletionUi.lean`; the only search result was the file itself.

The module contained only presentation-local values:

```text
Obligation
Action
Progress
action / actionLabel
obligations / obligationLabel
```

It was not canonical state, Application semantics, persistence, a practical-library entry point, or current TUI code.

**Decision: `RETIRE NOW`.**

The audit branch deletes `Loam/ScheduledCompletionUi.lean`.

This is the first concrete production subtraction from the audit.

## D4.2 — QuantityBasis / BasisCut implementation is production-retired, archive-linked

Nine of the eleven unreachable files form the old QuantityBasis/BasisCut path:

```text
Core/QuantityBasisMemory
Core/QuantityBasisCorrectionMemory
Application/QuantityBasisFrontier
Application/CurrentQuantity
Application/BasisCut
Persistence/QuantityBasisPersistence
Persistence/QuantityBasisCorrectionPersistence
Persistence/BasisCutPersistence
Cli/QuantityBasisCorrectionCli
```

Current production reachability is zero for the whole cluster.

Observation 219 independently established on real household data that:

- all five retained household QuantityBasis values were exact zero;
- no basis corrections or cuts existed in canonical data;
- the stable QuantityBasis identities were not observed outside `basis.loam`;
- all practical household balance answers had exact parity under explicit finite zero-origin coverage;
- negative controls preserved `missing != exact zero`;
- reconstructed Event history already retained the opening quantity evidence that mattered.

Production now contains `ZeroOriginCoverage` and current balance readers no longer reach the QuantityBasis/BasisCut path.

So the semantic decision is no longer open:

**Decision: `RETIRE FROM PRODUCTION`.**

However physical deletion is coupled to historical research cleanup. At least:

- `experiments/091_scoped_origin_projection.lean` imports the old QuantityBasis Core module;
- the Observation 218 workflow explicitly builds `Loam.Application.QuantityBasisFrontier`;
- additional historical experiments/documents discuss the retired mechanism as evidence.

Those references belong to research history, not current production authority. Phase 5 should decide the smallest way to preserve the historical claim while removing the obsolete production modules and dedicated CI obligation.

Until that Phase 5 cut, the nine files remain physically present but are classified as **archive-linked production residue**, not live production capability.

## D4.3 — AccountingRole persistence is unwired production residue

`Loam/Persistence/AccountingRolePersistence.lean` is unreachable from every executable and from the practical-library root closure.

Its remaining repository references are a dedicated persistence test and a dedicated workflow. The Core `AccountingRole` relation itself is a different question: it is practical-library-only and remains relevant to the provisional report research boundary.

Therefore persistence and Core must not be conflated.

**Decision for `AccountingRolePersistence`: `RETIRE FROM PRODUCTION`, physical removal deferred to Phase 5 together with its dedicated test/workflow.**

**Decision for `Core/AccountingRole`: not decided by this finding; keep as library/research vocabulary until the library-only pass below.**

## Why Phase 4 does not delete archive-linked residue yet

The ordered audit deliberately separates production retirement from research/CI compression.

Deleting old production modules while leaving historical Lean experiments and workflows broken would not be compression; it would be damage. Conversely, keeping dead production code forever because a historical observation imports it would make the research archive an accidental production dependency.

The intended cut is:

```text
Phase 4: decide what is no longer production
Phase 5: preserve the historical evidence in a cheaper form and remove its dedicated live-CI burden
then: physically delete the archive-linked production residue
```

## Remaining Phase 4 work

Audit the six practical-library-only files individually:

```text
Loam/Application/ScheduledCommitmentInspection.lean
Loam/Core/AccountingRole.lean
Loam/Core/Allocation.lean
Loam/Core/Rate.lean
Loam/Core/RecipientAssignment.lean
Loam/Tui.lean
```

For each, decide one of:

- `KEEP LIBRARY`: intentionally reusable current vocabulary/mechanic;
- `REWIRE`: should be part of a current executable/library entrance but is accidentally disconnected;
- `RETIRE`: no current production/library role remains;
- `DEFER RESEARCH`: current value is research-only and should move out of the practical production closure when Phase 5 reshapes the archive.

Also re-run the production reachability inventory after each physical deletion so Phase 6 can compare exact before/after surface rather than estimating savings.
