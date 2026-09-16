# MGA-019 Transactions Flow pane obligation DAG

Baseline: `9af9228b790a4764989a946c5f93815cdf18d6a8`

Purpose: determine whether the Transactions Flow presentation slice can become an independent physical module without duplicating state, semantics, query ownership, or workspace policy.

This DAG is intentionally stricter than a source-region split. A future extraction must satisfy every required edge before `SPLIT_QUALIFIED` is available.

## Nodes

```text
O0  Semantic source remains Loam.TransactionsFlowReview.Snapshot
 |
 +--> O1  One result-local retained state owner
 |         snapshot + selectedIndex + detail
 |
 +--> O2  Active rows are derived from Snapshot
 |         filter activeEvents > 0
 |         order by gross salience + coordinate tie-break
 |
 +--> O3  Focused contributions are derived
 |         Snapshot + selected coordinate -> nonzero Event witnesses
 |
 +--> O4  No derived row/contribution/layout cache is retained
 |
 `--> O5  No new movement semantics are introduced
           no pairwise edge / role / purpose / cross-Measure valuation

R0  Reports owns shared ReportWindow.State
 |
 +--> R1  Transactions pane does not import/mirror ReportWindow
 |
 +--> R2  Query.transactionsFlow emission remains Reports-owned
 |         explicit start/end come from Reports.window
 |
 +--> R3  Window-change stale-result invalidation remains Reports-owned
 |         clearResults resets pane state
 |
 `--> R4  No report-specific window adapter is introduced

W0  Reports owns workspace composition
 |
 +--> W1  Mode/menu/back-to-menu remain Reports-owned
 |
 +--> W2  notice integration remains Reports-owned
 |
 +--> W3  scroll remains Reports-owned
 |
 +--> W4  body/footer paging and bounds clamping remain Reports-owned
 |
 `--> W5  pane may consume content width only for responsive body layout

P0  Candidate physical owner: Loam.Tui.TransactionsFlowPane
 |
 +--> P1  owns Snapshot adoption/reset
 |
 +--> P2  owns selection movement bounded by derived active rows
 |
 +--> P3  owns summary/detail local transition
 |
 +--> P4  owns responsive summary table body
 |
 +--> P5  owns focused detail body
 |
 `--> P6  dependency direction stays one-way
           Reports -> Pane -> Review/Layout/Kernel
           Pane -X-> Reports
           Pane -X-> ReportWindow

T0  Existing focused test contract
 |
 +--> T1  explicit shared window query preserved
 +--> T2  zero-net / nonzero-gross witness preserved
 +--> T3  sparse zero-cell omission preserved
 +--> T4  narrow responsive table preserved
 +--> T5  coordinate selection preserved
 +--> T6  focused nonzero contributor detail preserved
 +--> T7  summary/detail/menu navigation preserved
 `--> T8  window edit clears stale Transactions result

Q0  MGA-020 qualification gate
 |
 +--> Q1  O0..O5 all satisfied
 +--> Q2  R0..R4 all satisfied
 +--> Q3  W0..W5 all satisfied
 +--> Q4  P0..P6 all satisfied
 +--> Q5  T0..T8 all satisfied
 +--> Q6  production reachability remains intact
 +--> Q7  no compatibility mirror retained in Reports.State
 `--> Q8  no new semantic engine / authority boundary introduced

Q0 satisfied -> KEEP_BOUNDARY / SPLIT_QUALIFIED
Q0 violated  -> SPLIT_REJECTED / keep Transactions Flow inline
```

## Why these dependencies matter

### O0 before P0

The presentation module is allowed to organize and render a `TransactionsFlowReview.Snapshot`; it is not allowed to become a second computation engine. That keeps exact quantity-at-coordinate semantics presentation-neutral and machine-checkable outside the TUI.

### R0 before P0

MGA-018 already paid the cost of making report-window state singular. A Transactions extraction that imports or mirrors ReportWindow would immediately undo that result. Shared coordinates must stay above the pane.

### W0 before P0

Transactions Flow has local navigation, but it lives inside a Reports workspace with shared bounded paging. The selected coordinate is local; the terminal viewport is not. This distinction is the main stop line preventing the candidate from growing into a second workspace.

### O1 requires snapshot + index + detail together

These three values form one local invariant:

```text
snapshot changes
  -> active rows change
  -> selected index must be reset/clamped
  -> focused detail must close/reset
```

Keeping the snapshot in Reports while moving only index/detail would create two owners for this invariant. Therefore the implementation experiment should prefer one nested pane state and reject compatibility mirrors.

### O2/O3 before O4

Rows and contributions are projections, not facts that need independent identity. They must remain derived on demand. Likewise responsive `TableLayout` is a function of terminal content width and is not retained state.

### W3/W4 constrain P4/P5

The pane can render a body for a supplied width. It must not decide page offset, footer size, total workspace scroll bounds, or terminal clamping. Reports can use pane-derived line/selection information to compute its existing paging policy.

## Minimal candidate shape

A qualifying implementation may look approximately like this:

```text
Reports.State
  mode
  menuIndex
  window : ReportWindow.State
  transactions : TransactionsFlowPane.State
  ...other report snapshots/forms...
  notice
  scroll

TransactionsFlowPane.State
  snapshot
  selectedIndex
  detail
```

This is an ownership sketch, not a required API.

The important absence is:

```text
Reports.transactionsSnapshot
Reports.transactionsIndex
Reports.transactionsDetail
TransactionsFlowPane.window
TransactionsFlowPane.scroll
TransactionsFlowPane.query
```

## Stop rule

Do not continue from a successful Transactions extraction into one-file-per-report decomposition.

MGA-017 KEEP decisions remain unchanged unless independently re-audited:

```text
Income & Expense renderer             KEEP_INLINE
Balances / Liquidity / Budget slices  KEEP_INLINE
bounds-aware paging                   KEEP_INLINE
```

MGA-019 only authorizes one narrow implementation experiment against the DAG above.
