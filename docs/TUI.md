# LOAM TUI

`loamTui` is LOAM's production terminal frontend.

The TUI owns presentation and interaction state only. Household meaning, admission,
review, and publication stay in shared LOAM boundaries so that TUI, CLI, and future
frontends do not grow separate semantic engines.

## Current production entrance

Run from the repository root:

```sh
./tools/loam
```

This launcher builds the current `loam` executable before starting its TUI, so
TUI changes are not missed because of an old executable. Pass an optional data
directory via `./tools/loam tui LOAM_DATA_DIR`.

For debugging, `lake build loamTui` followed by `./.lake/build/bin/loamTui`
also works. Do not run the binary directly after changing sources without
rebuilding it first.

`LOAM_DATA_DIR` may select the household data directory; otherwise `loamTui` uses
`../loam-data`. The selected directory is also the production Actual authority root,
and normalized Actual evidence is retained in `actual.loam`. Actual reads and writes
do not fall back to retired steady-state sidecars.

## Home grammar

The production Home surface currently exposes these entrances:

```text
h/l        previous / next day, month, or year (current zoom)
k/j        previous / next week, quarter, or year (current zoom)
t          return calendar focus to today
/          jump to a date, month, or year (Enter confirms; Esc cancels)
z          cycle Day / Month / Year
Tab/w      switch calendar / transaction focus
Ctrl-u/d   scroll calendar/summary; page transaction selection in detail
Enter      Year -> Month -> Day -> selected-day workspace
f          toggle calendar / money lens in Day view
r          Record (selected date prefilled; cursor starts in Description)
a          Actual workspace
s          Scheduled workspace
d          Daily Pace trend
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
The current Daily Pace answer stays on Home, while `d` opens a small read-only
trend over the already-derived retrospective current-truth series. The trend does
not retain daily pace as household state or introduce a second calculation.
The footer groups commands by the active Day/Month/Year or Detail context,
`Household`, and `Manage`. In Detail, j/k selects transactions, Enter opens the
selected transaction in its day workspace, and Esc/Tab/w returns to the calendar.
At widths below 120 columns, Detail takes the full body instead of selecting
invisible rows below a stacked calendar. Selection follows the viewport at every
width; oversized records keep their title visible. With no Actual rows, Ctrl-u/d
scrolls the remaining Scheduled evidence. In calendar focus, Enter or Esc drills
Year -> Month -> Day; Esc at Day does nothing.

Month/Year summaries consume the same role-aware CalendarMoneyReview as the money
calendar. Every represented Measure is labelled and shown separately, including
unresolved-role counts. In/Out are role-classified directional flow, not all asset
movements or a cash-balance claim. Out/day and Out/month are approximate quanta
quotients over the **full selected calendar period**, not elapsed-period spending
pace or forecasts. Empty flow, not requested, unavailable, and failed reads have
distinct labels. Long summaries remain accessible with Ctrl-u/d and an explicit
overflow indicator. The duplicate Peak Month transaction-count decoration is not
part of this financial summary.

Date/zoom changes reset selection and scrolling. Reloads after workspace edits
clamp selection to current records; rendering and Enter use the same selection.
These are ephemeral presentation states, not additional household authority.
Regression coverage is in `Loam/Tests/TuiHomeNavigation.lean` and
`Loam/Tests/TuiHelpFooter.lean`, run by both TUI CI tiers.

In Day view, an empty Pending set remains visible as `Pending: 0` but does not
allocate a separate empty `Pending Scheduled` section.

The Home labels distinguish the user-facing action from the narrower implementation
module name. `p` edits Actual-to-Purpose routing, `m` admits new Locus identities, and
`o` publishes one complete current quantity observation image.

## Copy and terminal selection

On Home, Actual, Selected Day, Scheduled, Balances, Settlement, and Reports,
`y` copies **the visible screen** as plain text: no ANSI styling, hidden report
rows, or columns clipped beyond the terminal. Home and Reports advertise
`[y] copy screen`; clipboard success/failure is reported in the workspace notice.
The clipboard backend is `pbcopy` on macOS, or `wl-copy` / `xclip` on Linux.

For a partial copy, use the terminal's own text selection and copy command.
With application mouse reporting enabled, many terminals use **Shift+drag** to
select text instead of sending a pointer event to LOAM. The exact modifier is
terminal/profile-dependent; the footer is a hint, not a LOAM-owned selection
engine. LOAM does not implement an independent drag-selection buffer.

## Resize and scroll mechanics

Home, Actual, Selected Day, Scheduled, Balances, Settlement, Capacity, Budget,
and Reports refresh their presentation geometry after input or the idle input
poll. A resize rebuilds the frame/diff baseline; Reports also rebuilds its
geometry-dependent Daily scroll cache. This does not reload household evidence
or change query coordinates. Every emitted frame is additionally clipped to the
live physical tty, protecting against a resize between input and drawing.

Compiled macOS/Linux builds use the small POSIX adapter
`Loam/Tui/terminal_native.c`: `read` returns an available input chunk without the
stdio short-read fill delay, and `ioctl` observes geometry without spawning
`stty` per key. Consecutive same-direction wheel packets in that chunk can share
one redraw; keyboard arrows, direction changes, and following commands remain
separate. The Lean interpreter retains a one-byte input / `stty` fallback for
source-level tests, not production performance claims.

Reports uses dirty-row output for ordinary updates rather than overwriting the
whole terminal on each scroll. Frame text cannot emit control bytes that move
the terminal cursor. Auto-wrap is disabled while the TUI owns the alternate
screen and re-enabled on exit, so a glyph-width disagreement cannot wrap the
bottom row and scroll the entire terminal. Unicode width remains the qualified
approximation in `Loam.Tui.Layout`, not a claim of identical glyph behavior in
every terminal.

Qualification includes `tests/test_terminal_input_latency.py`,
`tests/test_terminal_mechanics_pty.py`, and `tests/test_tui_viewport_pty.py`.
The PTY tests use compiled binaries and synthetic evidence only. Foundation
extractability also compiles the native adapter without LOAM domain modules.

## Surface map

```text
Loam/Tui/Kernel                   Widget / Screen meaning and reconstruction laws
Loam/Tui/Runtime                  compiled sparse-row redraw representation
Loam/Tui/Terminal                 terminal input/output mechanics
Loam/Tui/Calendar                 presentation-only Gregorian calendar projection
Loam/Tui/Home                     production Home presentation
Loam/Tui/DailyPaceTrend           read-only retrospective Daily Pace drill-down
Loam/Tui/ActualWorkspace          Actual workspace presentation state
Loam/Tui/ScheduledWorkspace       Scheduled workspace presentation state
Loam/Tui/SelectedDay              one-date Actual / Scheduled composition
Loam/Tui/Record                   local Movement draft editor
Loam/Tui/AttentionAdministration  current-open Attention management view
Loam/Tui/Balances                 replaceable read-only balance view
Loam/Tui/CycleBudget              current-cycle Budget decision surface
Loam/Tui/Capacity                 Capacity observation and action surface
Loam/Tui/Reports                  explicit-query Reports workspace
Loam/Tui/Cli                      canonical loading, shared action delegation, executable loop
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

Home `a` opens the Actual workspace (`Loam.Tui.ActualWorkspace`). It projects current
Actual records over neutral Loci coordinates, supporting Focus Day and All Current
scopes (`f`), as well as ascending and descending chronology toggling (`s`) so
records can be inspected starting from the newest transaction.

Like the selected-day Actual pane, recording new Movements (`n`) opens the shared
Movement editor and delegates execution to `MovementPublisher`, reloading canonical
evidence after durable writes.

## Scheduled workspace

Home `s` opens the Scheduled workspace (`Loam.Tui.ScheduledWorkspace`). Its
default surface is the **Series Calendar** over the current-open Scheduled frontier
and replaceable `config/scheduled-coverage.tsv` read-side rows.

The ordinary question is visible directly across calendar months:

```text
Plan                        Pace       Oct     Nov     Dec     Jan     Feb
wifi                        monthly    08      08      08      08      !
pension                     every 2m   15              15              !
gpt-plus                    undecided  15
```

A number is the real day of an explicit current-open Scheduled occurrence. Multiple
matching occurrences in one month remain visible, for example `08,18`; larger
multiplicities are shown explicitly as a plan count. `!` means the current
replaceable pace expects an occurrence in that month but no matching explicit
Scheduled occurrence exists. A month that is not expected is rendered as a genuinely
empty cell, not a dot or synthetic `NotDue` fact. Amounts are deliberately absent
from series identity; matching uses the exact negative- and positive-Locus sets.

`h/l` moves the finite month window without terminal-content scrolling. The TUI
loads a wider finite coverage horizon and redraws only the visible columns, so this
surface does not depend on a large horizontally scrolling widget.

Press `v` to cycle the Scheduled projections:

```text
Series Calendar -> Months -> List -> Series Calendar
```

**Months** remains the six-month, two-column calendar-board projection for answering
"what exists in this month?" and for exact occurrence actions. `j/k` selects one
occurrence there. **List** retains the older Focus Day / All Current-Open scopes
(`f`) and Locus filter pane.

The Series Calendar is the primary recurring-plan management surface:

```text
j/k       select recurring plan
h/l       move the visible month window
e         extend / replenish future explicit plans
b         batch amount edit with checked candidates and a final preview
p         change expected pace
Enter     open that plan's exact Scheduled dates

More:
s         future pace undecided
n         create one explicit Scheduled plan
v         Months / List alternate projections
```

The footer mirrors that hierarchy: ordinary plan navigation and maintenance stay on
the first line, while less-frequent creation/state changes and alternate projections
remain visible under `More:`. This is progressive disclosure only; no Scheduled
action or projection is removed.

`e` automatically chooses the latest current-open occurrence matching the selected
plan shape as its construction template and reuses the plan's current monitoring
cadence. Its normal horizon choices are **Next occurrence**, **Next 3 occurrences**,
**Next 6 occurrences**, and **Custom date**. These extension horizons are derived
from the selected cadence itself rather than household/report boundary presets, so
the shortest choice always contains one later cadence slot. If extension starts
from Months/List and the selected occurrence has no monitoring row yet, LOAM asks
for cadence once and continues the same flow. Every generated occurrence remains an
ordinary explicit Scheduled occurrence and is individually reviewable before
publication. The read-side cadence never becomes Scheduled authority.

`p` opens the existing plan-monitoring editor and changes the replaceable expected
cadence. `s` changes only that replaceable read-side row to `undecided`: its
signed-Locus selector and display row remain available, but it expects no future
month and therefore produces no future `!` markers. Existing explicit Scheduled
occurrences are untouched. This keeps "I do not yet know whether this continues"
distinct from both cancellation and a missing payment without introducing canonical
recurrence identity.

`Enter` from the Series Calendar opens Months with the latest matching explicit
occurrence selected. Completion (`c` / `Enter`), replacement (`r`), and
cancellation (`x`) then operate on exact occurrences there. The older `g`
generation and `m` monitoring keys remain compatibility/advanced paths but are no
longer part of the ordinary footer grammar.

### Checked batch amount editing

`b` opens **Batch amount edit** from the Series Calendar, plan detail, Months, or
List. The selected explicit occurrence is an advisory reference, not proof of
series or contract identity. Candidates are current-open occurrences with the
same Measure and exact signed-Locus sets; differing amounts remain visible.
Completed, cancelled, and replaced sources are not candidates.

1. Enter the new amount and an inclusive **From / Through** date range. From is
   initially the workspace's today date and is editable, including for
   overdue evidence. Empty Through means all retained later dates, not automatic
   generation of future occurrences. Decimal amounts use existing Measure
   presentation with exact parsing and no rounding.
2. All candidates initially remain unchecked. Use `j/k` to move, `Space` to toggle,
   `a` to check all, and `d` to clear. `e` returns to amount/range input; re-entering
   the sheet clears previous checks so hidden targets cannot survive a new range.
3. `Enter` previews each changed occurrence's old and new amount. Unchecked rows
   remain untouched; checked amounts already equal to the new amount produce no
   replacement facts. `j/k` reviews a finite scrolling window without truncating
   the batch. **Back** is the initial action; choose **Publish all** explicitly
   with Tab or Left/Right, then Enter. Esc returns to the checklist.

Uniform amount editing supports exactly one FROM and one TO posting. Split
postings require explicit individual editing; LOAM refuses rather than guessing
allocation. Dates, Loci, and Measure remain unchanged.

Publication appends ordinary replacement occurrences and relations, retaining
original Scheduled history and leaving paid Actual untouched. Existing dated
routing assertions are copied to each successor for its retained same-Measure
positive Loci; managed, explicitly unmanaged, and unrouted answers remain distinct.
The complete batch and routing are published in one HouseholdImage transition.
Any stale preview or failed admission publishes none of the batch and returns to
the workspace for reload and a fresh review. Selection and inferred similarity
never become persisted series identity or recurrence rules.

The surface delegates execution to shared publishers and sessions
(`ScheduledCreationSession`, `ScheduledTerminalPublisher`,
`ScheduledReplacementPublisher`), then reloads both canonical Scheduled evidence
and the shared `ScheduledCoverageReview` projection after durable writes.

## Attention

Home `i` opens `Attention / Manage` over the shared `Loam.AttentionReview`
answer. The surface preserves unavailable separately from configured-empty evidence
and keeps `due on`, `no due date`, and `due unknown` distinct.

The TUI may collect Add / Resolve / Drop intent, but durable publication remains in
the shared `HouseholdCommand -> AttentionPublisher` path. After publication the
session reloads canonical `attention.loam` evidence before continuing. The surface
does not invent priority, selected-day membership, or a second lifecycle engine.

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
j/k or up/down  select remembered Purpose
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

Scheduled future coverage is intentionally not duplicated in Reports. It lives with
the Scheduled workspace, next to the creation, fill, monitoring, completion,
replacement, and cancellation actions that change or explain the same future-plan
evidence.

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


### Floating Record panel

On terminals with enough room, the Home `r` entrance opens Record as a centered
floating panel. Compact terminals keep the existing full-screen Record surface.
Only presentation changes; Record validation and publication are shared.
