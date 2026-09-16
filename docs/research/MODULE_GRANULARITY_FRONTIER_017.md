# MGA-017 — Module granularity frontier after Generation 2

Status: **COMPLETE — ReportWindow SPLIT_CANDIDATE; Transactions Flow SPLIT_CANDIDATE deferred**

Baseline:

```text
df197aff19648ceb838b11ed997d14535133ff11
docs(audit): close Generation 2 at G2-034 (#979)
```

Generation 2 is closed. This document continues only the separate physical-module
question:

> Do current Lean files still align with independent reasons to change, reuse,
> qualify, or own presentation/effect behavior?

The current inventory remains:

```text
Lean modules: 335
Modules <= 80 lines: 92
Modules with exactly one local consumer: 54
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
```

These numbers select candidates. They do not authorize a split.

## Frontier ranking

The first post-G2 frontier combines size/declaration density, fan-out, one-consumer
chains, current ownership evidence, and prior MGA coverage. The useful top ten are:

| Candidate | Inventory signal | Initial MGA-017 reading |
|---|---|---|
| `Loam.Tui.Reports` | 1214 lines / 103 decls / fan-out 13 | **FOCUSED SPLIT CANDIDATE** |
| `Loam.Tui.Cli` | 1067 / 30 / fan-out 58 | already calibrated composition root; inspect only concrete local responsibility |
| `Loam.Application.ScheduledCommitmentInspection` | 600 / 36 / fan-in 7 | semantic/application owner; needs separate source/history evidence before physical change |
| `Loam.Tui.RoleBalances` | 418 / 39 / fan-in 2 | shared presentation projection; inspect after Reports |
| `Loam.RoleBalanceReview` | 413 / 30 / fan-in 9 | strong shared review owner; size alone is weak pressure |
| `Loam.Persistence.NormalizedActualPersistence` | 385 / 10 / fan-out 13 | persistence/versioning frontier; later focused audit |
| `Loam.Tui.ActualRoutingAdministration` | 379 / 22 / fan-in 3 | editor with separate Session already present; inspect later |
| `Loam.Tui.SelectedDay` | 378 / 32 / fan-out 2 | workspace presentation owner; no split inferred yet |
| `Loam.Tui.HraScheduled` | 350 / 36 / fan-out 3 | workspace presentation owner; no split inferred yet |
| `Loam.Tui.CapacityRebalance` / `CapacityTransfer` | 345 / 335 lines | paired editor family; similarity alone does not authorize sharing |

`Reports` is selected first because it is not merely large. Repository history and
current source show several independent presentation change axes inside one physical
module.

## `Loam.Tui.Reports` current topology

Current inventory:

```text
1214 lines
103 declarations
fan-in 3
fan-out 13
reachable from declared production roots
```

The file currently owns all of the following:

```text
Reports menu + top-level Mode / Query / State
        |
        +-- shared explicit-window editor
        |     calendar month
        |     named presets
        |     custom coordinates
        |
        +-- Stock-Flow interaction + presentation
        +-- Transactions Flow interaction
        |     sparse row ordering
        |     selection/detail state
        |     responsive table layout
        |     contributor detail
        +-- Income & Expense presentation
        +-- Balances presentation delegation
        +-- conditional Liquidity interaction + presentation
        +-- Budget Window presentation
        `-- cross-mode bounded scrolling / footer policy
```

This is one presentation workspace, but it no longer has only one reason to change.

## Historical independence

The following changes are useful positive evidence because they changed separate
regions for separate product requirements:

- #488: calendar-month report-window convenience;
- #550: replaceable report window presets;
- #548: conditional selected-balance Liquidity interaction;
- #555: terminal-height bounded Reports paging;
- #630: sparse Transactions Flow interaction;
- #633: responsive Transactions Flow table layout;
- #813–#815: occurrence-time Income & Expense surface and breakdown;
- #820–#821: RoleBalance presentation and answerability map;
- #952: Liquidity summary state was simplified without requiring a general Reports rewrite.

In particular:

- #633 changes the Transactions Flow table/layout slice plus its dedicated test;
- #815 changes only Income & Expense presentation plus `TuiReports` assertions;
- #952 changes conditional-Liquidity review semantics while the Reports consumer
  continues through the same projection names;
- #555 changes cross-mode paging policy and the root loop without introducing new
  report semantics.

That is stronger evidence than raw LOC: distinct requirements repeatedly select
different subregions of `Reports.lean`.

## Candidate seams

### A. Shared report-window state

Classification: **SPLIT_CANDIDATE — strongest first experiment**

Current responsibility:

```text
WindowSource
Form
calendarAnchor
windowPresets
windowSourceLabel
calendar-month seed/reset/shift
preset selection/cycling
custom coordinate editing
focus movement
```

Why this is a real candidate:

- the same window state is consumed by Stock-Flow, Transactions Flow,
  Income & Expense, and Budget Window;
- it has independent product history (#488, #550) unrelated to any one report
  renderer;
- it owns no household authority or report semantics, only presentation/query
  coordinates;
- extracting one nested window state would replace several flat `Reports.State`
  fields with one owner instead of duplicating state;
- Liquidity intentionally remains outside this boundary because its assumption
  horizon has different semantics.

An implementation experiment must not create a second source of report coordinates.
The desired shape is one nested presentation owner, not helper functions that copy
`start` / `endExclusive` / preset state back and forth.

### B. Transactions Flow interaction/presentation

Classification: **SPLIT_CANDIDATE — defer until window seam is tested**

Positive evidence:

- dedicated state (`transactionsIndex`, `transactionsDetail`);
- dedicated sparse-row and contributor-detail interaction;
- dedicated responsive table layout;
- a dedicated production-style test module, `Loam.Tests.TuiTransactionsFlow`;
- independent feature/layout history (#630, #633).

The current obstacle is physical, not semantic: its interaction reuses the shared
window editor. Splitting Transactions Flow before settling window ownership risks
inventing parameter plumbing or duplicated coordinate state.

### C. Income & Expense rendering

Classification: **KEEP_INLINE for now**

It has independent history (#813–#815), but today it is mostly a pure report-specific
rendering projection over `RoleFlowReview.Snapshot`. A new one-consumer module would
mostly move lines unless another consumer or stronger navigation/qualification seam
appears.

### D. Balances / Liquidity / Budget render slices

Classification: **KEEP_INLINE for now**

`RoleBalances` already owns the substantial shared balance presentation. Liquidity
has distinct query semantics but remains modest inside the workspace; Budget Window
is similarly a report-specific projection. Their existence does not justify one
file per menu item.

### E. Bounds-aware paging

Classification: **KEEP_INLINE for now**

Paging is genuinely cross-mode, but it is the workspace's terminal presentation
policy. Extracting it without a second workspace consumer would likely trade local
visibility for indirection. Revisit only if another large workspace needs the same
footer/body paging contract.

## MGA-017 verdict

The global frontier does not support a general "split all large modules" campaign.
It does identify one high-value focused experiment:

```text
Loam.Tui.Reports
        |
        +-- ReportWindow       SPLIT_CANDIDATE / first experiment
        +-- TransactionsFlow  SPLIT_CANDIDATE / second, dependent on window result
        +-- report renderers   KEEP_INLINE for now
        `-- bounds paging      KEEP_INLINE for now
```

The next implementation question is therefore narrow:

> Can the shared report-window presentation state become one physical owner while
> preserving exactly one coordinate state, existing query emission, existing
> Liquidity distinction, and all production Reports behavior?

If yes, MGA-018 may qualify that split. If the extraction needs duplicated state,
large adapter plumbing, or report-specific policy parameters, reject it and keep
`Reports` physically whole.
