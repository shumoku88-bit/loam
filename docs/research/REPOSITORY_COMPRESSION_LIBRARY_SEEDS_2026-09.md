# Repository compression and Lean library seed census — 2026-09

Status: ACTIVE

Baseline main: `6a3e74df53db7828ca62ddfcfe2d265cf01965e9`

This audit follows the completed six-phase Compression Audit. It does not reopen settled semantic distinctions or optimize for LOC alone.

## Questions

1. Which current repository surface is still obsolete, duplicated, over-specialized, or research residue?
2. Which repeated mechanics can be shared without erasing fail-closed boundaries, provenance, WriterOwnership, or authority topology?
3. Which already-shared Lean modules have become domain-independent enough to act as future standalone library seeds?
4. Which apparently generic modules should remain LOAM-local because their contract still carries household meaning?

## Governing rule

Prefer fewer independent implementation principles, not fewer names at any cost.

Do not introduce:

- a generic Memory ontology;
- a serializer/schema DSL;
- a generic publisher/transaction framework;
- a global identity service;
- a generic revision/history framework;
- a generic authority/image framework.

## Library-seed gate

A module is a future extraction candidate only when most of the following are true:

1. it has no LOAM-domain imports, or domain imports can disappear without weakening its contract;
2. it already has at least two genuinely different production callers;
3. its theorem/API contract has remained stable through practical use;
4. its tests or proofs state representation-level or mathematical laws rather than household policy;
5. extraction would clarify the dependency graph rather than merely move lines to another repository.

Do not split a new repository merely because a helper is generic. First make the candidate a stable dependency island inside LOAM.

## Initial seed census

### A — strong seed: `Loam/Core/FiniteKeyed.lean`

Current dependencies: `Init.Data.List.Perm` only.

Owns:

- lookup by caller-supplied key projection;
- permutation invariance under caller-supplied `Nodup` evidence.

It explicitly owns no household Memory, authority, chronology, or winner semantics. Multiple semantic memories already consume this mechanic.

Initial classification: **SEED / KEEP INTERNAL FOR NOW**.

### B — strong seed: `Loam/Application/ReplacementFrontier.lean`

Current dependencies: no LOAM imports.

Owns:

- directed source/successor edges;
- endpoint uniqueness;
- reference closure;
- finite acyclicity check;
- superseded-source frontier filtering.

ActualValidity, Event correction, and Scheduled replacement supply their own domain adapters and laws.

Initial classification: **SEED / KEEP INTERNAL FOR NOW**.

### C — utility seed: `Loam/Persistence/VersionedRows.lean`

Current dependency: `Std` only.

Owns only exact header + encoded rows + required trailing newline framing and fail-closed outer decoding.

Initial classification: **UTILITY SEED**, lower extraction priority than mathematical kernels.

### D — utility seed: `Loam/Persistence/SiblingStage.lean`

Current dependency: `Std` only.

Owns only sibling text write + rename. It deliberately makes no transaction, lock, recovery, or durability claim.

Initial classification: **UTILITY SEED**, probably best kept local unless another project earns the same filesystem contract.

### E — not extraction-ready: `Loam/Core/HistoricalRouting.lean`

The historical selection algebra is interesting and shared, but the module currently imports `Loam.Core.Purpose` and bakes `PurposeId` plus managed/unmanaged/unrouted policy into the public model.

Initial classification: **KEEP LOAM-LOCAL**. Do not split a generic temporal-selection kernel until another concrete use earns it.

### F — not extraction-ready: `Loam/Core/BalancedMovement.lean`

The coordinate type is generic and the zero-sum law is reusable, but the public value still imports LOAM `MeasureId` / `Quantity` meaning.

Initial classification: **KEEP LOAM-LOCAL**. A generic additive kernel may eventually emerge, but do not manufacture it for extraction.

### G — utility seed: `Loam/FreshNumberedToken.lean`

Current dependency: `Std` only.

The module owns only deterministic `stem ++ Nat` enumeration under a caller-supplied collision predicate and explicit start/fuel. Identity namespaces, collision domains, typed wrappers, and fuel policy remain caller-local. It already serves Movement, ActualValidity, Correction, Capacity, and Scheduled writers.

Initial classification: **UTILITY SEED / KEEP INTERNAL FOR NOW**. Its cross-domain use is strong evidence, but standalone extraction is not useful until another Lean project needs the same bounded enumeration contract.

## Pass 1 result — current production recensus

Exact measurement head: `dae955004b52833739e62980acbbf16fb1636c69` on this audit branch. The production source itself is identical to baseline main `6a3e74df53db7828ca62ddfcfe2d265cf01965e9`; the head only adds this audit and temporary measurement instrumentation.

The same `tools/audit-production-surface`, `tools/audit-production-reachability`, `tools/audit-semantic-candidates`, and `tools/audit-mechanics-patterns` instruments used by Compression Audit were rerun in exact-head CI.

### Practical source growth since the synchronized Phase 6 snapshot

| Layer | Phase 6 synchronized | Current | Delta |
| --- | ---: | ---: | ---: |
| Core | 3,649 / 33 files | 3,485 / 35 | **-164 / +2** |
| Application | 2,550 / 17 | 2,982 / 18 | **+432 / +1** |
| Persistence | 1,981 / 16 | 2,040 / 20 | **+59 / +4** |
| Writer / top-level candidate | 2,004 / 9 | 2,608 / 11 | **+604 / +2** |
| Other top-level Lean | 2,429 / 18 | 3,127 / 26 | **+698 / +8** |
| CLI | 4,240 / 21 | 2,777 / 17 | **-1,463 / -4** |
| TUI | 4,753 / 23 | 6,954 / 31 | **+2,201 / +8** |
| **Practical subtotal** | **21,606 / 137** | **23,973 / 158** | **+2,367 / +21** |

Reachability changed as follows:

| Class | Phase 6 synchronized | Current | Delta |
| --- | ---: | ---: | ---: |
| Executable-reachable practical | 21,226 / 134 | 23,968 / 157 | **+2,742 / +23** |
| Practical-library-only | 380 / 3 | 5 / 1 | **-375 / -2** |
| Candidate but unreachable | 0 / 0 | 0 / 0 | **unchanged zero** |

The only practical-library-only file is the five-line `Loam/Tui.lean` umbrella. It is an intentional practical library root in the reachability instrument, not evidence of a hidden second TUI implementation.

Tests grew from 6,285 lines at the synchronized Phase 6 note to 9,357 lines / 63 files. Historical selected Observation Lean remains exactly **7,769 lines / 41 files**. The research-proof body therefore did not resume uncontrolled growth while production TUI/report work advanced.

### Interpretation

The current growth is not primarily dead code:

- unreachable practical source remains exactly zero;
- Core is smaller than the Phase 6 synchronized snapshot;
- CLI shrank by 1,463 lines after retiring duplicate human interaction and sidecar write entrances;
- current growth is concentrated in TUI, top-level review/orchestration, publishers, and Application projections.

Therefore this audit should now prioritize **presentation/orchestration/read-projection multiplication**, not another indiscriminate Core deletion pass.

## Finding 001 — Capacity CLI duplicates the shared Capacity writer

Classification: **SHARE INSIDE LOAM — high confidence**.

`Loam/CapacityPublisher.lean` already declares and implements the surface-independent Capacity write boundary. Under `WriterOwnership` it:

- re-reads Capacity authority and effective evidence;
- rejects incomplete cross-stream evidence;
- checks source entitlement;
- allocates a fresh `CapacityMovementId`;
- constructs/admites the balanced JPY movement;
- publishes effective evidence before Capacity authority;
- returns a typed receipt.

The production TUI transfer/rebalance paths and tests already publish through this boundary.

`Loam/Cli/CapacityCli.lean`, however, still independently owns the same write orchestration. It duplicates:

- `effectiveEvidenceComplete`;
- effective-id collision checking;
- `freshCapacityId?`;
- two-endpoint balanced movement construction;
- source-entitlement admission;
- effective-evidence append;
- effective-first / Capacity-second publication;
- its own `WriterOwnership` wrapper around that path.

This is not merely textual duplication. It is a second implementation of the same retained write protocol.

Preferred subtraction:

```text
Capacity CLI prompts / date / text parsing
        -> CapacityPublisher.Draft
        -> CapacityPublisher.publish
        -> CLI rendering of Receipt / Error
```

Keep CLI-only presentation and `show` / `show-window` reads local. Do not introduce a generic publisher framework. Do not change Capacity authority topology or publication order.

This should be implemented and qualified in a separate narrow production PR, not inside the audit PR.

## Audit passes

### Pass 1 — current production recensus

**COMPLETE.** Current growth is quantified above and candidate-unreachable practical source remains zero.

### Pass 2 — residue graduation

Recheck:

- historical Observation code and dedicated workflows;
- stale docs and old production-surface guides;
- prototype or retired entrance tests;
- root wrappers and standalone executables;
- library-only practical files.

Delete only when current production invariants/tests have inherited the verification role.

### Pass 3 — mechanic multiplication

Re-scan current main for narrow repeated mechanics, especially:

- versioned line framing;
- deterministic opaque-id candidate enumeration;
- keyed collection lookup;
- local TUI layout helpers;
- complete-text replacement;
- duplicated read projection or candidate enumeration;
- duplicated frontend write orchestration around an existing publisher.

Finding 001 qualifies the Capacity CLI / CapacityPublisher duplication as the first high-confidence SHARE candidate.

Share only representation mechanics or already-earned surface-independent boundaries. Keep domain collision sets, wire semantics, publication order, and missing-storage meaning local.

### Pass 4 — dependency-island audit

For every seed candidate, record:

- imports;
- callers;
- proof/test contract;
- domain vocabulary leaked into the API;
- whether moving the module would require adapter churn.

The goal is to know what can later become a small Lean package with a nearly mechanical extraction.

### Pass 5 — closure

End with four buckets:

- RETIRE;
- SHARE INSIDE LOAM;
- KEEP DOMAIN-LOCAL;
- LIBRARY SEED.

No standalone library repository is created by this audit.
