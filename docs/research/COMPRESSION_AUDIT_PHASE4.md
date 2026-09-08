# Compression audit Phase 4 — dead production surface

Status: **COMPLETE — LIVE / LIBRARY / ARCHIVE RESIDUE SEPARATED**

Phase 3 closed without earning a large architectural rewrite. It found only narrow reusable mechanics and explicitly rejected generic Memory, serializer, transaction, identity-service, revision-framework, and authority-framework designs.

Phase 4 asks:

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

## D4.1 — `ScheduledCompletionUi`: RETIRED NOW

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

**Decision: `RETIRE`.**

The audit branch deletes `Loam/ScheduledCompletionUi.lean`.

## D4.2 — QuantityBasis / BasisCut: RETIRE FROM PRODUCTION, ARCHIVE-LINKED

Nine of the unreachable files form the old QuantityBasis/BasisCut path:

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
- stable QuantityBasis identities were not observed outside `basis.loam`;
- practical household balance answers had exact parity under explicit finite zero-origin coverage;
- negative controls preserved `missing != exact zero`;
- reconstructed Event history already retained the opening quantity evidence that mattered.

Production now contains `ZeroOriginCoverage` and current balance readers no longer reach the QuantityBasis/BasisCut path.

**Decision: `RETIRE FROM PRODUCTION`.**

Physical deletion is deferred only because historical research still imports the old modules. At least:

- `experiments/091_scoped_origin_projection.lean` imports old QuantityBasis Core;
- Observation 218 CI explicitly builds `Loam.Application.QuantityBasisFrontier`;
- additional historical experiments/documents discuss the retired mechanism as evidence.

These references are archive obligations, not current authority. Phase 5 must preserve the historical claim more cheaply and then delete the nine production-residue modules.

## D4.3 — AccountingRole persistence: RETIRE FROM PRODUCTION, ARCHIVE/TEST-LINKED

`Loam/Persistence/AccountingRolePersistence.lean` is unreachable from every executable and from the practical-library root closure.

Its remaining code references are a dedicated persistence test and dedicated workflow. Core `AccountingRole` is a separate question and must not be deleted merely because its persistence adapter is unwired.

**Decision for `AccountingRolePersistence`: `RETIRE FROM PRODUCTION`.**

Physical deletion is deferred to Phase 5 together with the dedicated test/workflow.

## Library-only classification

### `Loam/Application/ScheduledCommitmentInspection.lean` — KEEP LIBRARY

This module is intentionally exported by `Loam.Application` and carries qualified replacement-aware Scheduled Commitment and Headroom projections. Dedicated current tests/workflows exercise it even though no executable currently calls it.

It is therefore a **qualified library capability**, not dead production residue.

**Decision: `KEEP LIBRARY`.**

Do not rewire an executable merely to make reachability statistics prettier.

### `Loam/Core/AccountingRole.lean` — DEFER RESEARCH

Repository search finds no current production consumer of `AccountingRoleMap`. The persistence adapter is unwired. However the open provisional Report Lab is actively investigating an Accounting View, and earlier household/report observations earned the five-role vocabulary as a qualified candidate boundary.

Deleting the semantic vocabulary while that current research question is open would prejudge Phase 5/report work.

**Decision: `DEFER RESEARCH`.**

Keep it in the audit branch for now. Phase 5 should decide whether report research owns it, current production earns it again, or it moves out of Practical Core.

### `Loam/Core/Rate.lean` — RETIRED

Repository-wide code search found no consumer beyond `Loam/Core.lean` itself. `Rate.ofRat` had no repository use.

**Decision: `RETIRE`.**

The audit branch removes its `Core.lean` import and deletes the module.

### `Loam/Core/Allocation.lean` — RETIRED

The only code consumer was `RecipientAssignment`; no current executable, application, publisher, or report uses the numeric allocation kernel.

**Decision: `RETIRE`.**

The audit branch removes its `Core.lean` import and deletes the module.

### `Loam/Core/RecipientAssignment.lean` — RETIRED

Repository-wide code references were its own module and the Practical Core umbrella; other references were historical research prose.

**Decision: `RETIRE`.**

The audit branch removes its `Core.lean` import and deletes the module.

Research documents remain as historical evidence that this candidate numeric infrastructure was explored.

### `Loam/Tui.lean` — KEEP LIBRARY

This is a five-line package umbrella importing TUI Calendar, Kernel, Runtime, Terminal, and Main. The production executable imports its concrete TUI modules directly, so the umbrella itself is library-only.

Its size is negligible and its package-entry role is clear.

**Decision: `KEEP LIBRARY`.**

Deleting an intentional five-line package umbrella would optimize the metric rather than the design.

## Phase 4 concrete subtraction so far

Deleted from the audit branch:

```text
Loam/ScheduledCompletionUi.lean
Loam/Core/Rate.lean
Loam/Core/Allocation.lean
Loam/Core/RecipientAssignment.lean
```

Adjusted:

```text
Loam/Core.lean
  - no longer imports Rate
  - no longer imports Allocation
  - no longer imports RecipientAssignment
```

Archive-linked production residue classified for Phase 5 deletion:

```text
9 QuantityBasis / BasisCut files
1 AccountingRole persistence file
+ their dedicated historical/test CI dependencies
```

## Phase 4 conclusion

The first dead-surface audit does not support deleting every non-executable module.

It reveals four distinct states:

```text
LIVE EXECUTABLE
KEEP LIBRARY
DEFER RESEARCH
RETIRE / ARCHIVE-LINKED RESIDUE
```

That distinction prevents both failure modes:

- keeping unused code forever because it once proved something;
- deleting qualified reusable semantics merely because the current CLI/TUI has not wired them yet.

The next phase is now well-scoped:

> compress historical research and dedicated CI enough that archive-linked production residue can actually be deleted rather than merely declared dead.
