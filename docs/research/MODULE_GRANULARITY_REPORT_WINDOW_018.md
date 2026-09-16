# MGA-018 — Canonical ReportWindow state owner

Status: **KEEP_BOUNDARY / SPLIT_QUALIFIED pending full PR qualification**

Baseline:

```text
79e301ca27e36d700fbfae43be77004a0818058d
docs(audit): map MGA-017 Reports granularity frontier (#980)
```

MGA-017 identified the shared Reports explicit-window state as the strongest
physical split candidate. MGA-018 tests that candidate by implementation rather
than by line-count preference.

The acceptance rule was deliberately strict:

> The split qualifies only if one canonical window state replaces the old flat
> fields, four report modes reuse it, Liquidity keeps its different assumption
> horizon, report semantics remain outside it, and no compatibility mirror is
> required.

## Before

`Loam.Tui.Reports.State` directly retained four parts of one presentation owner:

```text
form : Form
calendarAnchor : String
windowPresets : List Preset
windowSource : WindowSource
```

`Reports.lean` also owned the transitions over that state:

```text
calendar-month seed
reset
left/right month shift
preset lookup and cycling
custom coordinate editing
focus movement
source label
```

Those operations were reused internally by Stock-Flow, Transactions Flow,
Income & Expense, and Budget Window.

Liquidity was already different. Its `assumedCompleteThrough` editor is an
explicit completeness assumption, not a report-window coordinate selector.
MGA-018 therefore does not merge it into the new owner.

## After

`Reports.State` now contains exactly one window field:

```text
window : Loam.Tui.ReportWindow.State
```

`Loam.Tui.ReportWindow` owns:

```text
Source
Form
State = Form + calendarAnchor + presets + source

initialForDateWithPresets
moveFocus
editActive
resetCalendarMonth
cycleSource
shiftCalendarMonth
sourceLabel
```

There is no retained `Reports.form`, `Reports.calendarAnchor`,
`Reports.windowPresets`, or `Reports.windowSource` compatibility copy.

The four explicit-window report modes read the same nested state:

```text
Stock-Flow
Transactions Flow
Income & Expense
Budget Window
        |
        v
Reports.window : ReportWindow.State
```

This is an ownership move, not a second window engine.

## Boundary that intentionally stays in Reports

`ReportWindow` does **not** own report-result invalidation.

Changing query coordinates makes existing report answers stale, but the answers
belong to the Reports workspace. Therefore `Reports` still owns:

```text
stockFlowSnapshot
transactionsSnapshot
incomeExpenseSnapshot
roleBalanceSnapshot
liquiditySnapshot
budgetSnapshot
transactions selection/detail
scroll
notice integration
clearResults
```

`Reports.applyWindowResult` composes one pure window transition with the
workspace policy that stale report answers must be cleared.

This prevents the extracted module from gaining knowledge of Stock-Flow,
Transactions Flow, RoleFlow, RoleBalance, Liquidity, or Budget review types.

## Refused month shift exposed the exact seam

The implementation experiment found one useful counterexample to an overly broad
composition rule.

Before extraction, a successful Calendar Month shift changed coordinates and
cleared report results. A refused shift did not change coordinates; it only
published a recovery notice and preserved the current report snapshot.

The first cutover routed every `shiftCalendarMonth` result through
`clearResults`, which would have changed that behavior. MGA-018 therefore keeps
this distinction at the Reports composition boundary:

```text
ReportWindow.shiftCalendarMonth
             |
             v
       next window state
             |
     +-------+-------+
     |               |
unchanged          changed
     |               |
notice only       clear stale results
preserve answer   adopt new coordinates
```

A regression now pins that a refused non-calendar month shift preserves an
existing Stock-Flow snapshot.

## Do not retain `changed`

During qualification, an intermediate debugging hypothesis considered adding a
`changed : Bool` field to `ReportWindow.Result`.

That field was rejected.

Whether a shift changed the canonical window is exactly derivable from:

```text
result.state = state.window
```

Retaining the same fact independently would violate the audit rule:

```text
retain independent distinctions
derive exact consequences
```

The final design therefore derives success/change at the composition boundary
and stores no extra outcome bit.

A confusing failed regression during this step was traced to stale compiled
`.olean` input in a temporary qualification workflow: source was patched after
the cached production module had been built. Rebuilding `loamTui` after the
source patch made the equality-based design pass. No extra state was required.

## Behavior qualification

Focused qualification now covers both shared and report-specific behavior.

`loamTui` builds after the ownership cutover.

`Loam/Tests/TuiReports.lean` verifies, among other existing behavior:

- selected-day calendar-month seed;
- named preset selection and return to Calendar Month;
- custom editing and stale-result clearing;
- month navigation and year rollover;
- fail-closed recovery from malformed/non-calendar Calendar-Month coordinates;
- Stock-Flow, Income & Expense, Balances, Liquidity, and Budget presentation;
- bounded report scrolling;
- the new refused-shift snapshot-preservation regression.

`Loam/Tests/TuiTransactionsFlow.lean` verifies that the shared window focus/edit
path still composes correctly with Transactions Flow's separate selection/detail
interaction and responsive presentation.

Both focused tests pass after a fresh production TUI rebuild.

## Inventory after extraction

The refreshed module inventory reports:

```text
Lean modules:                              336
Modules <= 80 lines:                       92
Modules with exactly one local consumer:   55
Declared Lake roots:                       17
Production-like unreachable:               0

Loam.Tui.Reports
  1104 lines / 97 declarations / fan-in 3 / fan-out 14 / reachable

Loam.Tui.ReportWindow
  176 lines / 14 declarations / fan-in 1 / fan-out 2 / reachable
  sole local consumer: Loam.Tui.Reports
```

Before MGA-018, Reports was:

```text
1214 lines / 103 declarations / fan-out 13
```

The new module count and one-consumer count both rise by one, as expected for an
explicit internal owner. That is not itself evidence for or against the split.
The relevant result is that Reports loses the window state machine, the new owner
is reachable, no production-like unreachable module appears, and no mirror state
is left behind.

## Why fan-in 1 is acceptable here

`ReportWindow` has one physical importer, `Reports`, but four report modes inside
that workspace depend on the same state owner.

A separate module is earned here by independent change history and singular state
ownership, not by broad repository-level reuse. The boundary also makes future
Transactions Flow extraction possible without duplicating or parameter-threading
window state.

If ReportWindow had merely moved helper functions while the real state remained
flat in Reports, MGA-018 would reject it. That is not the resulting topology.

## Stop point

MGA-018 does not continue decomposing Reports by menu item.

The MGA-017 KEEP decisions remain in force for now:

```text
Income & Expense renderer             KEEP_INLINE
Balances / Liquidity / Budget slices  KEEP_INLINE
bounds-aware paging                   KEEP_INLINE
```

Transactions Flow remains the next physical candidate because it owns dedicated
selection/detail state, sparse-row interaction, responsive layout, contributor
detail, a dedicated test module, and independent #630/#633 history.

Its case must now be re-audited against the settled ReportWindow boundary. MGA-018
does not pre-authorize that split.

## Verdict

The ReportWindow experiment satisfies the MGA-017 acceptance rule:

```text
one canonical state owner              YES
four explicit-window modes reuse it    YES
Liquidity assumption stays separate    YES
report semantics stay in Reports       YES
snapshot invalidation stays in Reports YES
compatibility mirror required          NO
extra change/outcome state retained    NO
reachable from production roots        YES
production-like unreachable introduced NO
focused production behavior preserved  YES
```

**MGA-018 verdict: KEEP_BOUNDARY / SPLIT_QUALIFIED**, subject only to the final
repository PR qualification suite.
