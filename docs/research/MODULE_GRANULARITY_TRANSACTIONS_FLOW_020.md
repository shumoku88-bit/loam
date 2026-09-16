# MGA-020 — qualified Transactions Flow result-pane boundary

Status: **KEEP_BOUNDARY / SPLIT_QUALIFIED**

Baseline:

```text
ec397f565e6643d91ff2f4f869e757e1526841c1
docs(audit): map MGA-019 Transactions Flow frontier (#983)
```

MGA-019 authorized one narrow implementation experiment: move only the result-local Transactions Flow presentation owner out of `Loam.Tui.Reports`, while keeping shared report-window, query, invalidation, scrolling, paging, and semantic ownership where they already belonged.

MGA-020 performed that experiment. The split qualifies.

## Final ownership

`Loam.Tui.Reports.State` no longer retains three separate Transactions-specific fields:

```text
transactionsSnapshot
transactionsIndex
transactionsDetail
```

They are replaced by exactly one nested owner:

```text
transactions : Loam.Tui.TransactionsFlowPane.State
```

The pane state is intentionally minimal:

```text
structure State where
  snapshot      : Option Loam.TransactionsFlowReview.Snapshot := none
  selectedIndex : Nat := 0
  detail        : Bool := false
```

No compatibility mirror remains in `Reports.State`.

## What moved into `TransactionsFlowPane`

The new presentation owner contains only result-local state and exact projections derived from it:

- snapshot adoption and reset;
- active-row derivation from the semantic snapshot;
- zero-activity filtering;
- presentation-only gross-activity ordering;
- selected-row lookup and movement;
- summary/detail local transition state;
- responsive Transactions table layout;
- summary result body rendering;
- focused detail body rendering;
- nonzero Event-contribution projection;
- derived selected-summary-line position used by the parent paging policy.

Rows, selected coordinate, contribution lists, and layout are recomputed. They are not retained as additional state.

## What deliberately stayed in `Reports`

### Shared report window

`Reports.window : ReportWindow.State` remains the only owner of explicit report-window coordinates, calendar anchor, presets, source selection, custom editing, and focus.

`TransactionsFlowPane` does not import `ReportWindow`.

### Query emission

`Reports` still emits:

```text
Query.transactionsFlow state.window.form.start state.window.form.endExclusive
```

The pane consumes a completed `TransactionsFlowReview.Snapshot`. It does not choose canonical coordinates or request household evidence.

### Stale-result invalidation

Shared coordinate changes still flow through `Reports.clearResults`. That policy resets the nested Transactions pane to its initial state along with the other report answers.

The pane does not observe window transitions and does not decide when evidence is stale.

### Workspace scrolling and paging

`scroll`, footer/body partitioning, `scrollLimit`, `requestedOffset`, bounds clamping, and `updateForBounds` remain Reports-owned workspace policy.

The pane exposes only the selected row's derived position inside its summary body. `Reports` composes that position with the shared window-editor prefix and terminal page size.

There is therefore still exactly one scroll owner.

### Menu, mode, notice, and semantic authority

Reports keeps menu/mode navigation, back-to-menu behavior, notices, and footer composition.

`Loam.TransactionsFlowReview` remains the sole presentation-neutral semantic owner. The pane does not infer pairwise source/destination edges, transfers, AccountingRole, Purpose, valuation, or cross-Measure aggregation.

## Dependency direction

The qualified dependency shape is:

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

The candidate did **not** introduce either rejected reverse edge:

```text
TransactionsFlowPane -/-> Reports
TransactionsFlowPane -/-> ReportWindow
```

## Behavioral qualification

The ownership cutover was first exercised before opening a PR.

A focused one-shot qualification rebuilt the production `loamTui` target after replacing the three flat Transactions fields with the nested pane and then ran:

```text
Loam/Tests/TuiTransactionsFlow.lean
Loam/Tests/TuiReports.lean
```

Both tests passed.

The focused Transactions test continues to pin:

- shared explicit window query reuse;
- sparse active-coordinate summary;
- zero-net / nonzero-gross circulation;
- responsive narrow-table width;
- coordinate selection;
- focused detail containing only nonzero contributing Events;
- detail -> summary -> Reports-menu navigation;
- shared window editing clearing stale Transactions results.

The test was updated to observe the new canonical nested owner. No production alias was added for test convenience.

## Implementation-experiment false alarms

Two failures occurred during the experiment, neither of which challenged the architecture:

1. the first source-transform helper used an overly strict multiline indentation match and stopped before building;
2. the first Pane build wrote the derived selected-row offset as
   `some prefix.length + 2 + index`, which Lean parsed as `Option Nat + Nat`.

The final expression is parenthesized as one derived `Nat` before wrapping in `some`.

Neither failure required widening the boundary, adding adapter state, or moving ReportWindow/query/scroll ownership.

## Refreshed inventory

The post-cutover inventory reports:

```text
Lean modules: 337
Modules <= 80 lines: 92
Modules with exactly one local consumer: 56
Declared Lake roots: 17
Production-like modules unreachable from declared roots: 0
```

Focused metrics:

```text
Loam.Tui.Reports
  892 lines / 78 declarations / fan-in 3 / fan-out 15 / reachable=True

Loam.Tui.ReportWindow
  176 lines / 14 declarations / fan-in 1 / fan-out 2 / reachable=True

Loam.Tui.TransactionsFlowPane
  287 lines / 33 declarations / fan-in 1 / fan-out 3 / reachable=True
  sole local consumer: Loam.Tui.Reports
```

Before MGA-020, post-MGA-018 `Reports` was:

```text
1104 lines / 97 declarations
```

The new module therefore accompanies a substantial drop in parent responsibility density rather than merely increasing physical file count. The decisive evidence remains ownership and behavior, not the line delta.

## MGA-019 obligation discharge

The MGA-019 acceptance rule is satisfied:

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

## Verdict

**MGA-020: KEEP_BOUNDARY / SPLIT_QUALIFIED.**

This does not authorize one physical module per Reports menu item. Transactions Flow earned its boundary because result-local state, local interaction, responsive presentation, dedicated tests, independent history, and a clean dependency seam all align.

The current stop line is the parent workspace composition itself. No further Transactions split is implied by this result.
