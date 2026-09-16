# MGA-019 — Transactions Flow presentation-owner frontier

Status: **SPLIT_CANDIDATE / IMPLEMENTATION_EXPERIMENT_JUSTIFIED**

Baseline:

```text
9af9228b790a4764989a946c5f93815cdf18d6a8
refactor(tui): isolate canonical ReportWindow state (#981)
```

MGA-017 identified Transactions Flow as a possible second Reports split, but explicitly deferred it until shared report-window ownership was settled. MGA-018 has now qualified `Loam.Tui.ReportWindow` as the one canonical owner of explicit report-window presentation state.

MGA-019 therefore re-audits Transactions Flow against the post-MGA-018 topology. This is not permission to create one module per report menu item. The question is narrower:

> Does Transactions Flow now contain one durable result-local presentation owner that can move out of `Loam.Tui.Reports` without taking shared window, query, scrolling, or household semantics with it?

## Current topology

`Loam.Tui.Reports.State` still directly retains three Transactions-specific fields:

```text
transactionsSnapshot : Option Loam.TransactionsFlowReview.Snapshot
transactionsIndex    : Nat
transactionsDetail   : Bool
```

Those fields feed a coherent local pipeline in `Reports.lean`:

```text
TransactionsFlowReview.Snapshot
        |
        v
active coordinate rows
filter zero activity
order by gross presentation salience
        |
        v
selected coordinate index
        |
        +--> summary responsive table
        |
        `--> focused detail
             nonzero Event contributions only
```

The same source region owns:

- active-row filtering and presentation-only ordering;
- selected-coordinate movement;
- summary/detail transition state;
- responsive Transactions table layout;
- selected-row lookup;
- nonzero contribution projection for detail;
- summary and detail body rendering.

This is more than a renderer fragment. The state and the presentation projections change together as one result-local interaction surface.

## Historical independence

The candidate is supported by repository history rather than size alone.

PR #630 introduced Transactions Flow as a sparse production Reports surface. Its own design record explicitly separated:

```text
shared Reports window / preset machinery
shared bounded scrolling
Transactions-local selected coordinate index
Transactions-local summary/detail flag
```

It also established the presentation semantics that remain visible today:

- one row per active `(LocusId, MeasureId)` coordinate;
- zero-net circulation visible through gross activity;
- rows ordered by gross activity as presentation salience only;
- detail contains only Events with nonzero contribution at the selected coordinate;
- no source/destination edge inference;
- no AccountingRole/Purpose inference;
- no cross-Measure aggregation.

PR #633 then changed the Transactions Flow responsive table/layout independently, without redefining the shared Reports window model or the underlying `TransactionsFlowReview` semantic engine.

That is positive evidence of an independent presentation change axis.

## Candidate owner

The implementation experiment should test a presentation module with a name that cannot be confused with the semantic review engine, for example:

```text
Loam.Tui.TransactionsFlowPane
```

The candidate state is exactly the result-local state:

```text
structure State where
  snapshot      : Option Loam.TransactionsFlowReview.Snapshot := none
  selectedIndex : Nat := 0
  detail        : Bool := false
```

The exact names are not architectural requirements. The ownership is.

The pane may own:

```text
snapshot adoption/reset
active row projection
presentation-only row ordering
selected-row lookup
selection movement
summary/detail local transition
responsive table layout
summary result body
detail result body
nonzero contribution projection
```

The pane must not cache `rows`, selected coordinates, contributions, or layout output as independent retained state. All of those are exactly derivable from the snapshot, selected index, and terminal width.

## Why the snapshot belongs with the pane

Leaving `transactionsSnapshot` in `Reports.State` while moving only `transactionsIndex` and `transactionsDetail` would split one local invariant across two physical owners.

Selection validity, detail availability, row count, selected coordinate, and contribution detail are all functions of the current Transactions Flow snapshot. A new snapshot also resets selection/detail.

Therefore the strongest singular-owner experiment is:

```text
Reports.State
  transactions : TransactionsFlowPane.State
```

rather than:

```text
Reports.State
  transactionsSnapshot : Snapshot
  transactionsUi       : TransactionsFlowPane.State
```

The second shape would create a coordination seam without an independent reason to change.

## Boundaries that must stay in Reports

### 1. ReportWindow

Transactions Flow must continue to reuse:

```text
Reports.window : ReportWindow.State
```

The pane must not import or mirror `ReportWindow.State`.

Window seed, preset cycling, calendar shifting, custom start/end editing, and focus remain shared Reports composition.

### 2. Query emission

The presentation pane must not decide canonical query coordinates or emit a production report request.

This remains Reports-owned:

```text
Query.transactionsFlow state.window.form.start state.window.form.endExclusive
```

The pane consumes an already-computed `TransactionsFlowReview.Snapshot`; it does not create the semantic answer.

### 3. Result invalidation policy

When shared query coordinates change, Reports decides that existing report answers are stale.

The pane may provide a zero/default state, but it must not observe ReportWindow transitions or decide when household answers become stale.

Expected composition:

```text
ReportWindow changes
      |
      v
Reports.clearResults
      |
      `--> transactions := TransactionsFlowPane.initial
```

### 4. Workspace scrolling and bounds paging

`scroll` remains a Reports workspace field.

Transactions detail currently uses `scroll` as vertical offset and summary selection influences `requestedOffset`, but bounded paging is shared across all report modes. Moving `scroll`, `viewParts`, `bodyPageSize`, `scrollLimit`, or `updateForBounds` into a Transactions module would duplicate or fracture workspace policy.

The pane may receive a content width for responsive table formatting and may expose enough derived information for Reports to compute the selected summary line. It must not own terminal page offsets or bounds clamping.

### 5. Mode/menu/notice composition

`Mode.transactionsFlow`, Reports-menu navigation, back-to-menu behavior, query dispatch, notice integration, and footer policy remain in Reports.

A pane transition may report a local outcome, but introducing a parallel top-level workspace state machine would fail the experiment.

## Proposed dependency direction

The physical dependency should remain acyclic and narrow:

```text
Loam.Tui.Reports
  |
  +--> Loam.Tui.ReportWindow
  |
  `--> Loam.Tui.TransactionsFlowPane
          |
          +--> Loam.TransactionsFlowReview
          +--> Loam.Tui.Layout
          `--> Loam.Tui.Kernel
```

Rejected direction:

```text
TransactionsFlowPane --> Reports
TransactionsFlowPane --> ReportWindow
```

Either would indicate that the candidate is not actually result-local.

## Semantic stop line

`Loam.TransactionsFlowReview` remains the presentation-neutral semantic owner.

The pane must not introduce another interpretation of movement. In particular it must not infer:

- pairwise source/destination flow edges;
- AccountingRole or Purpose;
- transfers from signs alone;
- valuation across Measures;
- dense zero-cell matrix semantics.

Its row ordering remains presentation salience only.

## Test obligations

The existing dedicated `Loam/Tests/TuiTransactionsFlow.lean` already forms a useful behavioral contract. A future extraction must preserve:

- shared explicit window query reuse;
- sparse active-coordinate summary;
- zero-net / nonzero-gross circulation witness;
- responsive narrow table with no overflow;
- coordinate selection movement;
- focused detail with only nonzero contributing Events;
- detail back to summary and summary back to Reports menu;
- shared window editing invalidating stale Transactions result state.

The extraction should change test access to the new owner rather than retaining compatibility fields in `Reports.State` solely for tests.

## Acceptance rule for MGA-020

A future implementation experiment qualifies only if all of the following hold:

```text
one Transactions result-local state owner             YES
snapshot/index/detail mirror fields in Reports         NO
ReportWindow ownership moved or duplicated             NO
query emission moved into pane                         NO
workspace scroll/paging moved into pane                NO
semantic TransactionsFlowReview logic duplicated       NO
row/contribution/layout caches retained                NO
Reports imports pane; pane imports Reports              NO
focused Transactions behavior preserved               YES
production root reachability preserved                 YES
```

If the extraction requires report-specific window adapters, a second scroll owner, compatibility mirrors, or a new semantic result type that duplicates `TransactionsFlowReview.Snapshot`, reject the split.

## DRAKON qualification

MGA-019 has a dedicated three-diagram DRAKON artifact:

```text
docs/drakon/loam-tui-transactions-flow-granularity-audit.drn
```

The generated map records:

1. the current Transactions-specific ownership cluster inside Reports;
2. the candidate `TransactionsFlowPane` seam and the responsibilities that must stay above it;
3. the all-or-nothing qualification obligations for MGA-020.

The builder-generated artifact passed SQLite integrity, exact three-diagram count, source metadata coverage, and explicit presence checks for the candidate-seam and obligation-DAG diagrams. The one-shot generator retired itself after committing the artifact. Permanent Module Granularity CI now regenerates and compares this map on relevant PRs.

## Current verdict

The post-MGA-018 evidence is stronger than at MGA-017 because the largest shared concern has already moved to its canonical owner.

Transactions Flow now presents one plausible physical seam:

```text
shared Reports workspace
        |
        +--> ReportWindow              already qualified
        |
        +--> TransactionsFlowPane      candidate result-local owner
        |
        `--> shared paging/query/menu  remain Reports
```

**MGA-019 verdict: SPLIT_CANDIDATE / IMPLEMENTATION_EXPERIMENT_JUSTIFIED.**

No production code is changed by MGA-019. MGA-020, if performed, must attempt the narrow owner extraction and is free to reject it if the implementation creates more coordination than it removes.
