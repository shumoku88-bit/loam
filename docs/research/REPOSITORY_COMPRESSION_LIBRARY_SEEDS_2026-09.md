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

## Audit passes

### Pass 1 — current production recensus

Re-run practical reachability and layer inventory against current main. Compare with the frozen Phase 6 closure snapshot rather than rewriting historical metrics.

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
- duplicated read projection or candidate enumeration.

Share only representation mechanics. Keep domain collision sets, wire semantics, publication order, and missing-storage meaning local.

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
