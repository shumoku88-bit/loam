# LOAM TUI

`loamTui` is LOAM's production terminal frontend.

The TUI owns presentation and interaction state only. Household meaning, admission,
review, and publication stay in shared LOAM boundaries so that TUI, CLI, and future
frontends do not grow separate semantic engines.

UI refinement progress: [非予算 TUI：画面別 UI 改修の進捗](TUI_NON_BUDGET_WORKLIST.md).
It tracks completed and pending presentation work on existing screens, not
feature delivery or trial-readiness gates. Budget screens are outside this queue.
Quality standards and interaction refinement goals: [TUI：操作体験の洗練化と今後の課題](TUI_REFINEMENT_ROADMAP.md).

## Current production entrance

Run from the repository root:

```sh
./tools/loam
```

This launcher asks Lake to check `loam`, then skips Lake while the successfully
checked linked-source/build-input contents and executable identity are unchanged. The
disposable receipt lives at `.lake/build/bin/loam.launcher-check`; deleting it
just requests another check. Timestamp-only saves/checkouts and unrelated test
changes do not request a build. A successful no-op Lake check also settles the
launcher: it does not require a newer executable timestamp.

The receipt uses SHA-256 input hashes and filesystem executable identity
(device/inode/size and high-resolution modification/change times), not a hash of
the large binary on every launch. Missing inputs/inventory, a corrupt receipt,
changed executable metadata, or a failed check cannot reuse it. A missing or
changing linked-input inventory during a build earns no receipt; a later stable
check establishes one. Startup still delegates the build itself to Lake, not a
concurrent-source-edit safety guarantee. If SHA-256 or filesystem
identity inspection is unavailable, the launcher falls back to Lake each time.
Use `LOAM_FORCE_BUILD=1 ./tools/loam` to force a check, including after changing
the installed compiler/build environment without changing repository inputs.

`tests/test_launcher_build_check.py` covers repeated no-op startup, real Lake
content changes (including restored mtimes), receipt invalidation and refusal.
On macOS x86_64, four alternating synthetic PTY runs per method measured warm
median startup of 1,240 → 197ms with 100 Actuals and 1,441 → 402ms with 10,000
Actuals; the previous launcher called Lake on every run, the revised launcher
only on its first unconfirmed run. These are local startup observations, not a
universal speed budget or real-household-data measurement.

Pass an optional data directory via `./tools/loam tui LOAM_DATA_DIR`.

For debugging, `lake build loamTui` followed by `./.lake/build/bin/loamTui`
also works. Do not run the binary directly after changing sources without
rebuilding it first.

`LOAM_DATA_DIR` may select the household data directory; otherwise `loamTui` uses
`../loam-data`. The selected directory is also the production Actual authority root,
and normalized Actual evidence is retained in the required `Actual` section of
`household.loam`. Production root reads and writes do not fall back to the legacy
standalone `actual.loam` diagnostic/migration file.

## Home grammar

### Bonsai Home

`./tools/loam` starts a quiet, centered Home with an
ASCII bonsai above a small `loam` name. The hand-drawn tree uses green leaf
texture, a normal-contrast trunk and a muted pot; it adds no animation, random
generation or external dependency. Its foliage quietly grows with the distinct
known occurrence dates of **current Actual records**, using the already-admitted
Home snapshot, never extra household reads or saved game state.

Six fixed silhouettes start at 0, 1, 3, 7, 14 and 30 recorded dates; 30 or more
keeps the previously approved mature bonsai. Existing recorded dates count too,
so a household with 30 or more already starts mature. These are visual steps, not accounting
laws, a score or a completeness claim. Same-day entries, amounts, descriptions,
Measures, Scheduled plans, Calendar focus and streaks do not change growth.
The date means the Actual occurrence date, **not when the user typed the entry**;
unknown/invalid dates are not guessed. Superseded Correction targets do not count;
reversals do not erase still-current Actuals. Changes to current dates/frontiers
reconstruct the tree, so a correction may change its silhouette. Time alone never
shrinks it: no decay, missed-day penalty or retained high-water mark. Existing
successful-publication reloads refresh growth; cancelling cannot grow it.

Home keeps six entrances: `r` Record, `s` Scheduled, `g` Calendar, `a` Actual, `b` Balances,
and `d` Daily Pace. `Enter` also opens Calendar; `i` opens Attention and `Space`
keeps the full Commands palette. No totals or household completeness claims are
added. The whole bonsai folds into a compact `loam` title before it would crowd
the entrances; 80×24 fits the tree, and 32×9 retains all six entrances. Notice feedback and two operation rows stay at the bottom.

Child workspaces return to their launching surface. Calendar `g` / `G` returns
directly to Home, and Calendar-focused `Esc` / `q` returns there one level at a
time (Detail and Help keep their own back behavior). Only Home `q` exits.
Calendar date, zoom and selection survive that round trip. Home shows that
selected date (initially today), matching the date seeded into Record, Actual and
Scheduled; it does not label an old Calendar focus as today. Household reads and
publishers are the same existing paths; there is no data migration.

The former `LOAM_HOME` opt-in and its enable flag are retired, not retained as a
second startup mode. The existing `tests/test_tui_viewport_pty.py FIXTURE EXE`
now qualifies Home and Calendar in one default-startup session, succeeding the
separate manual `--launcher` invocation without adding a CI lane or duplicate run.

### Calendar workspace

Home `g` / `G` or Enter opens **Calendar**: the date navigator remains the
accounting workspace. The former Summary surface and `c` toggle remain removed;
`g` now means a Home/Calendar round trip, not Summary. Daily Pace, Scheduled,
Actual, and Attention remain available through their individual workspaces.

`Space` opens a short-lived, hierarchical Commands palette with five groups:
**Transactions** (Record, Actual, Exchange), **Plans and attention** (Scheduled,
Attention, Settlements), **Reports and analysis** (eleven direct report/analysis entries),
**Envelope budget** (Budget, Capacity, Purpose routing), and **Household setup**
(Manage Loci, Observe quantities). `↑` / `↓` selects an item, `→` enters a group,
and `←` returns one level (closing the palette at its root). Returning from a
group preserves that group's selection in Commands. `Enter` opens the selected
group or workspace; `Esc` / `q` / Space also returns one level.
Right on a leaf does nothing: opening a workspace requires `Enter`.

Read-only navigation pilot: **Balances** and **Daily Pace / Trend** also accept `Space`
to open the same Commands palette. `Esc` at the palette root cancels and restores
the current workspace's selection, period, focus and scroll; choosing a leaf
returns a navigation request to the root dispatcher and opens that workspace.
An ordinary `q` / `Esc` back still follows the existing parent semantics.
The Daily Pace What-if input modal and all canonical-write editors do **not**
intercept `Space`: their local text input and cancellation rules remain unchanged.
This is deliberately a two-screen trial, not global palette dispatch or a new
navigation-history stack.

The page heading shows the current path. Selecting a leaf delegates to the
existing validated workspace, without changing canonical facts or publishers.

Calendar keeps these direct shortcuts:

```text
Space      Open Commands palette (five groups)
h/l        previous / next day, month, or year (current zoom)
k/j        previous / next week, quarter, or year (current zoom)
t          return calendar focus to today
/          jump to a date, month, or year (Enter confirms; Esc cancels)
z          cycle Day / Month / Year
Tab/w      switch calendar / transaction focus
?          open read-only Home help / complete key grammar and legends
Ctrl-u/d   scroll calendar; page transaction selection in detail
PgUp/Dn    scroll complete Detail evidence without changing transaction identity
Enter      Year -> Month -> Day -> selected-day workspace
(Day view) role-aware money calendar with income, expense, and open-plan markers
r          Record (selected date prefilled)
a          Actual workspace
s          Scheduled workspace
i          Attention administration (I also accepted)
d          Daily Pace trend (D also accepted)
b          Current Balances (B also accepted)
g/G        return directly to bonsai Home
q/Esc      back (Detail -> Calendar -> Home; Help closes first)
```

Attention (`i`), Daily Pace (`d`), and Balances (`b`) are direct Home shortcuts
in both calendar and transaction focus, and also remain in Commands.
Exchange, Settlements, individual reports, Manage Loci, Observe quantities and
optional-budget operations remain palette-only. The old Home Reports shortcut
`v` and the Reports chooser's mnemonic keys are retired; choose the report in
Commands instead.
Each workspace keeps its own local key grammar.

On wide terminals (120 columns and wider), Day Home presents the full
role-aware money grid across six weeks, with Today's underline on the date row only
(not the amount or blank rows), open-plan `!`, and
unresolved-role `?` markers. A daily amount too wide for its cell shows `…`, with
the `?` help legend, never misleading partial digits. Monthly totals wrap below the
grid; a failed money read has a distinct label and a wrapped, scrollable diagnostic.
If money flow evidence is unavailable, the calendar still shows dates and explicitly indicates that the financial projection is
unavailable. The calendar does not duplicate Daily Pace or Attention answers;
use `i` for Attention and `d` for Daily Pace.

Below 120 columns, Day Home keeps two roles: the **Week ribbon** date navigator
above, and selected-day evidence in Detail below. It never merges Actual previews,
daily flow, month totals, legends and full records into one Calendar frame.
The navigator has contiguous Monday-first weekday, date and read-side status rows
(two rows when weekday/date fit together). Selected days have brackets, or a leading
`>` at the narrowest widths; Today remains underlined. `S6` denotes six evidenced
**current-open** Scheduled occurrences, `S+` a positive count too wide for its cell,
and `S?` an unavailable read. A blank marker is not a closed-world NotDue verdict.
All strip rows share column geometry, including month/year crossovers.
Navigator height follows its content rather than a fixed eight-row allocation.
When the complete month overview and Detail both fit, the upper frame also exposes
month totals instead of hiding them above an empty lower frame. Otherwise the
complete week fits first and month totals remain reachable with Calendar Ctrl-u/d.
On short terminals the navigator becomes one unframed date strip, leaving the
remaining rows to Detail; tiny Detail drops its borders rather than all its evidence.
Explicit Calendar browsing may replace that strip with overview rows; date movement
resumes the date strip. The prior session-only `F` toggle remains retired.
The `z` cycle, date jump, and household writes do not change. No guessed week sum or spendable balance is calculated.

Home's selected date is presentation/navigation state. It seeds selected-day,
Actual, Scheduled, Record, Exchange and Reports interactions. It does not redefine
the current-cycle Budget observation date or silently manufacture a household cycle.

Outside Home, `q` and `Esc` mean one-level back. Only bonsai Home `q` exits LOAM; Calendar and child
surfaces do not carry a second application-quit command or a hidden `b` back alias.

Home keeps household evidence in the body and shortcut grammar in the stable footer.
Calendar and Detail use thin rounded frames separated by one blank column in the
wide layout. Only the focused frame uses the existing cyan border; inactive borders,
selection markers and help labels stay muted. Evidence and section headings use
normal contrast rather than treating important body text as a faded annotation. Context occupies
two quiet rows above the frames: known-through date, then navigated focus and zoom.
There are no heavy `=` rules or extra accent colors. Detail's period belongs in its
frame title, and each bottom border shows the visible line range and hidden-row
arrows. Wide terminals give Detail a bounded share of the width while leaving the
remaining space to the money grid.

Two operation rows stay at the bottom: frequent navigation/focus/help, then Record,
Commands and back/Home (plus Today/jump/zoom when width permits). Other direct keys
remain active and discoverable in `?`; no workspace entrance is retired.
The reserved feedback area above them shows compact `s` / `i` read-side signals
when needed and no notice is present. Notices and signals wrap without truncating
counts or causes, including Japanese and unbroken tokens. One-line feedback does
not move frames or operations. Over-height feedback explicitly asks for a larger
terminal. Date-jump input temporarily replaces the operation rows.

`?` opens a read-only framed Help surface with the full grammar and evidence legends.
`j/k`, Up/Down, Ctrl-u/d and Page Up/Down browse; Home/End reach the ends; `?`, Esc or
q closes it. Other keys, including Record, Commands and Enter, cannot escape to
household operations while Help is open. Resize reflows only Help presentation and
closing returns to the underlying date, pane and transaction identity.

Home `d` or Commands > Reports and analysis > Daily Pace opens a small read-only
trend over the already-derived retrospective
current-truth series, including its latest point. The trend does not retain daily
pace as household state or introduce a second calculation.
Help groups navigation by Day/Month/Year or Detail context. In Detail, j/k selects
transactions, Enter opens the selected transaction in its day workspace, and
Esc/Tab/w returns focus to Calendar. The Detail order is daily directional flow,
Actual, selected-day Scheduled, then nonempty/unavailable Pending evidence.
Scheduled's heading retains the selected-date Due count (or Unknown/Unavailable);
nonempty Pending's heading retains its exact count. These are distinct from the
footer signals relative to Today and never infer completeness from a blank marker.
The compact Calendar does not duplicate daily flow or selected-day lifecycle labels;
the wide month grid still has its own daily amounts and period read-state labels. Explicit Page Up/Down
scrolls all Detail evidence even when Actual is nonempty, retaining the selected
identity. Transaction movement resumes selection-following. Month/Year retain their
period transaction lists and compact focused-pane fallback.
Selection follows the available viewport at every width; oversized records keep
their title visible. Descriptions, long Loci and oversized quantities wrap by
terminal columns, including Japanese. Actual Effects and Scheduled changes retain
signed, grouped **quanta** and explicit Measure regardless of optional money-calendar
availability. An inactive Detail retains a muted selection marker without a selected
background. Focus is shown by the existing cyan frame, not an extra `[active]` label.
Enter still opens that exact record in Selected Day for object-local actions.
Shared field presentation: `Loam.Tui.Layout.inputTail` shows the insertion
end of an active, overflowing single-line input with a leading ellipsis;
`Loam.Tui.Layout.ellipsize` retains the beginning of a read-only or unfocused
field with a trailing ellipsis. Both use terminal **column** width, not Unicode
code-point count, and do not alter the retained field value. Record, Scheduled
creation, and Attention reuse these helpers; each screen still owns its label
width, focus, retained input, and publication semantics.

Focus arithmetic: the dynamic Scheduled posting form and the fixed six-position
Capacity transfer form both use the existing `Loam.Tui.CyclicIndex.move`
primitive, as Record and Exchange already do. Each editor still determines its
own focus count, editable/action field meanings, Tab/Shift-Tab handling,
candidate resets, Enter transitions, and publication authority. Shared focus
movement never commits a Locus or changes household data.

Single-line input editing uses `Loam.Tui.InputEdit` for Backspace, typed
characters, and the existing first-line bracketed-paste normalization.
Non-text keys return no edit. Record, Scheduled creation/replacement, and
Attention apply the same pure operation to their active field, while each
editor still owns its own focus, preview, candidate reset, validation,
and publication transitions. This does not introduce generic forms or
override editor-specific actions.

With no Actual rows, Ctrl-u/d scrolls the remaining Scheduled evidence. In calendar
focus, Enter or Esc drills Year -> Month -> Day; Esc at Day does nothing.

Month zoom uses a `Months / YYYY` frame and a quiet twelve-month grid grouped by
quarter. Each cell has a month name (`01 Jan` through `12 Dec`) above its explicit
record count, replacing the ambiguous `51t` / dash shorthand. Columns reflow from
three to two to one without truncating counts; a short automatic viewport starts
at the selected month name if its name/count pair cannot fit from the top. Count
rows never borrow the selection or current-month underline.
Year zoom uses a `Years` frame with aligned Year / Records columns over five
neighboring choices, bounded to the existing 1000–9999 jump/navigation domain.
Both zooms retain brackets for selection and underline for the current period,
with the legend in `?` rather than repeated body prose. A muted horizontal rule
separates navigation from the unchanged per-Measure period flow, partial/read-state
labels and full-period average. Footer Enter labels explicitly say days / months.

Beneath the day calendar, `Month Flow (YYYY-MM)` names the selected month's recorded
`In`, `Out`, and `Net`, with currency formatting and an explicit `Measure:` token.
These are period totals, not balances, budgets, or Daily Pace. All zooms consume the
same role-aware CalendarMoneyReview. Every represented Measure is labelled and shown
separately, including `[partial]` and unresolved-role counts. In/Out are the existing
gross directional flow of role-classified Income/Expense evidence, not all asset
movements: Expense reversals can contribute to In and Income reversals to Out.
Net is In minus Out; different Measures are never added together. Out/day and Out/month are approximate quanta
quotients in Month/Year zoom over the **full selected calendar period**, not elapsed-period spending
pace or forecasts. Empty flow, not requested, unavailable, and failed reads have
distinct labels. Long summaries remain accessible with Ctrl-u/d and an explicit
overflow indicator. The duplicate Peak Month transaction-count decoration is not
part of this financial summary.

Date/zoom changes reset selection and scrolling. In short terminals, Calendar's
viewport follows the selected day (date and its two amount rows when they fit),
month, or year. Explicit Ctrl-u/d browsing releases this follow behavior so summaries
and evidence remain reachable; legends live in `?`. Date navigation, zoom, a successful jump,
or Today resumes it. Resize derives the viewport from live bounds without changing
the selected date. This manual-browsing flag is ephemeral presentation state only.
Reloads after workspace edits
clamp selection to current records; rendering and Enter use the same selection.
These are ephemeral presentation states, not additional household authority.
Home reuses wrapped transaction rows/positions and the width-dependent calendar
and period overview within that immutable read snapshot. Pending remains derived
from the same qualified Scheduled evidence; there is no independent pending cache. Selection renders
only its visible row window; width/date/zoom changes rebuild the projection, and
workspace returns discard it before using refreshed evidence. Transaction-selection
keys and wheel repeat counts remain unchanged; Page Up/Down now owns explicit
read-side browsing. No input is dropped to hide latency.
Year-scroll reproduction and measurement limits:
[`TUI_YEAR_SCROLL_2026-10-10.md`](research/TUI_YEAR_SCROLL_2026-10-10.md).
Regression coverage is in `Loam/Tests/TuiHomeNavigation.lean` and
`Loam/Tests/TuiHelpFooter.lean`, run by both TUI CI tiers.

In Day view, an empty Pending set allocates no section or redundant zero-status row.
Nonempty and unavailable Pending evidence remains explicit in Detail; empty
Scheduled still says Unknown and never becomes a completeness claim.

The Commands labels distinguish user-facing actions from narrower implementation
modules. Purpose routing edits Actual-to-Purpose routing, Manage Loci admits new
Locus identities, and Observe quantities publishes a current observation image.

## Daily Pace / Trend

Home `d` opens a freshly admitted, read-only retrospective current-truth series,
initially selecting the latest day in **10d**. `1`–`5` choose **10d**, **30d**,
**Month**, **Cycle**, **Previous Cycle**. 10d/30d are inclusive calendar-day
windows through the observation day; Month starts at calendar month start; Cycle
starts at the explicit current accounting boundary; Previous Cycle is the adjacent
completed interval from the **same uniquely selected boundary preset**. Every
window contains daily integer-quanta/day samples, never a monthly aggregate.
Each day uses its own explicitly represented cycle end. Missing/ambiguous boundaries
are not extrapolated; unsupported historical evidence is disclosed with its cause.
A refused window is not silently shortened to its available portion.

These are reconstructed from current admitted truth and current query configuration,
not saved daily observations or a replay of what LOAM knew/configured then. Later-added
Scheduled occurrences may affect earlier days. Undated pool-affecting retirement or
replacement still refuses reconstruction. Existing HistoricalBalanceReview and
CycleSpendingPaceReview own all support routing, correction/date interpretation,
completion timing, deductions and pace arithmetic.

The provisional layout gives the upper Braille trend **full usable width**. With
sufficient room (79 usable columns and 15 body-panel rows), History is lower-left
and compact selected-day Detail lower-right. Tall narrower terminals stack the lower
panels. Otherwise `i` opens full-body Detail. At 48×14, Trend still keeps the selected
date, pace, change and a small plot; `list hidden` explicitly marks a hidden history.
History follows the shared graph/detail selection. Range changes preserve the selected
date when included, otherwise clamp to the nearest endpoint; a refused window keeps
the date anchor. Resize preserves range/day and only clamps detail scrolling. This
is a small local policy, not a new generic layout or panel-switch framework.

`h/l` or left/right selects a day in either pane. In Trend, `j/k` or up/down also
selects days; Ctrl-u/d or Page Up/Down moves by visible history rows (one day if the
list is hidden), and Home/End reaches the first/last point. `i`, Enter, Tab or
Shift-Tab toggles Detail. There `j/k`/arrows, pages and Home/End scroll full wrapped
values, change, inclusive display range, cycle end, remaining days, pool, Scheduled
deductions, arithmetic basis and reconstruction explanation. `q`/Esc leaves Detail first,
then returns to Home. Feedback has a reserved row above two fixed operation rows.
Idle resize reflows/clamps presentation only and returning Home preserves its date.

Pace and change display the exact **integer quanta/day** returned by
`CycleSpendingPaceReview`, grouped with their explicit Measure, without optional
money scales. Values too wide for the summary/table/axis use `see details` or `…`,
never partial digits; full selected values and long Measure tokens wrap in Detail.
Not-requested, unavailable, failed reads and loaded-empty series remain distinct;
failed causes, including long Japanese tokens, are scrollable in Detail. A missing
pace does not become zero. A mixed-Measure series is not plotted or subtracted
across Measures. Chart values above magnitude 10²⁴ are explicitly unplottable here,
before the shared renderer's bounded nice-step search can expand excessive ticks;
the valid quantities remain available in Detail, not relabelled as missing history.

Period preparation happens once per fresh entry from one admitted Actual/Household
and Scheduled generation. Overlapping presets reuse each reconstructed day; historical
effects are bucketed once per selected coordinate. Cursor, paging, range selection
and idle resize perform no household IO or accounting reconstruction. History expands
only visible rows; the shared chart uses indexed sampling rather than traversing the
whole daily list per raster cell. Re-entry discards old prepared information.

Qualification: `DailyPacePeriods`, `CycleSpendingPaceReview`, `HistoricalBalanceReview`,
`TuiDailyPaceTrend`, `TuiChart`, `TuiHomeActualGeneration` tests and synthetic
`tests/test_daily_pace_pty.py` / `tools/benchmark-daily-pace.py`. Costs and limits:
[Daily Pace periods evidence](research/TUI_DAILY_PACE_PERIODS_2026-10-10.md).
Arbitrary input windows, past-cycle traversal and overlaid comparison are deferred;
inclusive start/through coordinates leave room for those later questions.

## Selected current balances

Home `b` opens **Balances / Current** in `balance-view` configuration order,
normalizing duplicate Locus × Measure selections only. This neutral current
projection is not the role-aware Reports / Balances or an Account taxonomy.
`CurrentBalanceReview` remains the owner of exact, present-but-amount-unknown,
and unsupported answers; exact zero is never inferred from either unknown state.

The table aligns Locus, signed grouped **quanta**, Measure and support state.
At 120 columns and sufficient height, quiet rounded table and Detail frames sit
side by side; narrower terminals stack them, and short terminals show Detail
alone when focused. Narrow table rows combine Locus / Measure with value or state.
Clipped coordinates use `…`; oversized quantities use `see details` or `…`, never
partial digits or a combined multi-Measure total. Detail wraps full identifiers,
exact signed quanta and support explanations without optional money scales.

`j/k` or arrows selects a row; Ctrl-u/d or Page Up/Down moves by visible data rows,
and Home/End reaches the first/last row. Selection follows the viewport. `i`, Enter,
Tab or Shift-Tab toggles Detail; its arrows/page/endpoint keys scroll wrapped lines.
`q`/Esc returns from Detail to the list, then from the list to Home. `p` retains the
bounded Print entrance. Feedback has a reserved row above fixed two-row operations;
long causes wrap, and over-height feedback/help has an explicit overflow indicator.
Live resize clamps presentation offsets only. Home re-observes tty geometry on return,
without a household reload or a change to Calendar focus.

Qualification: `Loam/Tests/TuiBalances.lean` (also in representative TUI tests),
`tests/test_balances_pty.py` in both TUI CI tiers, and adjacent CurrentBalanceReview /
Reports Print tests. All native interaction fixtures are temporary and synthetic.
This completes UI-24 only, not Reports / Balances or the shared Print prompt's UI work.

## Terminal selection and plain-text reports

The retired `y` command no longer copies the visible TUI screen. Its
clipboard backend and the `Shift+drag` footer hint have been removed.
Ordinary terminal text selection remains controlled by the user's terminal:
in some terminal profiles, holding Shift while dragging selects text even when
TUI mouse reporting is enabled. LOAM does not own text selection or provide a
scrollback buffer inside its alternate-screen interface.

For a long report that should behave like ordinary terminal output, leave the
TUI and use the existing plain-text CLI reports, for example
`./tools/loam report balances` or `./tools/loam report loci`.
These write to standard output and can be selected across terminal scrollback
according to the terminal's own settings. Other report types may need a future
plain-text export; removing `y` does not by itself enable scrollback in the TUI.

## Bounded terminal Print view (initial Balances rollout)

Within **Balances / Current** or **Reports / Balances**, press `p` to prepare a
plain-text report using the same current read-only review evidence. This leaves
the alternate-screen TUI temporarily. LOAM displays the exact prepared line
count and UTF-8 byte count, warns that household content can persist in normal
terminal scrollback, and asks for explicit `y` + Enter consent. Any other answer
cancels without printing report lines. After copying or scrolling, Enter returns
to the TUI with its terminal modes and viewport restored.

Current Balances prints all configured selected rows from its current read snapshot,
not just the keyboard selection or visible window. Full Locus/Measure identifiers,
exact grouped quanta and support labels are preserved independently of table clipping.

The shared boundary refuses reports above **200 logical lines or 32,768 UTF-8
bytes** *before emitting any report line*. There is no automatic truncation,
silent fallback, clipboard access, file creation, or unbounded "print all"
mode. The richer Reports/Balances projection also has a conservative 70-balance
evidence gate before expanding its repeated Balance Sheet / Trial Balance
presentation. If these checks refuse, use an explicit narrower selection or a
future ranged report. This rollout does not enable printing the entire Actual
or Scheduled lifetime history; those producers need explicit range/filter UI
before joining the shared print boundary.

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

## Resource and scaling qualification

`tools/benchmark-tui-resources.py` runs repeated read-only workspace visits and
idle intervals on a temporary synthetic HouseholdImage. It reports operation
latency, RSS, CPU time, FD counts and descendant processes. `--check` qualifies
quiet idle, stable sampled FDs, no retained children, ordinary terminal cleanup,
and unchanged fixture bytes; it does not prove long-duration leak freedom.

```sh
lake build loamTui
python3 tools/benchmark-tui-resources.py --check --cycles 100 --idle-seconds 3
python3 tools/benchmark-tui-resources.py --check --events 10000 --cycles 5
```

Home startup and reload share one fully qualified Household generation across
Actual, Scheduled, canonical Attention, Pace support and AccountingRole. Family
refusals remain explicit; independent configuration reads are not an atomic part
of that generation. Writer entrances still freshly select authority.

The measured repairs and remaining pressure shapes are recorded in
[the bounded resource qualification](research/TUI_RESOURCE_QUALITY_2026-10-09.md).

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

### Selected Day workspace

Home Calendar Enter enters **Household Day Workspace**
without changing its fixed day coordinate. At 100 columns and wider, Actual and
Scheduled use separate quiet rounded lists with one blank column between them.
Narrower terminals give the active list the full width; `h/l` or Left/Right still
selects Actual/Scheduled. Only keyboard focus uses the existing cyan border and
selected-row background. Inactive lists retain a muted `*` selection marker.

Actual aligns Description and right-aligned Quanta. A simple row shows one explicit
positive Effect, not inferred spending or a balance; split Effects and multiple
Measures show `split` / `multi (count)` instead of an invented total. Scheduled
aligns the signed-Locus Shape and its simple receiving quanta, with split movements
left explicit. Long labels end in an ellipsis; an oversized quantity says
`see details`, never partial digits. The day is in the context row rather than
repeated in every list row. Headers may disappear on short terminals before a
record row does. Bottom borders show selected position and hidden rows.

The bounds-sized **Selected Actual / Selected Scheduled** frame puts exact signed
Effects first, then description (Actual), date, and complete identity. Quanta remain
retained quanta with grouped digits and explicit Measure tokens; this does not
rely on optional money-calendar roles/scales or perform conversion. Long Loci,
quantities, descriptions and IDs wrap by terminal columns, including Japanese.
Effect columns are bounded to a readable width even in a very wide detail frame.

`i` / Tab / Shift-Tab toggles Detail focus. In Detail, `j/k` and wheel motion scroll
wrapped lines; Page Up/Down or Ctrl-u/d pages the visible detail rows, and Home/End
reaches the actual top/bottom. Esc/q/i/Tab returns to the list; `h/l` selects a list.
When a separate detail region cannot fit, focused Detail takes the full body and
returning restores the list. In list focus, Page Up/Down moves by visible data rows
(excluding borders and the column heading), and Home/End selects first/last. Resize
clamps only local offsets; selection changes and canonical reloads reset Detail to
the top. No action or object identity is inferred from similarity or layout.

Two operation rows and a reserved feedback row stay below the panels in both panes.
An ordinary one-line child-return notice cannot move borders or disappear below
the body, including at 48×14. Longer refusals wrap completely while they fit; if
feedback/help exceeds the entire height, an explicit overflow hint asks for a larger
terminal. Compact operation labels are abbreviated without changing bindings.
After a child editor or Selected Day itself returns, the caller re-observes terminal
geometry before the first redraw, rather than clipping a frame built for an old
size. This geometry query does not reload household data. In particular, cancelling
an unchanged Record draft still returns over the existing snapshot without a
household re-read. Successful writes retain their existing canonical reload path.

Unknown Scheduled evidence and unavailable reads remain distinct from an admitted
empty Actual list. Unknown/unavailable Scheduled headers and details do not display
an invented zero count or claim NotDue. Full diagnostics remain reviewable in
Detail. Record, Correction/date/reversal/Merchant, Manage Loci, and Scheduled
create/complete/cancel/replace still delegate the same shared actions; their child
editor refinements are separate UI work items.

## Actual workspace

Home `a` opens the Actual workspace (`Loam.Tui.ActualWorkspace`). It projects current
Actual records over neutral Loci coordinates, initially showing **All Current,
newest first**, even when the selected Calendar day has no records. `f` narrows to
that selected day (Focus Day); another `f` restores All Current. Corrected/replaced
old records remain excluded from the current list. `s` toggles ascending/descending
chronology; Calendar / Selected Day retains its independent date-focused entrance.

The workspace uses thin rounded panels: Loci and selected details on the left,
with a full-height Actual list on the right when the terminal is wide enough.
The sidebar targets 30% of the writable width, bounded to 34–50 columns so larger
terminals give their extra space to the Actual table. Long Locus labels show an
ellipsis rather than silently clipping. The palette is deliberately restrained:
inactive borders, headings, and shortcut help stay muted. Only the focused panel
uses the existing cyan border, an explicit active label, and (for lists) the
selected-row background. Prefer alignment, spacing, and hierarchy over adding
colors; accents should serve a demonstrated need, not decorate each pane.
The terminal's palette and background remain user-controlled.
The two-line context distinguishes scope from the known-through date. Panel
headings show order, and bottom borders show selection position and overflow.
`h/l` or Left/Right and Tab/Shift-Tab cycle Loci, Actuals, and Details;
`i` focuses Details, where `j/k` scrolls and Esc returns to Actuals.
In a low terminal that cannot fit a separate details region, focusing Details
replaces the list with a full-body Details panel; Esc restores the list. A visible
inactive list keeps its selection marker without claiming keyboard focus.
`/` searches across all current evidence; Enter keeps the search and Esc clears it.
Search uses the existing context row rather than adding a row above the list.
Boundary notices have a fixed, muted status row when space permits; tiny terminals
show the notice in the last help row. Search and notices do not move panel borders
or change how many records fit.

`PageUp` / `PageDown` move by the focused pane's visible data rows, excluding
borders and the Actual table's column heading. `Home` / `End` reach the real first
or last position, including the end of a long wrapped Details record. `j/k` and
batched wheel motion stop at the same boundaries, so one upward step moves content
immediately after reaching the bottom. Resizing clamps the Details offset to its
new viewport without changing the selected Event. A new record selection, filter,
order, search, or canonical reload starts Details at the top. This is presentation
navigation only; opening and publishing still use the existing shared boundaries.

The Actual list aligns Date, Description, and right-aligned Amount columns.
Descriptions visibly end with an ellipsis when clipped. Very narrow panels show
Description only, and very short panels omit column headings before sacrificing
a record row. Amounts use the shared exact decimal conventions and grouping while
retaining explicit Measure tokens. A simple row shows its single positive Effect
amount, not an inferred expense or account balance. Multiple positive or negative
Effects show `split`; multiple Measures show `multi (count)` instead of an invented
total. Missing Effects show `—`, not zero. Amounts too wide for their column show
`see details`, never a partially clipped number. Details put the signed Effects
first, followed by the complete description and exact Event identity. Descriptions
and IDs wrap by terminal-column width, including Japanese text, and remain
scrollable rather than silently clipped. Oversized Effect amounts use explicitly
labelled wrapped lines instead of partial numbers. Date, Effect count, and identity
use muted text; there is no duplicate internal heading or redundant Current status.
Panel sizes stay fixed across records, and content and overflow arrows share one
clamped viewport. The initial scope is presentation-only; filter meanings, selection
identity, and household authority are unchanged.

Like the selected-day Actual pane, recording new Movements (`n`) opens the shared
Movement editor and delegates execution to `MovementPublisher`, reloading canonical
evidence after durable writes.

### Single-transaction detail and actions

Actual list / preview Enter opens **Actual / Transaction detail**, not Selected Day
and not an automatically active editor. It shows only the chosen Event: exact
signed quanta and explicit Measures at each Locus, description, occurrence date
(or explicitly unknown), complete ID, correction-frontier currentness, retained
reversal endpoints and Merchant disposition. Missing Merchant evidence remains
`Unresolved`, never Nonmerchant. Reversal does not remove the original from the
correction frontier; `Reversed by` names the retained inverse Event separately.
These record-local fields come from the same admitted Actual generation as the
rest of the shared review, not a second household read or new retained state.

Actions reuse SelectedDaySession's existing editors / writers:

| Key | Existing operation |
| --- | --- |
| `c` | Correct contents, including description, through Correction Preview |
| `d` | Change occurrence date through date Preview |
| `r` | Exact inverse Reversal through date / Preview |
| `m` | First Merchant / Nonmerchant classification through Preview |
| `g` | Shared Locus administration |
| `n` | New Movement recording, seeded by the known occurrence date |

The date-change editor has a bounded current/proposed date panel with a selected
editable value, exact target identity, and distinct Preview/Publish step. Its
feedback and shortcut rows stay at the bottom while the shared publisher owns
the final re-check.

Reversal is an **inverse Event**, not deletion or contents correction. Its framed
date input shows the selected target and the separately chosen reversal date.
Preview retains the original target, shows the exact signed inverse postings
with a scrollable viewport (Up/Down, PgUp/PgDn, Home/End), and places the
explicit publish action below a retained-original warning. Very short terminals
cannot publish when no inverse-posting line is reviewable. The same shared
publisher independently re-derives and checks the exact inverse before writing.

The action list uses the existing editor representability checks; unsupported
correction/reversal shapes do not advertise those actions. Already reversed or
reversal Events do not advertise contents correction / reversal, and classified
Events show their disposition instead of advertising first classification.
Shared publisher current-world, relation/discharge, Scheduled-completion, writer
and other authority checks remain decisive; shortcuts still surface existing
refusals rather than introducing a parallel permission engine.

`j/k` / arrows / wheel scroll the wrapped record and action rows, Page Up/Down or
Ctrl-u/d pages visible rows, and Home/End reaches the top/actions. On short/narrow
terminals all content remains scrollable in the same bounded frame; idle resize
clamps the local offset without changing Event identity. Esc/q returns directly
to Actual in one step. Search, scope, chronology, pane and selection are preserved;
Locus and Event selection are re-anchored by stable tokens after reload. The list's
viewport remains selection-following, including an unchanged preview offset.

After an editor returns, existing canonical reloads refresh the same Event even
when its date changes. A replaced/missing Event shows an explicit unavailable
message and its original ID, never stale Effects or an unrelated day row. Esc/q
then returns to the same filtered Actual list with a nearest-row fallback and
notice if the original no longer matches. A successor is not inferred from shape
or description. Cancel before confirmation publishes nothing. Home's fixed-date
Actual/Scheduled browser and all of its operations remain separate and unchanged.

### Actual Correction input and confirmation

Selected Day's Actual and single-transaction detail `c` action opens a bounds-aware Correction editor. It shares
Record's aligned fields, framed Postings/candidates, active-field tail and IME
caret, focus-following compact viewport, feedback row, and two operation rows.
The date is labelled `Date (kept)` and remains unfocusable; the target context is
muted, with an ellipsis if necessary. Original amount is not edited here.

Correction Preview separately labels **Before / selected snapshot** and
**Replacement**, retaining exact signed Effects and Measure tokens, descriptions,
kept date, and the complete target identity. Long content wraps and can be reviewed
with arrows, Page Up/Down, and Home/End; actions and two navigation rows stay fixed.
Idle resize rebuilds geometry and clamps review offsets without reloading or
publishing. The before snapshot is display-only, not fresh household authority.
Publish still appends an explicit Correction and replacement Event through the
shared publisher's current-world recheck; the original Event stays retained.
Enter in the input opens Preview, not publication. Esc cancels Correction.

## Scheduled workspace

Home `s` opens the Scheduled workspace (`Loam.Tui.ScheduledWorkspace`). Its
default surface is the **Series Calendar** over the admitted open/completed
Scheduled evidence and replaceable `config/scheduled-coverage.tsv` read-side rows.
Its first column is the current observation month, not the following month.

Series Calendar uses the same restrained rounded frame as Actual: muted context
and help, the existing focus accent, and a selected-row background only. The
known-through date and finite month window stay above the table; its bottom border
shows selection position and hidden rows. The vertical window follows the selected
plan instead of leaving it off-screen. Narrow screens reduce Plan width (with a
visible ellipsis) before cutting a month column; very narrow tables omit Pace.
Narrow screens abbreviate operation hints; short screens omit the column heading
before sacrificing the only plan row. The day/gap legend sits immediately below
the frame, separate from the operation bar. Publisher refusal feedback keeps its
complete wrapped text. Completed evidence now covers a monitored month without
remaining actionable; monitoring selectors and Scheduled publishers are unchanged.

The ordinary question is visible directly across calendar months:

```text
Plan                        Pace       Oct     Nov     Dec     Jan     Feb
wifi                        monthly    08✓     08      08      08      !
pension                     every 2m   15              15              !
gpt-plus                    undecided  15
```

A number is the retained day of an explicit current-open Scheduled occurrence.
`08✓` means that occurrence is completed; the day is its Scheduled date, not the
Actual payment date. Completed-only cells are muted except on the selected row.
Multiple dates remain visible, for example `08✓,18`; when they do not fit, `2p/1✓`
shows open and completed counts. `!` means the replaceable pace expects an occurrence
in that month but neither matching open nor completed evidence exists. Cancellation
and replaced sources do not cover a month. A completion reference without its Actual
Event remains open, as in the existing lifecycle reader.

This is a month-level presence check, not a claim that every obligation in a month
is covered. Expected days are never inferred from the monitoring anchor. Overdue
open dates remain visible; passing a date does not complete it. A month without
expectation or retained open/completed evidence is genuinely empty, not synthetic
`NotDue`. Amounts are deliberately absent from series identity; matching uses the
exact negative- and positive-Locus sets.

`h/l` moves the finite month window without terminal-content scrolling. The TUI
loads a wider finite coverage horizon and redraws only the visible columns, so this
surface does not depend on a large horizontally scrolling widget.

Press `v` to cycle the Scheduled projections:

```text
Series Calendar -> Months -> List -> Series Calendar
```

**Months** remains the six-month, two-column calendar-board projection for answering
"what exists in this month?" and for exact occurrence actions. `j/k` selects one
occurrence there. Six thin rounded month frames replace the heavy screen rules;
only the month containing the selected occurrence uses the existing focus accent.
Day, signed-Locus shape, and right-aligned exact quanta stay separate. Long shapes
show an ellipsis; split quantities are never summed, and oversized quantities say
`too wide`. Frame bottoms show explicit counts and hidden-row indicators, without
asserting NotDue or generating future occurrences.

Months geometry depends on terminal bounds, not on the selected movement's number
of changes. Taller screens grow the month windows. The fixed-height Selected
Scheduled panel puts signed expected Effects first, then muted date and exact ID;
wrapping and an overflow label make hidden detail lines explicit. At 80 terminal
columns the two-column board fits; narrower or very short screens explain the List
fallback while retaining selected details when space permits. Failed Scheduled
reads show Unavailable instead of six fabricated empty months.

**List** retains Focus Day / All Current-Open scopes (`f`) and exact Locus filtering.
Its quiet Loci and Scheduled frames use the existing focus accent only on the
active pane. The occurrence table aligns Date, signed-Locus Shape, and right-aligned
Quanta; split quantities remain explicit rather than becoming totals. Each frame
shows selection position and hidden rows. At 80 columns and wider both panes stay
visible; narrower terminals give the focused pane the full width, and `h/l` switches
between them without changing the underlying filter or selected occurrence.

The shared Selected Scheduled panel keeps signed expected Effects, date, and exact
ID in a bounds-sized viewport, so selection and short notices do not resize List.
Long labels show an ellipsis. Unknown day evidence, unavailable Scheduled reads,
and an admitted empty current-open inventory remain distinct in both pane labels
and content; no unreadable evidence becomes a zero count or NotDue claim.

The Series Calendar is the primary recurring-plan management surface:

```text
j/k       select recurring plan
h/l       move the visible month window
e         extend / replenish future explicit plans
b         batch amount edit with checked candidates and a final preview
p         change expected pace
Enter     open that plan's exact Scheduled dates
q         return to Home
s         future pace undecided
n         create one explicit Scheduled plan
v         Months / List alternate projections
```

All four Scheduled projections share an operation-only **two-row footer**:
selection, Enter, and back on the first row; maintenance on the second. Keys use
the existing normal foreground while labels and spacing stay muted—no extra accent
colors. At 80 columns and wider, all advertised maintenance actions fit without
wrapping; `batch` means batch amount editing, `views` means Months/List, and Months
advertises its direct `v` switch to List. Narrow
screens abbreviate hints but do not remove any binding or action. Table meaning
(days, gaps, pace, quanta) stays next to the frame rather than among shortcuts.

A separate feedback row is reserved above the operation bar, even with no notice.
Ordinary one-line feedback therefore cannot move the table or shortcuts. Longer
publisher refusals wrap into additional feedback rows, including long unbroken
tokens: preserving the complete cause takes priority over fixed table height in
that case. No Scheduled publication or selection semantics change.

`e` automatically chooses the latest current-open occurrence matching the selected
plan shape and monitored cadence before the first missing month as its construction
template (or the latest matching open occurrence when there is no gap) and reuses
the monitoring cadence. If there is no open template before a gap, use `n` to create that explicit
occurrence; the monitoring anchor is not enough evidence to invent its date or movement. Its normal horizon choices are **Next occurrence**, **Next 3 occurrences**,
**Next 6 occurrences**, and **Custom date**. These extension horizons are derived
from the selected cadence itself rather than household/report boundary presets, so
the shortest choice always contains one later cadence slot. If extension starts
from Months/List and the selected occurrence has no monitoring row yet, LOAM asks
for cadence once and continues the same flow. Every generated occurrence remains an
ordinary explicit Scheduled occurrence and is individually reviewable before
publication. The read-side cadence never becomes Scheduled authority.

After a successful Scheduled completion, continuation guidance is a separate
bounded step. When similar later current-open Scheduled evidence exists, Keep as
is / Add another / Review remain explicit. Review keeps the full wrapped
read-only evidence navigable with j/k, PageUp/PageDown and Home/End, with Esc
returning to those choices. When no candidate exists, Done / Defer / Add next
remain distinct; Defer still records unfinished intent in Attention with unknown
due timing. Narrow terminals keep all three choices visible with a fixed
navigation footer. A resize reflows presentation only and never creates a plan.

The horizon and cadence choices and the final edited-occurrence review now use bounded
lists and a stable action/notice footer. On short terminals their rounded frames
collapse before hiding the active choice. During final review, `j/k` or Up/Down
move the selected occurrence, and Home/End jump to the first/last draft without
changing the chosen Publish all / Cancel action. Tab or Left/Right still chooses
that final action; Enter confirms it. Resizing reflows the same process-local
review state, without creating extra plans or changing publisher authority.

`p` opens the existing plan-monitoring editor and changes the replaceable expected
cadence. The monitoring chooser now uses a focus-following **Expected pace**
panel with five explicit cadence options, bounded notice/help rows, and the
same live-resize geometry as the post-creation chooser. Up/Down or j/k moves,
Enter saves the selected monitoring cadence, and Esc/q cancels unchanged.
The panel scrolls on short terminals so the highlighted cadence remains
visible. This is a read-side monitoring choice only: it neither creates a
future Scheduled nor claims a canonical recurring series.

`s` changes only that replaceable read-side row to `undecided`: its
signed-Locus selector and display row remain available, but it expects no future
month and therefore produces no future `!` markers. Existing explicit Scheduled
occurrences are untouched. This keeps "I do not yet know whether this continues"
distinct from both cancellation and a missing payment without introducing canonical
recurrence identity.

`Enter` from the Series Calendar opens focused **Plan Detail**. Its quiet rounded
frame aligns Date/Month, Status, and right-aligned Quanta columns. Quantities show
exact grouped retained quanta with the Measure token, without assuming a currency
scale or conversion. Split movements show their change count rather than a sum;
oversized quantities say `too wide` instead of showing misleading partial digits.
Explicit on- and outside-pace dates remain visible beside presentation-only
monitored gaps. The selected row stays inside the visible table, with position and
hidden-row indicators in the bottom border. Very narrow screens show date/status
only; narrow screens abbreviate operation hints and short screens can omit the
column heading. A reserved
feedback row prevents ordinary boundary notices from shifting the frame, while
long publisher refusals retain their complete wrapped text. Failed Scheduled or
coverage evidence shows Unavailable, never a fabricated empty plan or gap list.

Completion (`c` / `Enter`), replacement (`r`), and cancellation (`x`) operate on
exact explicit occurrences; a MISSING row is not a Scheduled occurrence and cannot
be completed, replaced, or cancelled. Completed dates shown in the Series Calendar
are read-only context; Plan Detail continues to list actionable current-open dates
and genuine monitored gaps, not completed history. `q` returns to the Series Calendar.

The Scheduled completion editor now distinguishes the immutable **Plan reference**
(ID and expected due date) from the editable **Actual draft** (new Actual date,
description, Measure and signed postings). Tab moves among the original Record
fields and explicit actions; the editing pane follows the active field even
at short heights. Preview shows a scrollable **Actual effects (to record)**
list with exact signed quantities, Actual date and a retained Plan-reference
link. Up/Down, Page Up/Down and Home/End review the effects; the bottom
Publish/Edit/Cancel controls remain visible. If fewer than two review rows
fit, Enter on Publish refuses and asks to enlarge the terminal. This is a
presentation guard only: the actual publication still writes one Actual Event
plus its explicit Scheduled completion relation via existing authority.
The child session follows live terminal resize; no completion or continuation
semantics have been changed. The unresolved-Locus activation subdialog retains
its existing Record-owned semantics.

The Scheduled cancellation confirmation has a bounded **Expected effects**
review, with the selected due date and retained Scheduled identity above it.
Long identity text and signed posting rows remain reachable by Up/Down,
Page Up/Down and Home/End. The bottom actions always default to **Keep**;
Tab/Left/Right select between Keep and **Cancel Scheduled**, Enter confirms,
and Esc keeps the occurrence. Retirement evidence remains retained; this never
silently deletes the Scheduled. The child session follows live terminal resize.
If the terminal has no review rows available, Enter on Cancel refuses until
the terminal is enlarged; this is only a presentation safety gate. The older
`g` generation and `m` monitoring keys remain compatibility/advanced paths but are
no longer part of the ordinary footer grammar.

### Scheduled creation review (UI-16, first slice)

The existing `n` entrance collects an explicit due date and two to six signed
postings with the existing Locus picker. Its editor remains a separate refinement
task. Enter from the last posting or the Preview action opens a confirmation
without creating any household evidence.

The confirmation uses a fixed summary for the due date and Measure, a bounded
scrollable list of **every** signed posting and the balanced total, and a reserved
notice/action/navigation footer. Positive quanta have an explicit `+`, and long
Locus tokens, large exact quanta, and Measure tokens wrap by physical terminal
columns rather than being silently clipped. Up/Down, Page Up/Down, Home/End
review the postings independently of Tab/Left/Right action selection. The bottom
border shows line position and overflow arrows. When fewer than two posting
lines are visible, Enter on Publish refuses with a request to enlarge the
terminal; Edit and Cancel remain available.

This is a presentation-only review refinement. It does not create an Actual,
recurrence, replacement relation, or new Scheduled authority. Final publication
still goes through the existing shared household command. The editing surface now keeps the selected Due or Posting field inside a
focus-following framed viewport. The candidate summary, action choices, and two
navigation rows keep stable positions as the user moves across fields. Larger
terminals show an additional bounded Locus candidate panel; compact terminals
retain a selectable candidate summary without pushing the action bar away.
While the Posting Locus field is focused, Up/Down highlight catalog candidates,
**Enter commits the highlighted token to the Posting and advances to Amount**,
and Right commits without advancing. Tab only moves focus and does not commit
the suggestion. Already exact Locus tokens remain unchanged on Enter.
Long values show their editable tail with a visible ellipsis; full stored
input and the existing publication authority are unchanged. The ordinary Scheduled creation editor and its confirmation now re-measure the
terminal while open, retaining entered values and focus and rechecking the
minimum review height against the *current* size before Publish. The optional
post-create expected-pace chooser and the per-occurrence draft collector
also reflow their own screens on a resize. The wider Scheduled workspace remains
responsible for refreshing its parent frame after a child session returns.
Other non-Scheduled editors continue to use their existing terminal behavior.

After the **ordinary** `n` creation flow successfully publishes one explicit
Scheduled, a bounded **Expected pace** follow-up appears. It defaults to
`This occurrence only` (no monitoring change); the user may instead choose
Monthly, Every 2/3/6 months, Yearly, or Future pace undecided. Esc keeps the
already-published occurrence and leaves any existing monitoring untouched.
Choosing a pace writes only the replaceable read-side Scheduled coverage rule,
anchored to the newly published occurrence's date and exact signed-Locus shape;
a pre-existing rule for the same shape may therefore be updated. It never
creates another Scheduled or canonical recurrence. Future explicit occurrences
are still added by the separate `e` flow with per-occurrence review. This
follow-up is not shown while generating multiple drafts or when explicitly
continuing a completed Scheduled; those paths keep their previous contracts.
If the just-published Scheduled cannot be re-read, creation remains successful
and the status explains why pace setup was unavailable. Current child-editor
resize behavior remains a distinct UI-16 follow-up.

### Scheduled replacement Locus picker

The explicit Scheduled replacement editor (`r` on a selected occurrence)
keeps the original date and signed posting values until the user edits them.
When a Posting Locus is focused, Up/Down changes the highlighted entry in the
currently write-admitted token catalog. Enter commits the highlighted **stable
Locus token** and moves to Amount; Right commits while staying on Locus.
Tab changes focus without accepting the candidate. An already exact admitted
token is kept unchanged; if no admitted candidate matches, existing typed text
is retained for the publisher's normal validation rather than silently
replaced. This picker shares `LocusPicker.commitToken?` with Record and
Scheduled creation. Display metadata never admits or remaps write identities.

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

The checklist and replacement preview share bounded, cursor-following rounded
panels where space allows. At 32×9 the frame collapses to visible rows while
the checked count, selected target and explicit review actions remain accessible.
Amount/date entry keeps the input tail visible without changing the typed value.

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

Home `i` or Commands > Plans and attention > Attention opens `Attention / Manage`
over the shared `Loam.AttentionReview` answer. Unavailable is not a configured-empty
stream; neither the body nor its frame caption claims `0 open` for absent evidence.
`due on`, `no due date`, and `due unknown` remain distinct, in source order, without
priority, taxonomy, amounts, selected-day membership, or a second lifecycle engine.

Quiet rounded frames align due meaning and context. At 100 columns and sufficient
height the list and Detail sit side by side; narrower terminals stack them when
space permits, or show focused Detail alone. Selection follows the visible list,
not a fixed first twelve rows. `j/k` or arrows retains cyclic one-row selection;
Ctrl-u/d or Page Up/Down pages by visible data rows and Home/End reaches the ends.
`i`, Enter, Tab or Shift-Tab toggles full wrapped Detail. Its selection background
is inactive when reviewing Detail; `j/k`, pages and Home/End scroll context, ID and
due meaning. `q`/Esc leaves Detail first, then returns to Home.

`n` starts Add; `r` and `x` review Resolve / Drop of the exact retained ID on the
known-through date, not Home's navigated day. Context/date fields keep their full
stored text while the selected input tail stays visible for long text and IME.
Bracketed paste follows the same single-line convention as Record. Due choices
stay visible above their scrollable context; confirmation keeps the operation/date
in the heading while its full target scrolls. Every mode reserves feedback above
two fixed operation rows; long causes wrap with an explicit over-height indicator.

Publication keys are unchanged: Context Enter only chooses due meaning; there `n`
explicitly publishes no due date, `u` publishes unknown timing, and `d` enters the
known-date field whose valid-date Enter publishes. Resolve/Drop publishes only on
confirmation Enter. Esc cancels editors/confirmations without an intent; `q` in a
text field is text. Review scrolling and endpoint keys never acquire write intent.

Durable publication still crosses `HouseholdCommand -> AttentionPublisher`, which
re-reads and re-admits under shared authority ownership, including stale-target
refusal. Only accepted writes reload the canonical **HouseholdImage Attention
section** and then all Home reviews. Read-only visits, cancellation and refusal do
not manufacture a reload/success. Live resize observes geometry without household
reads; Home re-observes tty bounds on return. Legacy `attention.loam` is not the
production source or write target. The shared previous-image recovery backup still
advances normally on accepted publication.

Qualification: `TuiAttentionAdministration` (also representative tests), Attention
persistence/Household adapter and Scheduled continuation neighbors, plus synthetic
`tests/test_attention_pty.py` / `tests/AttentionPtyFixture.lean` in both TUI CI tiers.
These cover full text/identity, all due meanings, cancellation/date refusal,
resolve/drop, stale re-admission, resize and unchanged non-Attention families/config.
UI-26 includes list/Detail and these Add/Resolve/Drop forms. It is the final screen
in this refinement round; pending work elsewhere remains separate.

## Balances

Commands > Reports and analysis > Balances / Current opens the read-only Balances workspace over `Loam.BalanceReview`.
Coordinates remain neutral `Locus × Measure` selections. Presentation does not
classify them as Account, Asset, Liability, cash, or any other accounting role.
Explicit zero-origin evidence and correction-aware review remain shared boundaries.

## Current-cycle Budget

Commands > Envelope budget > Budget opens the current-cycle Budget surface. The observation date is the
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
alternate Capacity entrance. General/raw Capacity remains available from Commands > Envelope budget > Capacity.
After Budget actions, the executable reloads the current Budget evidence before
rendering the workspace again.

## Capacity

Commands > Envelope budget > Capacity opens Capacity. The base snapshot is the shared all-retained
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

Commands > Envelope budget > Purpose routing opens Actual-to-Purpose routing administration. The surface edits explicit
routing evidence; it does not infer a Purpose from an AccountingRole, sign, account
name, or current balance. Expense Loci remain the default audit scope while admitted
non-Expense Loci can be entered explicitly when a generic Purpose question needs it.

## Locus administration

Commands > Household setup > Manage Loci opens add-only Locus administration. It shows the currently admitted
vocabulary before proposing one new stable Locus token. Admission does not also
create a label, AccountingRole, Purpose route, rename, or alias.

## Current quantity observation

Commands > Household setup > Observe quantities opens the current quantity observation editor. It collects one complete set
of `Locus × Measure × observed Quantity` rows observed together and publishes the
whole image through the shared boundary. The editor does not merge the image with an
older observation or derive reconciliation semantics locally.

## Reports

Home → `Space` → **Reports and analysis** → **specific report** opens that
report directly. There is no intermediate Reports chooser or extra subcategory.
For Stock–Flow and Income & Expense, `c` enters the existing two-window comparison.
At 14 terminal rows or fewer, the comparison editor shows the active coordinate
(or the Run action) first, following `Tab`/`Shift-Tab` with a bounded choice window.
A long custom date keeps its insertion tail visible rather than wrapping the
terminal row. At ordinary heights the original comparison layout remains intact.
This changes neither automatic source adjacency nor explicit comparison queries.

The single-period Start / End (exclusive) / Run form in Stock–Flow and
Income & Expense (Summary, Monthly and Daily) follows the same compact rule
at 14 rows or fewer. A small terminal places the current source and selected
input/Run first, keeping the entered date's tail visible. Larger terminals
retain the full original header. This affects neither the end-exclusive query
coordinates nor the report result. Multicurrency Spend now reuses the same
compact Start / End / Run presentation at short heights, while its read-only
ordinary/original/exchange evidence distinction and typed query remain unchanged.
Liquidity retains its independent screen contract. Transactions Flow now
reuses the same compact Start / End / Run header. Its report results still
prioritize the selected sparse coordinate when navigating the table; focusing
Start or End instead shows the editable dates. Compact contributor detail puts
the selected coordinate and exact quantities ahead of verbose explanation.
Esc or q returns to the selected summary row, not Home, and the single-period
query and sparse contribution evidence remain unchanged.
Accounting Balances remains a read-only immediate RoleBalance projection. At
14 rows or fewer, duplicate explanatory header rows collapse so the current
per-Measure answer appears first. Under 80 terminal columns, individual
accounting evidence lines wrap without discarding UNKNOWN, unsupported, or
unresolved details. Arrows/j/k scroll a physical row; PageUp/PageDown advance
one visible page, Home/End jump to its boundaries. Enter still refreshes the
shared answer, q/Esc returns Home, and p keeps the existing bounded full-text
Print contract. Neither totals nor answerability are inferred by wrapping.

Liquidity retains two separate propositions: an unconditional future forecast and
low-water mark remain UNKNOWN; a manually supplied Scheduled-completeness horizon
can only produce a read-only CONDITIONAL selected-balance outlook. At 14 rows
or fewer the screen shows both UNKNOWN answers, the selected assumption date,
and [Run conditional] before longer provenance details. Narrow report result
lines wrap instead of disappearing past the right edge, and the existing j/k
scroll and fixed footer reach the full conditional explanations. Long assumption
input keeps its insertion tail visible; changing it still invalidates stale
results, never upgrades a hypothesis to household evidence.

The ordered entries are:

1. Daily Pace
2. Balances / Current
3. Income & Expense
4. Transactions Flow
5. Stock–Flow
6. Trend / Locus comparison
7. Balances / Accounting
8. Liquidity
9. Budget Window
10. Multicurrency Spend
11. Fava Projection (external)

`↑/↓` or `j/k` selects; `Enter` opens; `Esc` returns one palette level (or closes
at the root). The palette uses one stable rectangle across pages, sized for the
largest command group plus context/help (currently **19 rows**, showing all eleven
analysis entries). Floating panels use the existing focused-frame border accent
to distinguish the active overlay from Home, while compact nonfloating palettes
keep the muted border. Floating panels leave two terminal rows above and below; at
23 rows or taller, all eleven items fit without scrolling. Added group items can
increase the preferred height automatically; the terminal remains the upper bound.
The bounded item viewport follows selection when the list cannot fit, including
after idle resize. Compact terminals retain the selected row and abbreviated help; extremely
short terminals prioritize the selected row over headings/borders/help.

At 14 terminal rows or fewer, Trend / Locus comparison gives its active Series
picker the short screen instead of leaving candidate rows below the chart. The
shared focus-following list window keeps the selected admitted Locus visible;
slot (1–5), Enter/apply, x/remove, and Esc/cancel remain available. Closing the
picker restores the same Trend chart and selected period. Ordinary terminal
heights retain the existing chart and picker layout, with no change to exact
Locus/Measure identities or series queries. The session-only Day overlay editor
also uses a focused form at 14 rows or fewer: the selected month, Name and Days
fields (including the active input tail), validation feedback, Tab/Enter, and
Esc stay on screen instead of following the full chart header. Applying and
cancelling continue to use the original unsaved overlay state; ordinary-height
chart and editor geometry are unchanged.

For ordinary Trend chart browsing at 9–14 rows (not within those editors),
the selected date, current grain/Measure, a compact selected-series summary, a
Braille plot and its axis, and short navigation help have reserved screen
space. At 9 rows one series and the count of additional series appear; at
10–14 rows the existing selected-series values are listed individually,
without clipping oversized amounts into misleading partial digits. A
presentation-only overlay uses a compact marker row and a separate session-only
guide/clear hint; the corresponding full legend remains available on larger
terminals. Compact pointer hit testing follows the actual compressed header
instead of the old full-size chart origin. No historical query, exact
Locus/Measure coordinate, overlay state or chart value is rewritten.

`q/Esc` exits a report's internal detail/comparison/series picker one level
at a time, then returns directly to Home from the report root. The existing Trend
overlay free-text form keeps `q` as text input and uses `Esc` to cancel back to
Trend (so overlay names are not restricted by navigation). Home's date, pane
and selection are retained. Daily Pace and Trend are distinct projections, as are
Current and role-aware Accounting Balances. Fava launches the existing disposable
external browser projection and returns its success/refusal notice to Home;
select it again to refresh/retry. No internal Fava chooser is opened.

Reports are explicit read queries rather than hidden household period authority.
Window-based reports retain their editable dates, calendar-month/named presets and
explicit Run. Accounting Balances and Trend still load immediately. Income &
Expense retains Summary/Monthly/Daily, Stock–Flow and Income & Expense retain
period comparison, Transactions Flow retains focused contributors, Trend retains
series/comparison controls, Balances retain evidence and bounded Print, Liquidity
retains assumption input, and Budget Window and Multicurrency Spend remain available.

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
floating panel. Its outer frame borrows the Commands overlay's existing focus accent,
without moving the active input caret or changing selected-field styling.
Compact terminals keep the existing full-screen Record surface and muted outer framing.
Only presentation changes; Record validation and publication are shared.

Record input uses aligned muted labels, with a focus accent on the active field
pane only. At wider widths, signed Postings and the admitted Locus candidate list
sit side by side; narrower terminals stack them. Low terminals show a bounded
Fields viewport that follows focus. Adding a posting never hides the active row.
The selected candidate follows its own window, without taking the input caret;
long labels/help show an ellipsis. Long active input shows its tail, including
CJK text, without changing the stored value. Actions, two operation rows, and a
reserved feedback row remain below the panes. `C-` denotes Ctrl in the compact
footer; row limits, exact candidate acceptance, and publication rules are unchanged.

#### Text caret and Japanese IME boundary (#1992)

Terminal output, not individual sessions, owns the caret lifecycle across all
production editors. `Layout.inputSpan` constructs semantic input fields with
dedicated insertion cells, preserving caret metadata through clipping, framing,
and side-by-side assembly. When a field is focused and active, `Terminal.lean`
emits `\x1b[?25h` at the painted insertion point; during repaints, menu browsing,
confirmation dialogues, and idle intervals, the caret is hidden with `\x1b[?25l`.
Zero-width, offscreen, and clipped regions suppress stale caret markers without
emitting unnecessary escape churn.

The static audit (`tools/audit-tui-text-inputs`) classifies 29 owners across the
codebase (including navigation, dispatch, transport, and line-mode owners alongside
active and conditional text inputs), rather than 29 editable text owners. Note that
this lexical audit cannot prove every view mode is correctly wired, and PTY test
harnesses cannot exercise uncommitted macOS IME preedit.

#### Production text-input inventory

| Owner | Class | Audited Renderers | Entrance / Purpose | Regression Test |
| :--- | :--- | :--- | :--- | :--- |
| `Record` | text | `Record` | Home `r`, Actual `r` | `tests/test_actual_detail_pty.py` |
| `ScheduledCompletion` | text | `ScheduledCompletion` | Scheduled `c`, Selected Day → Scheduled → `c` | `tests/test_scheduled_completion_modal_pty.py` |
| `ScheduledCreation` | text | `ScheduledCreation` | Scheduled `n` | `Loam/Tests/TuiScheduledCreate.lean` |
| `ScheduledReplacement` | text | `ScheduledReplacement` | Scheduled `e` | `tests/test_scheduled_replacement_pty.py` |
| `ScheduledBulkEdit` | text | `ScheduledBulkEdit` | Scheduled `b` | `tests/test_scheduled_bulk_edit_pty.py` |
| `ScheduledGeneration` | conditional | `ScheduledGeneration` | Scheduled `g` | `Loam/Tests/TuiScheduledGeneration.lean` |
| `AttentionAdministration` | text | `AttentionAdministration` | Home `i`, Commands `i` | `tests/test_attention_pty.py` |
| `Exchange` | text | `Exchange` | Commands `e` | `Loam/Tests/TuiExchange.lean` |
| `LocusAdmissionAdministration` | text | `LocusAdmissionAdministration` | Commands `l` | `Loam/Tests/TuiLocusAdmissionAdministration.lean` |
| `BoundedHistorySupportAdministration` | text | `BoundedHistorySupportAdministration` | Commands `b` | `Loam/Tests/TuiBoundedHistorySupportAdministration.lean` |
| `ActualRoutingAdministration` | conditional | `ActualRoutingAdministration` | Commands `r` | `Loam/Tests/TuiActualRoutingAdministration.lean` |
| `ActualDateCorrection` | conditional | `ActualDateCorrection` | Actual `d` | `Loam/Tests/TuiActualDateCorrection.lean` |
| `ActualReversal` | conditional | `ActualReversal` | Actual `u` | `Loam/Tests/TuiActualReversal.lean` |
| `EventMerchant` | conditional | `EventMerchant` | Actual `m` | `Loam/Tests/TuiEventMerchant.lean` |
| `CurrentQuantityAnchor` | text | `CurrentQuantityAnchor` | Commands `a` | `Loam/Tests/TuiHelpFooter.lean` |
| `CapacityTransfer` | text | `CapacityTransfer` | Capacity `t` | `Loam/Tests/TuiCapacityTransfer.lean` |
| `CapacityRebalance` | conditional | `CapacityRebalance` | Capacity `r` | `Loam/Tests/TuiCapacityRebalance.lean` |
| `DailyPaceWhatIf` | text | `DailyPaceWhatIf` | Daily pace `w` | `tests/test_daily_pace_pty.py` |
| `SettlementAction` | text | `SettlementAction` | Settlement `s` | `Loam/Tests/TuiSettlement.lean` |
| `ReportsModel` | text | `ReportsView` | Reports window, comparison, liquidity | `tests/test_reports_navigation_pty.py` |
| `LocusTrendComparePane` | text | `LocusTrendComparePane` | Reports trend compare | `Loam/Tests/TuiReports.lean` |
| `Home` | conditional | `Home` | Date jump buffer | `Loam/Tests/TuiHomeNavigation.lean` |
| `ActualWorkspace` | conditional | `ActualWorkspace` | Search query `/` | `Loam/Tests/TuiActual.lean` |
| `AccountingRoleAdministration` | navigation | - | Role selection | `Loam/Tests/TuiHomeNavigation.lean` |
| `Main` | dispatch | - | Top-level loop | `Loam/Tests/TuiHomeNavigation.lean` |
| `InputEdit` | dispatch | - | Shared single-line editor | `Loam/Tests/TuiTextFieldGeometry.lean` |
| `Cli` | transport | - | Terminal harness | `tests/test_terminal_mechanics_pty.py` |
| `Terminal` | transport | - | Low-level IO | `tests/test_terminal_mechanics_pty.py` |
| `PlainTextPrint` | line-mode | - | Direct prompt | `tests/test_terminal_mechanics_pty.py` |

**Real macOS Japanese IME acceptance remains unverified.** LOAM supplies a visible
insertion anchor, not an IME preedit renderer or candidate-window clipping policy.
A PTY injecting Japanese bytes cannot prove OS/terminal composition behavior, and
lexical auditing cannot verify that every view mode or dynamic transition wires caret
state properly.
Manual check, using only an isolated synthetic household:

```sh
lake build loamTui
fixture="$(mktemp -d)/household"
lake env lean --run Loam/Tests/ScheduledBatchReplacement.lean setup "$fixture"
./.lake/build/bin/loamTui "$fixture"
```

1. **Primary specimen (Scheduled Completion)**:
   - Navigate to Scheduled (`s`), select a due plan, and press `c` (Scheduled List → `c`), or navigate via Selected Day (`g` → select date → Enter → `s` → `c`).
   - Press `Tab` to focus the **Actual description** field.
   - Compose Japanese in Actual description **before pressing Enter**; inspect the preedit and candidate window anchor relative to the modal field.
   - Confirm composition, test `Backspace` and `Tab`/`Shift-Tab`, resize through 120×40, 80×24, 48×14, and 32×9, and check cursor stability.
   - Cancel with `Esc` without writing.
2. **Additional representative specimens**:
   - `Record`: from Home, press `r` at 120×40, compose Japanese in Description before Enter, test `Ctrl-O` Original amount return, resize, and cancel.
   - `Correction`: navigate to Actual (`a`), press Enter on a record, press `c` (Correction), compose Japanese, resize, and cancel.
3. Repeat directly and under tmux when applicable; report terminal/version (Terminal.app, iTerm2, Ghostty, Alacritty, etc.), tmux/version, field, size, and preedit-versus-confirmed behavior.

Separate Unicode limitation, not an IME fix: width and Backspace remain
scalar-based. The #1992 specimens measured decomposed `か` + U+3099 as four
columns, `e` + U+0301 as one, ZWJ `👩‍💻` and skin-tone `👍🏽` as four, and flag
`🇯🇵` as two. Clip/wrap can split these sequences; Backspace removes one scalar,
not one grapheme. CJK/ASCII replacement remains column-bounded under this
approximation. No normalization, segmentation dependency, Cell rewrite or
synchronized-output mode was introduced; atomic/synchronized painting is deferred
without a demonstrated connection to this failure.


Record's Ctrl-O Original amount editor uses the same aligned muted labels,
active-field tail display and caret geometry, with a quiet input frame and a
separate meaning panel. Feedback has a reserved row and wraps completely;
two fixed operation rows show focus/attach and clear/return/cancel. The editor
states that this is the merchant/card amount, not another posting or an inferred
FX rate. Enter attaches only to the local draft; durable publication still needs
Record Preview confirmation. Ctrl-O returns without attaching local edits, Ctrl-D
clears the attached original, and Esc cancels Record. Terminal input disables
extended tty editing so macOS does not consume Ctrl-O before the TUI receives it.

Record's first-use Ctrl-U confirmation separates a focused **Household vocabulary**
frame (admit the ordinary `suspense` Locus) from a quiet explanation that this does
not record a Movement, change its Measure, or guess a category. The Enable action,
reserved wrapping feedback, and two operation rows stay below the bounded body.
Enter confirms household policy admission; e/E or Backspace returns to the draft,
and Esc cancels Record. Opening, returning, and cancelling before confirmation do
not publish. After confirmed admission, the existing canonical reload and draft
remainder assistance still run; any Actual publication requires Record Preview.

Record confirmation uses a quiet rounded frame with signed Effects, their exact
Measure quantities and Locus tokens, plus date, description, and any attached
original amount. Long values wrap without dropping digits or identities.
`↑/↓`, Page Up/Down, and Home/End review overflowing content; publication actions
and the operation bar remain below the viewport. Idle resize recomputes the frame
without reloading or writing household evidence. Tab selects Publish/Edit/Cancel;
Enter confirms the selected action. Opening Preview still never publishes.
Embedded correction/completion surfaces retain their existing presentation contract.
