# Legacy Capacity Persistence Retirement Audit

Date: 2026-09-18
Status: Approved & Executed

## Audit Question

> Canonical migration が完了した現在、旧 two-file persistence (`capacity.loam` + `capacity.loam.effective`) を残すことでしか守れない production property はまだ存在するか？

## Conclusion: NO

There are no production properties that require keeping the legacy two-file persistence.
All production properties are either preserved or strengthened by operating exclusively on the normalized single-file authority (`capacity.loam`).

### Property-by-Property Analysis

1. **Semantic Separation of Movement and Effective Date**
   - **Principle**: `CapacityMovement` and `CapacityEffective` are distinct retained domain concepts. Effective date must never be derived from movement fields.
   - **Status**: Completely preserved. `Loam.Core.CapacityMemory` and `Loam.Core.CapacityEffective` remain independent core structures. `Loam.CapacityEvidence` aggregates them without unifying their types or modifying `CapacityMovement`.

2. **Atomic Publication & Recovery Semantics**
   - **Former Two-File Protocol**: Required writing `.effective` first, then `capacity.loam`. If the second write failed, an inert orphan effective entry was left behind, requiring explicit manual recovery.
   - **Normalized Single-File Protocol**: Performs off-authority staging (`.loam-stage`), verifies typed re-decoding, and executes an atomic filesystem rename over `capacity.loam`. This eliminates the possibility of orphan effective state or half-written pairs.

3. **Identity Allocation & Continuity**
   - **Status**: Identity allocation (`freshCapacityId`) computes across both `CapacityMovement` and `CapacityEffective` memory in `CapacityEvidence`. It does not rely on filesystem splitting.

4. **Canonical Data Status**
   - **Status**: Canonical household repository `loam-data` (PR #110 merged at `f49aba369ef9947eb52fb4cda4fa2e0192645473`) has already migrated to `LOAM-NORMALIZED-CAPACITY 1` (25 movements, 25 effective dates, 1-to-1 correspondence) and removed `capacity.loam.effective`.
   - Git history serves as the historical archive; keeping migration scaffolding in the active production tree is unnecessary.

5. **Writer Behavior**
   - **Status**: Production writers (`Loam.CapacityPublisher.publish`, `publishBalanced`) already target `CapacityAuthority.publishImage?`, publishing only the single normalized image without producing `.effective` sidecars.

## Retirement Actions

1. **Production `CapacityAuthority` Legacy Fallback Removal**
   - Removed `loadLegacyRequired` and companion file lookup (`.effective`).
   - `CapacityAuthority.loadExisting` now fail-closed decodes only normalized `capacity.loam` via `Loam.Persistence.decodeNormalizedCapacity?`.

2. **Retired Modules and Workflows**
   - Removed `Loam/Persistence/CapacityPersistence.lean`
   - Removed `Loam/Persistence/CapacityEffectivePersistence.lean`
   - Removed `Loam/Tests/CapacityEffectivePersistence.lean`
   - Removed `Loam/Tests/NormalizedCapacityDogfood.lean`
   - Removed `.github/workflows/practical-capacity-effective-persistence.yml`
   - Removed `testLegacyCutover` from `Loam/Tests/CapacityPublisher.lean`

3. **Fixture and Test Modernization**
   - `Loam/Tests/NormalizedCapacityPersistence.lean`: Updated to directly test normalized serialization, round-trip fidelity, date syntax checks, unbalanced movement rejection, and refusal of legacy headers without importing legacy modules.
   - `Loam/Tests/CapacityDogfood.lean`: Updated to test normalized persistence round-trip and validation on `CapacityEvidence`.
   - `Loam/Tests/BudgetWindowReview.lean`: Updated to publish normalized `capacity.loam` via `CapacityAuthority.publishImage?`.
   - `Loam/Tests/CurrentCoverageReview.lean`: Updated to publish normalized `capacity.loam` and test failure modes directly against normalized syntax and missing authority.
   - `Loam/Tests/CycleBudgetReview.lean`: Updated to seed normalized `capacity.loam` and test independence on missing `capacity.loam`.
   - `Loam/Tests/TuiCycleGrant.lean`: Updated fixture to single-file `LOAM-NORMALIZED-CAPACITY 1`.
   - `tests/test_cycle_budget_tui.py`: Updated PTY test fixture to single-file `LOAM-NORMALIZED-CAPACITY 1`.

4. **Workflow and Path Cleanup**
   - `.github/workflows/capacity-publisher.yml`: Removed retired persistence paths.
   - `.github/workflows/practical-capacity.yml`: Updated paths to `NormalizedCapacityPersistence.lean` and `CapacityAuthority.lean`; added assertions verifying single-file normalized output, absence of `.effective` sidecar, and `show-window` CLI execution.
   - `.github/workflows/practical-slice-b.yml`: Updated paths.
   - `.github/workflows/tui.yml`: Updated paths.

5. **Verification**
   - Re-ran `rg` across the codebase confirming that no legacy wire formats, functions, or retired file references remain on the production/test surface.
