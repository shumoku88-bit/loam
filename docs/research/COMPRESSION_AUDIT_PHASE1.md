# Compression audit Phase 1 — production surface

Status: **COMPLETE — PHYSICAL + REACHABILITY BASELINE**

Current main baseline after the Scheduled lifecycle authority cut: `5d3c136b6e9fe119e2d0e2d1ba9365eb4b03812a`.

Phase 1 answers a deliberately narrow question: what source surface participates in the current practical implementation before any semantic judgment is made about whether that surface is necessary?

The repeatable inventory commands are:

```sh
bash tools/audit-production-surface
python3 tools/audit-production-reachability
```

The `Compression Audit` workflow runs both commands in CI. Their output is the evidence for the physical and import-reachability inventory.

## Reproduced physical inventory

The successful CI inventory against current main reported:

| Surface | Lines | Files |
| --- | ---: | ---: |
| Core | 4,171 | 38 |
| Application | 2,876 | 20 |
| Persistence | 2,313 | 20 |
| writer/top-level candidates | 2,004 | 9 |
| other top-level Lean requiring classification | 2,521 | 19 |
| CLI | 4,419 | 22 |
| TUI | 4,753 | 23 |
| Tests | 6,296 | 48 |
| Historical observations | 8,117 | 42 |
| practical subtotal before reachability filtering | **23,057** | **151** |

This materially supports the original concern that the practical implementation is not obviously small even after tests and historical observation proofs are excluded.

It also corrects the earlier ~25.3k / 156-file audit input for the current main snapshot. The two inventories are not directly interchangeable because the original grouping used a broader writer/top-level and CLI classification and, critically, main changed during the audit: PR #533 merged the complete Scheduled lifecycle authority cut. That commit retired legacy Scheduled mutation CLI writers and standalone sidecar authority APIs.

Therefore the audit records both facts rather than choosing the more dramatic number:

```text
pre-#533 review input       ~25.3k / 156 practical files
post-#533 reproducible scan 23,057 / 151 candidate practical files
```

The reduction is evidence that destructive compression is real and can materially shrink production surface. It does not establish that the remaining surface is minimal.

## Import reachability

Tracing repository-local Lean imports from every `lean_exe` root and from the explicit practical library roots (`Loam.Core`, `Loam.Application`, `Loam.Persistence`, `Loam.Tui`) gives:

| Reachability class | Lines | Files |
| --- | ---: | ---: |
| executable-reachable practical | **21,226** | **134** |
| practical-library-only | **676** | **6** |
| candidate practical but unreachable | **1,155** | **11** |
| candidate practical total | **23,057** | **151** |

No `Loam.Tests` or `Loam.Observations` module is reached from an executable root. The 21,226-line executable closure therefore cannot be explained away as historical proof/test code accidentally entering the runtime graph.

### Practical-library-only modules

These six are retained by a practical umbrella but not reached by any current executable root:

- `Loam/Application/ScheduledCommitmentInspection.lean`
- `Loam/Core/AccountingRole.lean`
- `Loam/Core/Allocation.lean`
- `Loam/Core/Rate.lean`
- `Loam/Core/RecipientAssignment.lean`
- `Loam/Tui.lean`

This is not a deletion verdict. Phase 2 must determine whether the first five carry independent current semantic meaning or are merely retained library surface. `Loam/Tui.lean` is an umbrella and should not be interpreted as an independent domain concept.

### Present but unreachable candidate practical modules

These eleven are reached by neither a current executable nor an explicit practical library root:

- `Loam/Application/BasisCut.lean`
- `Loam/Application/CurrentQuantity.lean`
- `Loam/Application/QuantityBasisFrontier.lean`
- `Loam/Cli/QuantityBasisCorrectionCli.lean`
- `Loam/Core/QuantityBasisCorrectionMemory.lean`
- `Loam/Core/QuantityBasisMemory.lean`
- `Loam/Persistence/AccountingRolePersistence.lean`
- `Loam/Persistence/BasisCutPersistence.lean`
- `Loam/Persistence/QuantityBasisCorrectionPersistence.lean`
- `Loam/Persistence/QuantityBasisPersistence.lean`
- `Loam/ScheduledCompletionUi.lean`

The concentration around QuantityBasis / BasisCut is significant because the current README already describes the former QuantityBasis / BasisCut production path as historical research provenance rather than current household balance authority. Phase 4 is the first phase allowed to turn this reachability result into deletion/move decisions.

## Top-level write/authority surface is active

All nine top-level files initially classified as writer/authority candidates are executable-reachable:

- `Loam/ActualValidityPublisher.lean`
- `Loam/CapacityPublisher.lean`
- `Loam/CorrectionPublisher.lean`
- `Loam/MovementManifestAuthority.lean`
- `Loam/MovementPublisher.lean`
- `Loam/ScheduledCreationPublisher.lean`
- `Loam/ScheduledReplacementPublisher.lean`
- `Loam/ScheduledTerminalPublisher.lean`
- `Loam/WriterOwnership.lean`

Therefore the publisher/write-path concern is not primarily historical residue. It is part of the current executable closure and must be judged semantically and mechanically in Phases 2–3.

Among the remaining top-level practical files, `Loam/ScheduledCompletionUi.lean` is unreachable and `Loam/Tui.lean` is practical-library-only; the rest are executable-reachable.

## Executable roots and wrapper exposure

`lakefile.lean` exposes 15 executable targets.

The main `tools/loam` wrapper directly references eight:

- `loam`
- `loamMovement`
- `loamCapacity`
- `loamDailyQuantity`
- `loamOpenScheduled`
- `loamShadowAudit`
- `loamShadowQuantity`
- `loamTui`

Seven remain standalone Lake targets, not referenced by the main wrapper:

- `loamActualRouting`
- `loamScheduledRouting`
- `loamBudgetWindow`
- `loamScheduledSuppression`
- `loamJournalExport`
- `loamShadowDay`
- `loamShadowScheduledDay`

`STANDALONE` means only that the main wrapper does not expose the target. It does not imply obsolescence; some may remain useful diagnostic or qualification entrances. Their role belongs to the later dead-surface audit.

## Per-executable closure pressure

For orientation, the largest current executable closure is the production TUI:

```text
loamTui  15,985 lines / 106 practical files
```

The primary `loam` executable reaches 8,440 lines / 56 files. These numbers are transitive import closure, not unique code owned by each frontend and not evidence that the TUI reimplements those semantics. In fact, sharing causes a frontend to inherit a broad closure. They are useful as coupling measurements, not duplication measurements.

## Phase 1 judgment

Phase 1 supports four conclusions:

1. **The practical implementation is materially large relative to LOAM's own compression goal.** Even after excluding tests, historical observations, and unreachable candidate files, the current executable closure is 21,226 lines across 134 files.
2. **Some production-address residue is real.** Eleven candidate practical files are unreachable, with most belonging to the already historical QuantityBasis / BasisCut path.
3. **Residue does not explain most of the size.** All nine current top-level writer/authority candidates are executable-reachable. The central write-path complexity is live.
4. **Physical size still does not answer semantic necessity.** Phase 1 deliberately makes no claim that 134 files represent 134 concepts, or that active publishers can safely be unified.

The defensible next question is therefore no longer “is the count inflated by tests or dead files?” It is:

> How many independently retained meanings and genuinely distinct mechanisms are represented by the 21,226-line / 134-file executable closure?

That is Phase 2.

## Exit rule

**Satisfied.** Physical counts, executable roots, practical-library reachability, unreachable candidate modules, and top-level writer/authority reachability are now mechanically reproducible. No production deletion has been performed in Phase 1.
