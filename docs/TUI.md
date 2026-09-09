# LOAM TUI

`loamTui` is LOAM's production terminal frontend.

The TUI owns presentation and interaction state only. Household meaning, admission,
review, and publication stay in shared LOAM boundaries so that TUI, CLI, and future
frontends do not grow separate semantic engines.

## Current production entrance

Build and run:

```sh
lake build loamTui
./.lake/build/bin/loamTui
```

`./tools/loam` opens the production TUI by default.

`LOAM_DATA_DIR` may select the household data directory; otherwise `loamTui` uses
`../loam-data`. `LOAM_MOVEMENT_MANIFEST_ROOT` may explicitly select the Movement
manifest root; otherwise the selected authority is resolved below the data directory.
Movement reads and writes do not fall back to retired steady-state sidecars.

## Home grammar

The production Home surface currently exposes these entrances:

```text
h/l        previous / next day
k/j        previous / next week
g          return focus to the known-through day
Enter      selected-day workspace
r          Record
a          Actual workspace
p          Scheduled workspace
i          Attention
b          Balances
c          current-cycle Budget
e          raw/general Capacity
v          Reports
q          quit
```

Home's selected date is presentation/navigation state. It seeds selected-day,
Actual, Scheduled, and Record interactions. It does not redefine the current-cycle
Budget observation date or silently manufacture a household cycle.

## Surface map

```text
Loam/Tui/Kernel              Widget / Screen meaning and reconstruction laws
Loam/Tui/Runtime             compiled sparse-row redraw representation
Loam/Tui/Terminal            terminal input/output mechanics
Loam/Tui/Calendar            presentation-only Gregorian calendar projection
Loam/Tui/HraHome             production Home presentation
Loam/Tui/HraActual           Actual workspace presentation state
Loam/Tui/HraScheduled        Scheduled workspace presentation state
Loam/Tui/SelectedDay         one-date Actual / Scheduled composition
Loam/Tui/Record              local Movement draft editor
Loam/Tui/Attention           current-open read-only Attention view
Loam/Tui/Balances            replaceable read-only balance view
Loam/Tui/CycleBudget         current-cycle Budget decision surface
Loam/Tui/Capacity            Capacity observation and action surface
Loam/Tui/Reports             explicit-query Reports workspace
Loam/Tui/Cli                 canonical loading, shared action delegation, executable loop
```

Historical `Loam/Prototype/*` code and numbered prototype executables are research
provenance. Production TUI code must not import them.

## Actual and selected day

Actual and Scheduled remain separate semantic families even when one selected day
shows both. Missing explicit Scheduled evidence remains `Unknown`; presentation
must not strengthen it into `NotDue` without completeness evidence.

The selected-day workspace delegates object-local actions rather than retaining a
second lifecycle engine. Current actions include Movement recording and Actual
correction/date-correction/reversal, plus Scheduled create/complete/cancel/replace.
The TUI editors collect intent; shared publishers perform authoritative re-read,
admission, writer ownership, and publication.

After a successful write, the executable reloads canonical evidence before returning
to the surrounding workspace. A cached TUI answer is never promoted into authority.

## Actual workspace

Home `a` opens the Actual workspace (`Loam.Tui.HraActual`). It projects current
Actual records over neutral Loci coordinates, supporting Focus Day and All Current
scopes (`f`), as well as ascending and descending chronology toggling (`o` / `s`) so
records can be inspected starting from the newest transaction.

Like the selected-day Actual pane, recording new Movements (`n`) opens the shared
Movement editor and delegates execution to `MovementPublisher`, reloading canonical
evidence after durable writes.

## Scheduled workspace

Home `p` opens the Scheduled workspace (`Loam.Tui.HraScheduled`). It projects
the current-open Scheduled frontier over neutral Loci coordinates, supporting
Focus Day and All Current-Open scopes (`f`).

Like the selected-day Scheduled pane, object-local actions include Scheduled
creation (`n`), completion (`c` / `Enter`), supersede/replacement (`s`), and
cancellation (`x`). The surface collects intent and delegates execution to shared
publishers (`ScheduledCreationSession`, `ScheduledTerminalPublisher`,
`ScheduledReplacementPublisher`), reloading canonical evidence after any durable write.

## Attention

Home `i` opens the current-open Attention workspace. It consumes
`Loam.AttentionReview`; lifecycle selection remains in shared Application/Review
semantics. The surface is read-only and preserves the qualified due distinctions
rather than inventing priority or selected-day membership.

## Balances

Home `b` opens the read-only Balances workspace over `Loam.BalanceReview`.
Coordinates remain neutral `Locus × Measure` selections. Presentation does not
classify them as Account, Asset, Liability, cash, or any other accounting role.
Explicit zero-origin evidence and correction-aware review remain shared boundaries.

## Current-cycle Budget

Home `c` opens the current-cycle Budget surface. The observation date is the
known-through Actual date, not Home's navigated focus date. The cycle coordinates
come from the explicit current boundary preset; the TUI does not infer a cycle from
a month, first Capacity movement, or selected day.

`Loam.CycleBudgetReview` composes shared funding, physical-balance, current-coverage,
and Scheduled-frontier answers. The surface displays those answers directly and does
not retain Remaining, Headroom, SafeToSpend, or a second budget arithmetic engine.

Budget is an action surface, not a read-only workspace:

```text
g          grant a selected negative After-known shortage through Capacity transfer
u          route unresolved Scheduled pressure through shared Scheduled routing
r          rebalance through the existing Capacity rebalance path
b / Esc    Home
q          quit
```

The former Budget `e -> Capacity` detour is retired. `e` inside Budget is not an
alternate Capacity entrance. General/raw Capacity remains available from Home `e`.
After Budget actions, the executable reloads the current Budget evidence before
rendering the workspace again.

## Capacity

Home `e` opens Capacity. The base snapshot is the shared all-retained
`Loam.CapacityReview` answer. When the explicit current boundary preset is available,
the caller also attaches the shared `CurrentCoverageReview` answer for current
decision support.

The surface does not locally recompute Consumption, Scheduled commitment, Remaining,
or Headroom. Coverage labels are presentation only and are not SafeToSpend authority.
If current coverage cannot be justified, the all-retained Capacity answer remains
visible with an explicit coverage refusal.

Capacity currently exposes:

```text
t          transfer
r          rebalance
up/down    select remembered Purpose
b / Esc    Home
q          quit
```

Editors remain local interaction state. `CapacityPublisher` and the existing shared
publication sessions own authoritative writes and fresh review.

## Reports

Home `v` opens Reports. Reports are explicit read queries rather than hidden household
period authority. Current report queries include Budget Window, Stock-Flow,
Transactions Flow, and conditional Liquidity.

Visible query coordinates are the coordinates sent to the shared Review boundary.
Calendar-month defaults are presentation conveniences only; they do not establish a
retained Month, BudgetCycle, cadence, or canonical current window.

## Write boundary

No TUI surface may publish by mutating canonical files directly or by copying a
CLI-private writer. Editors produce typed intents/drafts and delegate to shared
publishers. Writer ownership, current-world re-read, admission, stale rejection,
publication, and post-write verification stay outside presentation state.

This rule applies equally to Movement, correction/reversal, Scheduled lifecycle,
Capacity, and Scheduled-routing actions.

## Qualification

`.github/workflows/tui.yml` is the production TUI qualification path. It builds the
production executables and exercises the shared review/publisher boundaries plus
Actual, selected-day, Attention, Balances, Capacity, Reports, Cycle Budget, Scheduled
Routing, Cycle Grant, and PTY interaction paths.

`docs/research/*` and `experiments/*` may describe earlier stages such as the original
read-only Cycle Budget. Those files are historical/research evidence unless they
explicitly claim to be current production guidance. This document and the production
source/tests are the current TUI contract.
