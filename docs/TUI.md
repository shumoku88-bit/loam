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
`../loam-data`. The selected directory is also the production Actual authority root,
and normalized Actual evidence is retained in `actual.loam`. Actual reads and writes
do not fall back to retired steady-state sidecars.

## Home grammar

The production Home surface currently exposes these entrances:

```text
h/l        previous / next day
k/j        previous / next week
t          return focus to today
Enter      selected-day workspace
r          Record
a          Actual workspace
s          Scheduled workspace
i          Attention
b          Balances
c          current-cycle Budget
e          raw/general Capacity
p          Purpose routing administration
m          Locus administration
o          current quantity observation
v          Reports
q          quit
```

Home's selected date is presentation/navigation state. It seeds selected-day,
Actual, Scheduled, and Record interactions. It does not redefine the current-cycle
Budget observation date or silently manufacture a household cycle.

Outside Home, `q` and `Esc` mean one-level back. Only Home `q` exits LOAM; child
surfaces do not carry a second application-quit command or a hidden `b` back alias.

Home keeps household state in the body and shortcut grammar in the stable footer.
The footer groups commands as `Day`, `Household`, and `Manage`; all Home entrances
remain one-keystroke commands. The body glance line reports only Scheduled and
Pending state. An empty Pending set remains visible as `Pending: 0` but does not
allocate a separate empty `Pending Scheduled` section.

The Home labels distinguish the user-facing action from the narrower implementation
module name. `p` edits Actual-to-Purpose routing, `m` admits new Locus identities, and
`o` publishes one complete current quantity observation image.

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
scopes (`f`), as well as ascending and descending chronology toggling (`s`) so
records can be inspected starting from the newest transaction.

Like the selected-day Actual pane, recording new Movements (`n`) opens the shared
Movement editor and delegates execution to `MovementPublisher`, reloading canonical
evidence after durable writes.

## Scheduled workspace

Home `s` opens the Scheduled workspace (`Loam.Tui.HraScheduled`). It projects
the current-open Scheduled frontier over neutral Loci coordinates, supporting
Focus Day and All Current-Open scopes (`f`).

Like the selected-day Scheduled pane, object-local actions include Scheduled
creation (`n`), completion (`c` / `Enter`), supersede/replacement (`r`), and
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
q / Esc    Home
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
q / Esc    Home
```

Editors remain local interaction state. `CapacityPublisher` and the existing shared
publication sessions own authoritative writes and fresh review.

## Purpose routing

Home `p` opens Actual-to-Purpose routing administration. The surface edits explicit
routing evidence; it does not infer a Purpose from an AccountingRole, sign, account
name, or current balance. Expense Loci remain the default audit scope while admitted
non-Expense Loci can be entered explicitly when a generic Purpose question needs it.

## Locus administration

Home `m` opens add-only Locus administration. It shows the currently admitted
vocabulary before proposing one new stable Locus token. Admission does not also
create a label, AccountingRole, Purpose route, rename, or alias.

## Current quantity observation

Home `o` opens the current quantity observation editor. It collects one complete set
of `Locus × Measure × observed Quantity` rows observed together and publishes the
whole image through the shared boundary. The editor does not merge the image with an
older observation or derive reconciliation semantics locally.

## Reports

Home `v` opens Reports. Reports are explicit read queries rather than hidden household
period authority. Current report queries include Budget Window, Stock-Flow,
Transactions Flow, and conditional Liquidity.

Visible query coordinates are the coordinates sent to the shared Review boundary.
Calendar-month defaults are presentation conveniences only; they do not establish a
retained Month, BudgetCycle, cadence, or canonical current window.

Scheduled Coverage is a separate read-only future-plan lens. It compares current-open
Scheduled evidence with optional `config/scheduled-coverage.tsv` monitoring rules:

```text
<rule-token><TAB><anchor-date><TAB><every-months><TAB><negative-locus[,negative-locus...]><TAB><positive-locus[,positive-locus...]>
```

The grid starts with the month after the selected Home date and currently shows eight
months. `●` means an expected month has an explicit matching Scheduled occurrence,
`!` means the configured expectation has no explicit matching occurrence, `·`
means the rule does not expect that month, and `+` means explicit evidence exists
outside the configured month pattern. Matching uses the exact negative- and
positive-Locus sets while deliberately ignoring amounts, so incoming plans such as
pension and support remain distinguishable even when both land in the same asset.
These are coverage diagnostics only. The rules do not create Scheduled occurrences,
retain Series identity, or promote absence into a canonical NotDue claim.

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
