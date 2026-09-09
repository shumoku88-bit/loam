# Repository compression and Lean library seed census - 2026-09

Status: ACTIVE

Original baseline main: `6a3e74df53db7828ca62ddfcfe2d265cf01965e9`

Current recensus main: `a84f9442fbbdcbfdc73edbe78a5ac870fc301dfa`

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

A successful audit outcome may be **KEEP**. Repeated syntax is pressure to inspect, not proof that two semantic boundaries should be merged.

## Library-seed gate

A module is a future extraction candidate only when most of the following are true:

1. it has no LOAM-domain imports, or domain imports can disappear without weakening its contract;
2. it already has at least two genuinely different production callers;
3. its theorem/API contract has remained stable through practical use;
4. its tests or proofs state representation-level or mathematical laws rather than household policy;
5. extraction would clarify the dependency graph rather than merely move lines to another repository.

Do not split a new repository merely because a helper is generic. First make the candidate a stable dependency island inside LOAM.

## Seed census

### A - strong seed: `Loam/Core/FiniteKeyed.lean`

Current dependencies: `Init.Data.List.Perm` only.

Owns:

- lookup by caller-supplied key projection;
- permutation invariance under caller-supplied `Nodup` evidence.

It explicitly owns no household Memory, authority, chronology, or winner semantics. Multiple semantic memories already consume this mechanic.

Classification: **SEED / KEEP INTERNAL FOR NOW**.

### B - strong seed: `Loam/Application/ReplacementFrontier.lean`

Current dependencies: no LOAM imports.

Owns:

- directed source/successor edges;
- endpoint uniqueness;
- reference closure;
- finite acyclicity check;
- superseded-source frontier filtering.

ActualValidity, Event correction, and Scheduled replacement supply their own domain adapters and laws.

Classification: **SEED / KEEP INTERNAL FOR NOW**.

### C - utility seed: `Loam/Persistence/VersionedRows.lean`

Current dependency: `Std` only.

Owns only exact header + encoded rows + required trailing newline framing and fail-closed outer decoding.

Since the original census, the narrow framing mechanic was reused by Scheduled, EventMemory, ActualValidity, and EventCorrection without moving their typed decoding, block semantics, legacy refusal, or domain admission into a generic serializer.

Classification: **UTILITY SEED / KEEP INTERNAL FOR NOW**. Main PRs #609, #610, #612, and #613 strengthen the evidence that the boundary is correctly narrow.

### D - utility seed: `Loam/Persistence/SiblingStage.lean`

Current dependency: `Std` only.

Owns only sibling text write + rename. It deliberately makes no transaction, lock, recovery, or durability claim.

Classification: **UTILITY SEED / KEEP INTERNAL FOR NOW**.

The current mechanics scan still finds `.loam-stage` / rename operations in `MovementManifestAuthority`, `ActualValidityPersistence`, and `ScheduledLifecyclePersistence`. These are not automatically missing SiblingStage callers: each retained boundary carries stronger authority, legacy-refusal, staged-byte verification, or commit-image semantics. Do not broaden SiblingStage into a generic transaction layer merely to reduce the textual count.

### E - not extraction-ready: `Loam/Core/HistoricalRouting.lean`

The historical selection algebra is interesting and shared, but the module currently imports `Loam.Core.Purpose` and bakes `PurposeId` plus managed/unmanaged/unrouted policy into the public model.

Classification: **KEEP LOAM-LOCAL**. Do not split a generic temporal-selection kernel until another concrete use earns it.

### F - not extraction-ready: `Loam/Core/BalancedMovement.lean`

The coordinate type is generic and the zero-sum law is reusable, but the public value still imports LOAM `MeasureId` / `Quantity` meaning.

Classification: **KEEP LOAM-LOCAL**. A generic additive kernel may eventually emerge, but do not manufacture it for extraction.

### G - utility seed: `Loam/FreshNumberedToken.lean`

Current dependency: `Std` only.

The module owns only deterministic `stem ++ Nat` enumeration under a caller-supplied collision predicate and explicit start/fuel. Identity namespaces, collision domains, typed wrappers, and fuel policy remain caller-local. It serves Movement, ActualValidity, Correction, Capacity, and Scheduled writers.

Classification: **UTILITY SEED / KEEP INTERNAL FOR NOW**. Cross-domain use is strong evidence, but standalone extraction is not useful until another Lean project needs the same bounded enumeration contract.

## Pass 1 result - original production recensus

Original exact measurement head: `dae955004b52833739e62980acbbf16fb1636c69` on this audit branch. The production source at that point was identical to original baseline main `6a3e74df53db7828ca62ddfcfe2d265cf01965e9`.

The same `tools/audit-production-surface`, `tools/audit-production-reachability`, `tools/audit-semantic-candidates`, and `tools/audit-mechanics-patterns` instruments used by Compression Audit were rerun in exact-head CI.

### Practical source growth since the synchronized Phase 6 snapshot

| Layer | Phase 6 synchronized | Original recensus | Delta |
| --- | ---: | ---: | ---: |
| Core | 3,649 / 33 files | 3,485 / 35 | **-164 / +2** |
| Application | 2,550 / 17 | 2,982 / 18 | **+432 / +1** |
| Persistence | 1,981 / 16 | 2,040 / 20 | **+59 / +4** |
| Writer / top-level candidate | 2,004 / 9 | 2,608 / 11 | **+604 / +2** |
| Other top-level Lean | 2,429 / 18 | 3,127 / 26 | **+698 / +8** |
| CLI | 4,240 / 21 | 2,777 / 17 | **-1,463 / -4** |
| TUI | 4,753 / 23 | 6,954 / 31 | **+2,201 / +8** |
| **Practical subtotal** | **21,606 / 137** | **23,973 / 158** | **+2,367 / +21** |

Original reachability:

| Class | Phase 6 synchronized | Original recensus | Delta |
| --- | ---: | ---: | ---: |
| Executable-reachable practical | 21,226 / 134 | 23,968 / 157 | **+2,742 / +23** |
| Practical-library-only | 380 / 3 | 5 / 1 | **-375 / -2** |
| Candidate but unreachable | 0 / 0 | 0 / 0 | **unchanged zero** |

The only practical-library-only file was and remains the five-line `Loam/Tui.lean` umbrella. It is an intentional practical library root in the reachability instrument, not evidence of a hidden second TUI implementation.

At the original recensus, Tests were 9,357 lines / 63 files and historical selected Observation Lean was 7,769 lines / 41 files.

### Original interpretation

The growth was not primarily dead code:

- unreachable practical source was exactly zero;
- Core was smaller than the Phase 6 synchronized snapshot;
- CLI had already shrunk substantially after retiring duplicate human interaction and sidecar write entrances;
- current growth was concentrated in TUI, top-level review/orchestration, publishers, and Application projections.

The audit therefore prioritized presentation/orchestration/read-projection multiplication rather than another indiscriminate Core deletion pass.

## Pass 1 refresh - after subtraction stack through #616

The audit branch was refreshed from current main `a84f9442fbbdcbfdc73edbe78a5ac870fc301dfa`. Exact-head Compression Audit run 163 completed successfully after the refresh.

Between the original recensus and current main, production changes #608 through #616 implemented several candidates while keeping the audit open.

### Current exact surface

| Layer | Original recensus | Current main | Delta |
| --- | ---: | ---: | ---: |
| Core | 3,485 / 35 | 3,485 / 35 | **0 / 0** |
| Application | 2,982 / 18 | 2,982 / 18 | **0 / 0** |
| Persistence | 2,040 / 20 | 2,038 / 20 | **-2 / 0** |
| Writer / top-level candidate | 2,608 / 11 | 2,608 / 11 | **0 / 0** |
| Other top-level Lean | 3,127 / 26 | 3,176 / 26 | **+49 / 0** |
| CLI | 2,777 / 17 | 2,332 / 17 | **-445 / 0** |
| TUI | 6,954 / 31 | 6,954 / 31 | **0 / 0** |
| **Practical subtotal** | **23,973 / 158** | **23,575 / 158** | **-398 / 0** |

Current reachability:

| Class | Original recensus | Current main | Delta |
| --- | ---: | ---: | ---: |
| Executable-reachable practical | 23,968 / 157 | 23,570 / 157 | **-398 / 0** |
| Practical-library-only | 5 / 1 | 5 / 1 | **0 / 0** |
| Candidate but unreachable | 0 / 0 | 0 / 0 | **unchanged zero** |

Non-production support also contracted:

- Tests: `9,357 / 63 -> 9,176 / 62`, **-181 lines / -1 file**;
- historical selected Observation Lean: `7,769 / 41 -> 6,094 / 35`, **-1,675 lines / -6 files**.

### Refresh interpretation

This is evidence for **subtraction by authority and implementation principle**, not merely LOC shaving:

- practical source fell by 398 lines while every practical candidate remains reachable;
- CLI fell by 445 lines while top-level Review/other Lean grew by only 49 lines, consistent with moving one semantic boundary into shared production ownership rather than cloning it per frontend;
- Core and Application did not need to shrink to obtain the reduction;
- narrow row-framing reuse changed Persistence by only two net lines, consistent with keeping domain decoding/admission local rather than building a serializer framework;
- historical proof apparatus was graduated after its obligations were inherited, rather than kept indefinitely as a second verification surface.

## Finding 001 - Capacity CLI duplicated the shared Capacity writer

Classification: **SHARE INSIDE LOAM - IMPLEMENTED / CLOSED**.

The original audit found that `Loam/CapacityPublisher.lean` already owned the surface-independent Capacity write boundary while `Loam/Cli/CapacityCli.lean` independently repeated effective-evidence checks, fresh ids, balanced movement construction, entitlement admission, publication order, and WriterOwnership.

PR #608, `refactor(capacity): route CLI writes through shared publisher`, implemented the preferred subtraction:

```text
Capacity CLI prompts / date / text parsing
        -> CapacityPublisher.Draft
        -> CapacityPublisher.publish
        -> CLI rendering of Receipt / Error
```

The Capacity CLI change itself was `+44 / -142`, net **-98 lines**, without changing Capacity authority topology or introducing a generic publisher framework.

Audit conclusion: the original classification was correct and the narrow production PR retired a genuine second writer implementation.

## Finding 002 - repeated fixed row framing

Classification: **SHARE INSIDE LOAM - IMPLEMENTED / CLOSED**.

The original pass identified versioned line framing as repeated mechanics but explicitly rejected a serializer/schema ontology.

Current main now routes the repeated outer frame through `VersionedRows` in the remaining qualified fixed-row cases:

- #609 `refactor(scheduled): share versioned row framing`;
- #610 `refactor(event): share EventMemory row framing`;
- #612 `refactor(persistence): close repeated row framing` for ActualValidity and EventCorrection;
- #613 `refactor(persistence): finish fixed row framing`.

Typed row parsing, block/chunk semantics, identity admission, legacy refusal, and authority meaning remain in their domain modules.

Audit conclusion: **M2 is closed**. Do not broaden `VersionedRows` further merely because other persistence modules contain newlines.

## Finding 003 - historical Actual identity / wire-shape apparatus

Classification: **RETIRE AFTER GRADUATION - IMPLEMENTED / CLOSED**.

Current main graduated historical proof/test apparatus after production obligations had inherited its verification role:

- #611 graduated Observation 149-152 and the Observation 154 production fixture/workflow;
- #614 graduated Observation 147-148 identity migration Lean apparatus.

The exact recensus records the result as **-1,675 historical Observation lines / -6 files** plus **-181 test lines / -1 file** relative to the original audit census.

Audit conclusion: research code remains valuable while it carries obligations, but it should not become permanent parallel production machinery after those obligations are published elsewhere.

## Finding 004 - Movement sidecar authority fallback

Classification: **RETIRE DUPLICATE AUTHORITY TOPOLOGY - IMPLEMENTED / CLOSED**.

PR #615 retired the second Movement sidecar publication backend from the explicit line CLI. The line CLI now publishes through `MovementPublisher` against selected manifest authority, and the retained read-only Budget Window projection obtains Event + ActualValidity from the same selected Movement manifest world rather than requiring retired Movement sidecars.

Open Relation / Relation Discharge practical stories and WriterOwnership qualification were moved to the manifest topology. A sidecar-only partial-publication crash fixture was retired while the underlying relation identity-reservation semantic law remained retained.

Audit conclusion: this was larger than helper sharing. It removed a second authority topology while preserving low-level diagnostic codecs and independent Capacity / routing / correction boundaries.

## Finding 005 - current unreachable practical source remains zero

Classification: **KEEP / STOP BROAD DEAD-CODE DELETION**.

The refreshed reachability census still reports:

```text
Candidate but unreachable    0 lines / 0 files
```

The only practical-library-only file is the intentional five-line `Loam/Tui.lean` umbrella.

Audit conclusion: another repository-wide "delete everything not obviously central" pass is not justified. Future retirement should be evidence-driven: obsolete entrance, superseded authority, graduated research obligation, or proven duplicate implementation.

## Finding 006 - residual mechanics pressure is mostly semantic boundary pressure

Classification: **KEEP DOMAIN-LOCAL UNLESS A NARROW DUPLICATION IS PROVEN**.

The refreshed mechanics smoke scan now reports, among other indicators:

- `.loam-stage` / stage-path pressure: 6 occurrences across 4 files;
- filesystem rename: 6 occurrences across 5 files;
- path-existence branches: 51 occurrences across 27 files;
- WriterOwnership: 33 occurrences across 13 files;
- manifest current-world load: 24 occurrences across 17 files;
- or-empty loaders: 22 occurrences across 10 files;
- fresh-identity textual pressure: 130 occurrences across 11 files;
- `ReplacementFrontier` use: 13 occurrences across 4 files;
- `RoutingHistory` use: 89 occurrences across 13 files.

These counts are not a mandate to build generic frameworks.

Current stop rules:

- `SiblingStage` stays narrow; manifest commit, ActualValidity legacy refusal, and Scheduled lifecycle staged verification remain local;
- WriterOwnership stays an explicit protocol seam rather than becoming a generic transaction framework;
- manifest current-world loads may be shared through existing authority/read boundaries, but caller-specific projection and failure semantics stay local;
- or-empty loaders must not be unified unless the missing-storage meaning is actually identical;
- `FreshNumberedToken` already owns candidate enumeration; collision domains and typed identity policy stay with each caller;
- `HistoricalRouting` remains LOAM-local despite broad use because its public contract still carries household routing meaning.

The remaining high-value search area is therefore **duplicated read projection / review orchestration and frontend plumbing**, not raw textual pattern elimination.

## Finding 007 - Budget Window CLI duplicated the production read boundary

Classification: **SHARE INSIDE LOAM - IMPLEMENTED / CLOSED**.

The audit found that TUI already consumed `BudgetWindowReview.loadSnapshot`, while the standalone `loamBudgetWindow` CLI independently repeated the same canonical evidence loading and projection:

- Capacity and CapacityEffective;
- selected Movement manifest world;
- ActualValidity frontier admission;
- absent-as-empty EventCorrection;
- ActualRouting;
- Purpose projection;
- Entitlement, Consumption, and Remaining derivation.

PR #616, `refactor(report): share Budget Window read boundary`, removed that second reader. `BudgetWindowReview` now owns one evidence loader and exposes:

- `loadSnapshot` for the remembered-Purpose set used by TUI/all-Purpose presentation;
- `loadPurposeRow` for one explicit Purpose used by the line CLI.

The explicit query deliberately preserves the prior behavior that a valid Purpose absent from Capacity history may still produce exact `0 / 0 / 0` when the evidence snapshot is complete.

Exact-head qualification passed Compression Audit, Practical Budget Window Report, Production TUI, and Selected Lean Observations. Production Lean changed by **-96 lines** overall:

- `BudgetWindowCli`: `+36 / -180`;
- `BudgetWindowReview`: `+72 / -24`.

The mechanics recensus also moved in the expected direction:

- manifest current-world loads: `25 / 18 -> 24 / 17`;
- or-empty loaders: `24 / 11 -> 22 / 10`;
- RoutingHistory textual use: `91 / 14 -> 89 / 13`.

Audit conclusion: this was not code motion from CLI to Review. One canonical evidence reader replaced two frontend-specific implementations while preserving both TUI all-Purpose semantics and explicit CLI zero-Purpose semantics.

## Audit passes

### Pass 1 - current production recensus

**COMPLETE AND REFRESHED.** Current practical subtotal is 23,575 lines / 158 files; candidate-unreachable practical source remains zero.

### Pass 2 - residue graduation

**PARTIALLY COMPLETE.**

Completed during this audit window:

- stale TUI production surface guidance was retired before the original baseline;
- Observation 149-152 and Observation 154 fixture/workflow graduated in #611;
- Observation 147-148 graduated in #614;
- sidecar-only Movement relation crash/identity fixture topology graduated in #615.

Still inspect narrowly:

- root wrappers and standalone executables;
- any historical workflow whose obligation is now inherited by current production CI;
- old documents that still describe superseded authorities or entrances.

### Pass 3 - mechanic multiplication

**MAJOR ITEMS COMPLETE; READ/ORCHESTRATION REVIEW REMAINS.**

Completed or already shared:

- versioned fixed-row framing -> `VersionedRows`, M2 closed;
- deterministic opaque-id candidate enumeration -> `FreshNumberedToken`;
- keyed collection lookup -> `FiniteKeyed`;
- local terminal column geometry/padding -> shared TUI geometry work before this baseline;
- complete-text sibling replacement -> `SiblingStage`, with semantic stop points retained;
- duplicated Capacity frontend writer -> #608 closed;
- duplicated Movement sidecar writer/authority path -> #615 closed;
- duplicated Budget Window frontend reader -> #616 closed.

Continue with:

- duplicated read projection where a production Review boundary already exists;
- repeated review/orchestration that can share an already-earned read boundary;
- frontend plumbing that reconstructs semantics already published by Application or authority modules.

### Pass 4 - dependency-island audit

**ACTIVE.** For every seed candidate, record:

- imports;
- callers;
- proof/test contract;
- domain vocabulary leaked into the API;
- whether moving the module would require adapter churn.

The current evidence strengthens `FiniteKeyed` and `ReplacementFrontier` as mathematical/internal seeds and `VersionedRows`, `SiblingStage`, and `FreshNumberedToken` as utility/internal seeds. None currently earns a standalone repository.

### Pass 5 - closure

End with four buckets:

- RETIRE;
- SHARE INSIDE LOAM;
- KEEP DOMAIN-LOCAL;
- LIBRARY SEED.

No standalone library repository is created by this audit.
