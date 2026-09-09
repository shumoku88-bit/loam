# Repository compression and Lean library seed census - 2026-09

Status: CLOSED

Original baseline main: `6a3e74df53db7828ca62ddfcfe2d265cf01965e9`

Closure main: `ddb6373f15010c71b73970cf6eada4072e71d91b`

This audit follows the completed six-phase Compression Audit. It does not optimize for LOC alone. Its target is fewer independent implementation principles, fewer duplicate authority/read/write paths, and a repository topology whose file boundaries correspond to actual responsibilities.

## Governing rule

Prefer fewer independent implementation principles, not fewer names at any cost.

Do not introduce merely to make the tree look smaller:

- a generic Memory ontology;
- a serializer/schema DSL;
- a generic publisher/transaction framework;
- a global identity service;
- a generic revision/history framework;
- a generic authority/image framework;
- a generic `Utils` dumping ground;
- a directory hierarchy whose only benefit is a lower root-file count.

A successful audit outcome may be **KEEP**. Repeated syntax and small files are pressure to inspect, not proof that boundaries should be merged.

## Closure census

The exact #623 Compression Audit gives the closure production surface:

| Layer | Original recensus | Closure | Delta |
| --- | ---: | ---: | ---: |
| Core | 3,485 / 35 | 3,485 / 35 | **0 / 0** |
| Application | 2,982 / 18 | 2,982 / 18 | **0 / 0** |
| Persistence | 2,040 / 20 | 2,075 / 20 | **+35 / 0** |
| Writer / top-level candidate | 2,608 / 11 | 2,608 / 11 | **0 / 0** |
| Other top-level Lean | 3,127 / 26 | 2,668 / 19 | **-459 / -7** |
| CLI | 2,777 / 17 | 2,745 / 21 | **-32 / +4** |
| TUI | 6,954 / 31 | 6,980 / 32 | **+26 / +1** |
| **Practical subtotal** | **23,973 / 158** | **23,543 / 156** | **-430 / -2** |

Reachability at closure:

| Class | Original recensus | Closure | Delta |
| --- | ---: | ---: | ---: |
| Executable-reachable practical | 23,968 / 157 | 23,543 / 156 | **-425 / -1** |
| Practical-library-only | 5 / 1 | 0 / 0 | **-5 / -1** |
| Candidate but unreachable | 0 / 0 | 0 / 0 | **unchanged zero** |

Non-production support also contracted relative to the original recensus:

- Tests: `9,357 / 63 -> 9,176 / 62`, **-181 lines / -1 file**;
- historical selected Observation Lean: `7,769 / 41 -> 6,094 / 35`, **-1,675 lines / -6 files**.

The important result is not the `-430` practical lines. Every retained practical file is executable-reachable, and the sole old library-only umbrella is gone. The subtraction came from duplicate writer/read/authority paths, graduated research apparatus, one over-separated persistence adapter, and stale topology rather than from deleting live semantics.

## Root topology result

At the start of the file-granularity pass, `Loam/` had 41 root `.lean` files. Closure has 34.

Seven root files left the root for three different reasons:

### MOVE - independent responsibility, wrong physical owner

PR #620 moved four human-input Movement adapters under `Loam/Cli/Movement/` while preserving their file boundaries:

- `MovementEntry.lean` -> `Cli/Movement/Entry.lean`;
- `MovementRelationEntry.lean` -> `Cli/Movement/RelationEntry.lean`;
- `MovementDischargeEntry.lean` -> `Cli/Movement/DischargeEntry.lean`;
- `MovementUi.lean` -> `Cli/Movement/Ui.lean`.

PR #622 moved the recognition-only completion helper:

- `CompletionPrompt.lean` -> `Tui/CompletionPrompt.lean`.

These were topology corrections, not file-count reductions. Their independent contracts remain visible.

### MERGE - no independent boundary remained

PR #621 retired `ActualValidityV2Identity.lean` by absorbing its two V2 representation helpers into its sole production importer, `Persistence/ActualValidityPersistence.lean`, while preserving the public `Loam.ActualValidityV2` helper names.

This was a genuine over-separation: the file existed only as persistence-format compatibility glue.

### RETIRE - stale package surface

PR #623 retired the five-line `Loam/Tui.lean` umbrella. It re-exported only Calendar, Kernel, Runtime, Terminal, and Main while the production TUI had grown to more than thirty modules and the executable already imported `Loam.Tui.Cli` directly.

The closure census confirms that deleting it changed:

```text
Practical-library-only   5 lines / 1 file -> 0 / 0
Candidate unreachable    0 / 0            -> 0 / 0
loamTui executable closure                -> unchanged
```

## File-granularity verdict

**The repository is not suffering from general micro-module fragmentation.**

Small files were inspected by responsibility rather than size. The following remain deliberately small because they own narrow, reusable boundaries:

- `Core/FiniteKeyed.lean`;
- `Persistence/VersionedRows.lean`;
- `Persistence/SiblingStage.lean`;
- TUI editor/session modules;
- `FreshNumberedToken.lean`.

Merging those merely to reduce file count would increase coupling or erase useful proof/ownership boundaries.

The one clear over-separated practical module found by this pass was `ActualValidityV2Identity.lean`, and it was merged in #621.

## Top-level family classification

After #623 the Compression Audit reports 19 non-writer top-level practical files and 11 writer/authority top-level files.

### Review family - KEEP ROOT

Current surface-independent read boundaries:

- `ActualReview`;
- `AttentionReview`;
- `BalanceReview`;
- `BudgetWindowReview`;
- `CapacityReview`;
- `ConditionalBalancePathReview`;
- `CurrentCoverageReview`;
- `CycleBudgetReview`;
- `ScheduledReview`;
- `StockFlowReview`.

A `Loam/Review/` directory would be visually tidy, but at closure it would require broad import/workflow churn without changing dependencies, authority, or semantics. The `*Review` suffix already exposes the family clearly at the architectural root, where multiple frontends consume it.

Classification: **KEEP ROOT** until a semantic dependency reason, not aesthetics, earns a move.

### Publisher / authority family - KEEP ROOT

The top-level write/authority boundaries remain deliberately visible:

- `ActualReversalPublisher`;
- `ActualValidityPublisher`;
- `CapacityPublisher`;
- `CorrectionPublisher`;
- `MovementPublisher`;
- Scheduled creation/replacement/routing/terminal publishers;
- `MovementManifestAuthority`;
- `WriterOwnership`.

Do not create a generic Publisher framework or move `WriterOwnership` / `MovementManifestAuthority` merely for naming symmetry.

Classification: **KEEP ROOT**.

### Config family - GROUP CANDIDATE, DEFER / KEEP ROOT NOW

The three replaceable application/query configurations form a coherent family:

- `BalanceViewConfig`;
- `BoundaryPresetConfig`;
- `CycleFundingConfig`.

All explicitly reject canonical/history authority semantics, and `CycleFundingConfig` already reuses `BalanceViewConfig`'s two-column grammar.

A `Loam/Config/` directory is therefore conceptually valid. It is intentionally **not implemented by this audit** for two reasons:

1. moving these three files would touch many Review, CLI, TUI, test, and workflow import paths while changing no semantic dependency;
2. the current source-surface audit explicitly classifies Core/Application/Persistence/Cli/Tui plus root files, so adding another directory would require changing the census at the same time to avoid a false apparent LOC reduction.

The correct closure decision is not to manufacture churn for a prettier root.

Classification: **KEEP ROOT / DEFER GROUPING UNTIL A REAL CONFIG-SUBSYSTEM CHANGE EARNS IT**.

### Cross-surface singletons - KEEP ROOT

`ActualDate` is used across Persistence, CLI, Review, and TUI for one practical ISO-date convention. Moving it into any one of those layers would make the dependency direction less honest.

`MovementAdmission` is the shared semantic admission boundary consumed by CLI, TUI, manifest authority, Movement publisher, and Scheduled publication. PR #619 specifically removed its old reverse dependency on human-input Entry modules; after that correction, root placement is clearer rather than less clear.

`CycleFundingInspection` is pure composition of shared Balance and CurrentCoverage answers. Its module contract explicitly states why it sits beside Reviews rather than below them in Application, and it has its own semantic tests/workflow.

`Sha256` currently has one production caller, `MovementManifestAuthority`, but it is a self-contained pure FIPS 180-4 implementation with no authority semantics. Absorbing it into the authority file would hide a generic algorithm inside a household boundary. It does not yet pass the multi-caller extraction gate, so it remains a root utility rather than a separate library.

`Cli.lean` remains the executable/wrapper command root.

## Finding 001 - Capacity CLI duplicated the shared writer

Classification: **SHARE INSIDE LOAM - CLOSED**.

PR #608 routed Capacity CLI writes through `CapacityPublisher`, removing the second effective-evidence / fresh-id / entitlement / publication / WriterOwnership orchestration. The CLI change was `+44 / -142`, net `-98` lines.

## Finding 002 - repeated fixed-row framing

Classification: **SHARE INSIDE LOAM - CLOSED**.

PRs #609, #610, #612, and #613 reused the narrow `VersionedRows` outer frame for qualified codecs. Typed row parsing, block semantics, identity admission, legacy refusal, and authority meaning remain domain-local.

**M2 is closed.** Manifest authority images are intentionally not forced through this helper.

## Finding 003 - historical Actual identity / wire-shape apparatus

Classification: **RETIRE AFTER GRADUATION - CLOSED**.

- #611 graduated Observation 149-152 plus the Observation 154 fixture/workflow;
- #614 graduated Observation 147-148.

Research prose and Git history remain. Live executable proof obligations no longer preserve abandoned/migrated candidate machinery indefinitely.

## Finding 004 - Movement sidecar authority fallback

Classification: **RETIRE DUPLICATE AUTHORITY TOPOLOGY - CLOSED**.

PR #615 made the explicit Movement CLI manifest-only and routed publication through the same `MovementPublisher` used by the TUI. Budget Window Actual evidence was also moved to the selected manifest world rather than keeping a live sidecar read topology.

Sidecar-partial-publication-only crash fixtures retired; the underlying relation identity-reservation law remains in semantic admission/formal evidence.

## Finding 005 - broad dead-code deletion stop point

Classification: **STOP**.

Closure reachability is:

```text
Executable-reachable practical   23,543 / 156
Practical-library-only                 0 / 0
Candidate but unreachable              0 / 0
```

There is no remaining repository-wide dead practical surface to justify another broad deletion pass.

## Finding 006 - residual textual mechanics are not generic-framework mandates

Classification: **KEEP DOMAIN-LOCAL UNLESS NARROW DUPLICATION IS PROVEN**.

Retained examples:

- stronger staging/rename protocols in Manifest authority, ActualValidity legacy refusal, and Scheduled lifecycle verification;
- explicit WriterOwnership protocol seams;
- caller-specific absent-storage semantics;
- typed/collision-domain identity policy around `FreshNumberedToken`;
- LOAM-specific managed/unmanaged/unrouted policy in `HistoricalRouting`.

Textual similarity is not sufficient evidence for another abstraction layer.

## Finding 007 - Budget Window duplicated the production read boundary

Classification: **SHARE INSIDE LOAM - CLOSED**.

PR #616 made TUI and standalone CLI share `BudgetWindowReview`. The Review exposes both all-Purpose snapshot loading and an explicit single-Purpose query, preserving the qualified unseen-Purpose `0 / 0 / 0` behavior.

Production Lean fell by 96 lines, and manifest/or-empty loader counts also contracted.

## Finding 008 - Open Scheduled repeated current-open frontier semantics

Classification: **SHARE INSIDE LOAM - CLOSED**.

PR #617 replaced the CLI's second copy of replacement-aware terminal/frontier failure branching with `ScheduledReview.currentOpenRecords`. Presentation sorting/rendering remains CLI-local.

## Finding 009 - DailyQuantity is similar but not equivalent to BalanceReview

Classification: **KEEP / DO NOT COLLAPSE**.

`DailyQuantityCli` retains an explicitly qualified raw-EventMemory diagnostic contract when no Movement manifest root is supplied. `BalanceReview` is the manifest-based production review boundary. Routing one through the other would silently retire a diagnostic contract rather than merely share mechanics.

## Finding 010 - Capacity all-retained read duplicated CapacityReview

Classification: **SHARE INSIDE LOAM - CLOSED**.

PR #618 routed only the all-retained Capacity `show` path through `CapacityReview.loadSnapshot`. The distinct `show-window` temporal query remains on its own Application path. Production Lean fell by 17 lines without broadening the Review boundary.

## Finding 011 - Movement semantic admission depended outward on human-input adapters

Classification: **DEPENDENCY DIRECTION - CLOSED**.

PR #619 moved Relation/Discharge draft ownership into `MovementAdmission`; the human-input Entry modules now build those semantic drafts rather than the admission layer importing presentation adapters.

PR #620 then moved the four now-clearly-presentation-local Movement Entry/UI modules under `Loam/Cli/Movement/` as physical renames.

## Finding 012 - one practical module was genuinely over-separated

Classification: **MERGE - CLOSED**.

PR #621 absorbed `ActualValidityV2Identity.lean` into its sole production persistence owner. This is the audit's example of a legitimate file merge: one representation adapter, one caller, no independent semantic/test boundary worth preserving.

## Finding 013 - presentation helper belonged under TUI

Classification: **MOVE - CLOSED**.

PR #622 moved `CompletionPrompt.lean` to `Tui/CompletionPrompt.lean` as a zero-line rename. Its recognition-only contract remains independent; only physical ownership changed.

## Finding 014 - stale TUI umbrella

Classification: **RETIRE - CLOSED**.

PR #623 retired `Loam/Tui.lean`. It was the sole library-only practical file and no longer represented the production TUI package. The production TUI executable closure was unchanged after deletion.

## Library-seed census

A module is a future extraction candidate only when production use has made its contract stable and extraction would clarify dependencies rather than just move lines.

### Strong internal seeds

#### `Core/FiniteKeyed.lean`

Dependencies: `Init.Data.List.Perm` only.

Owns caller-keyed finite lookup plus permutation invariance under caller-supplied uniqueness evidence. It owns no household Memory, chronology, authority, or winner semantics.

Classification: **LIBRARY SEED / KEEP INTERNAL FOR NOW**.

#### `Application/ReplacementFrontier.lean`

No LOAM imports.

Owns finite source/successor edge structure, endpoint uniqueness, reference closure, acyclicity, supersession, and frontier filtering. ActualValidity, Correction, and Scheduled replacement supply domain adapters.

Classification: **LIBRARY SEED / KEEP INTERNAL FOR NOW**.

### Utility internal seeds

#### `Persistence/VersionedRows.lean`

Owns only exact header + encoded rows + trailing newline outer framing and fail-closed outer decoding.

Classification: **UTILITY SEED / KEEP INTERNAL FOR NOW**.

#### `Persistence/SiblingStage.lean`

Owns only sibling text write + rename and deliberately claims no generic transaction/lock/recovery/durability semantics.

Classification: **UTILITY SEED / KEEP INTERNAL FOR NOW**.

#### `FreshNumberedToken.lean`

Owns deterministic `stem ++ Nat` enumeration under caller-supplied collision predicate/start/fuel. Movement, ActualValidity, Correction, Capacity, and Scheduled supply identity namespaces and collision policy.

Classification: **UTILITY SEED / KEEP INTERNAL FOR NOW**.

### Generic utility, extraction gate not yet met

#### `Sha256.lean`

Pure SHA-256 with no household imports or authority semantics, but currently one production caller. Do not extract merely because it is generic.

Classification: **KEEP INTERNAL / WATCH**.

### Keep LOAM-local

#### `Core/HistoricalRouting.lean`

Its public model still carries `PurposeId` plus managed/unmanaged/unrouted household policy.

Classification: **KEEP LOAM-LOCAL**.

#### `Core/BalancedMovement.lean`

The zero-sum law is reusable, but the public value still carries LOAM `MeasureId` / `Quantity` meaning.

Classification: **KEEP LOAM-LOCAL**.

## Final buckets

### RETIRE

- graduated Observation 147-152 executable apparatus and Observation 154 fixture/workflow;
- Movement sidecar authority fallback and sidecar-only crash fixture topology;
- stale `Loam/Tui.lean` umbrella.

### SHARE INSIDE LOAM

- `VersionedRows` fixed-row outer framing;
- `FreshNumberedToken` candidate enumeration;
- shared Capacity writer/read boundaries;
- shared Movement publisher/manifest authority;
- shared Budget Window Review;
- shared Scheduled current-open Review semantics;
- previously earned `FiniteKeyed`, `ReplacementFrontier`, and `SiblingStage` mechanics.

### KEEP DOMAIN-LOCAL / KEEP ROOT

- specialized authority publication and missing-storage rules;
- DailyQuantity raw-sidecar diagnostic contract;
- Review and Publisher/Authority architectural families;
- Config family until a real subsystem change earns directory churn;
- `ActualDate`, `MovementAdmission`, `CycleFundingInspection`;
- `HistoricalRouting`, `BalancedMovement`.

### LIBRARY SEED

- strong: `FiniteKeyed`, `ReplacementFrontier`;
- utility: `VersionedRows`, `SiblingStage`, `FreshNumberedToken`;
- watch only: `Sha256`.

No standalone Lean library repository is created by this audit.

## Closure rule

This audit is complete because all of the following now hold:

1. candidate-but-unreachable practical source is zero;
2. practical-library-only source is zero;
3. the major qualified duplicate writer/read/framing/authority paths found by the audit were either removed/shared or received explicit KEEP reasons;
4. root topology was reduced where ownership was actually wrong, without merging meaningful small modules;
5. remaining root families have explicit architectural reasons to remain visible;
6. further directory moves now produce more import/workflow churn than semantic/topological gain;
7. internal Lean library seeds are classified without premature extraction.

The next LOAM work should therefore leave cleanup mode. New Report Semantics, canonical vocabulary, and budget-administration work should be evaluated against these retained boundaries rather than preceded by another broad repository-compression pass.
