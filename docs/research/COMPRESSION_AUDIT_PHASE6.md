# Compression audit Phase 6 — complexity comparison and closure

Status: **AUDIT COMPLETE — REPRODUCIBLE COMPLEXITY REPORT**

This document concludes the six-phase compression audit tracked by Issue #535 and grounded by `COMPRESSION_AUDIT_CHECKPOINT_226.md`.

## Summary of the audit arc

| Phase | Core question | Result |
| --- | --- | --- |
| **Phase 1: Production surface** | What is the real size of the practical implementation before judgment? | 21,226 lines reachable across 134 files; 11 candidate unreachable files (1,155 lines); 6 practical-library-only files (676 lines). |
| **Phase 2: Retained meaning** | What is the irreducible semantic basis of household operation? | 18 retained fact/policy families across ~9 physical authority instances. |
| **Phase 3: Mechanics multiplication** | Is implementation size driven by repeated mechanics? | M1–M9 classified: 4 narrow mechanical sharing candidates identified; generic ontologies/DSL frameworks rejected; positive controls (`ReplacementFrontier`, `RoutingHistory`, `WriterOwnership`) confirmed. |
| **Phase 4: Dead production surface** | Which practical files no longer participate in active authority or entrances? | 4 files immediately retired (427 lines); 10 archive-linked residue files identified for Phase 5 cut; library-only surface classified. |
| **Phase 5: Research & CI graduation** | How to stop the historical laboratory apparatus without losing history? | Repeatable graduation rule established; QuantityBasis/BasisCut generation and AccountingRole persistence graduated: 30 files / 3,660 lines deleted, 10 workflows retired. |
| **Phase 6: Complexity comparison** | How did repository complexity change, and why? | Comprehensive before/after accounting below. |

---

## Before / after complexity metrics

### 1. Practical production source surface

| Metric | Checkpoint 226 baseline | Post-audit snapshot | Net change |
| --- | ---: | ---: | ---: |
| **Candidate practical lines** | **23,057** | **21,567** | **-1,490 lines (-6.5%)** |
| **Candidate practical files** | **151** | **137** | **-14 files (-9.3%)** |
| Executable-reachable practical lines | 21,226 | 21,226 | 0 lines (100% preserved) |
| Executable-reachable practical files | 134 | 134 | 0 files (100% preserved) |
| **Unreachable candidate lines** | **1,155** | **0** | **-1,155 lines (-100%)** |
| **Unreachable candidate files** | **11** | **0** | **-11 files (-100%)** |
| Practical-library-only lines | 676 | 341 | -335 lines (-49.6%) |
| Practical-library-only files | 6 | 3 | -3 files (-50.0%) |

All unreachable practical candidate modules have been completely eliminated from the repository.

### 2. Breakdown of practical source by layer

| Layer | Baseline lines (files) | Post-audit lines (files) | Reduction | Rationale |
| --- | ---: | ---: | ---: | --- |
| Core | 4,171 (38) | 3,649 (33) | -522 lines (-5 files) | Retired unwired numeric kernels (`Rate`, `Allocation`, `RecipientAssignment`) & `QuantityBasis` memories |
| Application | 2,876 (20) | 2,511 (17) | -365 lines (-3 files) | Retired `BasisCut`, `CurrentQuantity`, `QuantityBasisFrontier` |
| Persistence | 2,313 (20) | 1,981 (16) | -332 lines (-4 files) | Retired `QuantityBasis`, `BasisCut`, `AccountingRole` persistence |
| Top-level writer candidates | 2,004 (9) | 2,004 (9) | 0 lines (0 files) | Retained explicit publisher modules |
| Other top-level Lean | 2,521 (19) | 2,429 (18) | -92 lines (-1 file) | Retired `ScheduledCompletionUi` shell |
| CLI | 4,419 (22) | 4,240 (21) | -179 lines (-1 file) | Retired `QuantityBasisCorrectionCli` |
| TUI | 4,753 (23) | 4,753 (23) | 0 lines (0 files) | Retained active production TUI |
| Tests | 6,296 (48) | 6,182 (47) | -114 lines (-1 file) | Retired unneeded `AccountingRolePersistence` test |
| Observations (Lean) | 8,117 (42) | 7,769 (41) | -348 lines (-1 file) | Graduated `Observation145` proof |

### 3. Total repository deletions

Across the entire audit (Phases 4 & 5):

- **34 files deleted**;
- **4,087 lines removed**;
- **10 dedicated GitHub Actions workflows retired**;
- **Zero broken imports or broken tests** (`lake build` clean, all 16 practical Python integration tests pass in ~4s).

---

## Semantic basis vs implementation surface

The audit confirmed the primary hypothesis:

> LOAM retains a compact semantic information basis (18 fact/policy families across ~9 physical authorities), while the practical implementation surface (21,567 lines) reflects the explicit representation, validation, fail-closed codecs, and TUI/CLI interactions needed for real household operations.

Crucially, Phase 3 proved that compressing this implementation surface into fewer "grand abstractions" would be counter-productive:

- Generic `Memory α` would obscure domain uniqueness laws (`ScheduledCompletion` 2-endpoint uniqueness, `RoutingHistory` 2-coordinate uniqueness, `LocusAdmission` finite vocabulary);
- Generic serializer DSLs would hide observable fail-closed wire contracts;
- Generic transaction monads would obscure exact multi-authority publication orders (e.g. Scheduled lifecycle before Movement generation);
- Generic missing-storage policies would dangerously conflate permitted-empty provenance with missing-authority error.

Instead, the audit identified 4 narrow, safe representation-level sharing opportunities for future work:
1. `List.lookup` with permutation-invariance proof helper;
2. Versioned line-image framing helper;
3. Sibling text stage-and-rename replacement helper;
4. Deterministic opaque-ID candidate linear search helper.

---

## Research & CI lifecycle policy

The graduation rule established in Phase 5 provides an enduring governance policy:

1. **Active research**: dedicated experimental probes and CI workflows are encouraged while a hypothesis is open;
2. **Integrated law**: once qualified, production invariants and tests take over verification responsibility;
3. **Superseded history**: when a later invariant replaces the practical role of an observation, the executable probe and dedicated CI workflow graduate to prose and Git history, preventing dead code accumulation.

---

## Audit closure

All six phases are **COMPLETE**. The compression audit in PR #534 / Issue #535 has met all exit conditions without compromising semantic precision, fail-closed safety, provenance, or writer ownership.
