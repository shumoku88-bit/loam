# LOAM TUI

`loamTui` is the production terminal frontend for LOAM.

The TUI is presentation and interaction state, not a second household authority.
It consumes the same admitted read and write boundaries used by other LOAM
frontends.

Current production direction:

```text
Loam/Tui/Kernel     small Widget / Screen meaning and reconstruction laws
Loam/Tui/Runtime    compiled sparse-row redraw representation
Loam/Tui/Terminal   raw terminal mechanics only
Loam/Tui/Calendar   presentation-only Gregorian month projection
Loam/Tui/Main       Home / Actual / Scheduled interaction state
Loam/Tui/Record     local Record editor / preview state
Loam/Tui/Attention  local read-only Attention workspace
Loam/Tui/Balances   local read-only replaceable balance-view workspace
Loam/Tui/Capacity   local read-only Capacity workspace
Loam/Tui/Reports    local explicit-query Reports workspace
Loam/Tui/Cli        canonical loading and executable loop
```

One selected day drives Home evidence, Actual review, Scheduled review, and the
Record date seed. Actual and Scheduled remain separate semantic families.
Missing explicit Scheduled evidence remains `Unknown`; the UI must not strengthen
it into `NotDue` without completeness evidence.

Attention is currently a global current-open workspace rather than selected-day
evidence. The TUI does not infer day membership from a due date, sort open items
by due date, or add a priority taxonomy. Those would require separately earned
query/policy semantics.

Balances is a replaceable current-question projection over explicitly selected
neutral `Locus × Measure` coordinates. It does **not** classify those loci as
Accounts, Assets, Liabilities, cash, or any other accounting role.

Capacity is currently an all-retained JPY Entitlement projection. `Current` in
that workspace means the current answer over all retained Capacity movements; it
does **not** mean current cycle, current month, selected day, or any inferred
budget period. Windowed Capacity remains an explicit Application query with
caller-supplied `[start, end)` coordinates.

Reports begins with one Budget Window report. The visible coordinates are explicit,
but the editor is initially seeded with the Gregorian calendar month containing
Home's selected day as a presentation convenience. This does not claim that the
month is a household cycle, budget period, cadence, or canonical current window.

## Production rule

Historical `Loam/Prototype/*` code and numbered prototype executables are research
provenance. Production TUI code must not import them. Useful mechanics are promoted
into `Loam/Tui/*` only when they have earned a stable production role.

The production executable is:

```sh
lake build loamTui
./.lake/build/bin/loamTui
```

`LOAM_DATA_DIR` may select the household data directory; otherwise the executable
uses `../loam-data`. Movement reads use selected manifest authority and fail closed.

## Attention review

Home `a` opens the read-only Attention workspace. It consumes
`Loam.AttentionReview`, which in turn delegates current-open lifecycle selection
to the shared Application `openAttentions?` projection. The TUI does not repeat
closure interpretation.

The configured stream is `attention.loam` under `LOAM_DATA_DIR`. A missing stream
is rendered as `Attention / Unavailable`; this is deliberately not the same claim
as an explicitly configured stream with `0 open` items. Malformed evidence or a
closure that references an unknown Attention identity fails closed at the shared
review boundary.

The three qualified due meanings remain distinct on screen:

```text
due YYYY-MM-DD
no due date
due unknown
```

Rows remain in representation order. That order is not priority, chronology, or
due ordering. This first workspace has no add, resolve, drop, or relation writer;
`b`/Escape returns Home and `q` quits LOAM.

Qualification is split deliberately: `Loam/Tests/AttentionPersistence.lean`
checks persistence round-trip, source unavailable versus explicit empty, escaped
human context, due distinctions, and dangling-closure refusal.
`Loam/Tests/TuiAttention.lean` checks that the surface preserves those distinctions
and remains read-only.

## Balances review

Home `b` opens the read-only Balances workspace. It consumes
`Loam.BalanceReview`, a surface-independent household reader over the already-
qualified current-quantity and basis-cut projections.

The production read topology is deliberately mixed rather than collapsed into a
new umbrella authority:

```text
selected Movement manifest -> Event effects
corrections.loam            -> EventCorrection, absent means empty
basis.loam                  -> QuantityBasis, absent means no basis facts
basis-corrections.loam      -> QuantityBasisCorrection, absent means empty
basis-cut.tsv               -> already-reflected occurrence relation, absent means empty
balance-view.tsv            -> replaceable selected Locus × Measure coordinates, absent means empty selection
```

Movement never falls back to the retired `memory.loam` sidecar. The other files
retain their existing independent evidence/configuration meanings; this read does
not claim an atomic snapshot across them.

`balance-view.tsv` is a question-selection seam, not an Account registry. It can
choose which neutral coordinates should appear without changing quantity evidence.
Row order is presentation order only, duplicate coordinates are normalized, and
no Asset/Liability/Income/Expense role, ranking, valuation, or total is inferred.

For each selected coordinate the shared review delegates to the existing
`BasisCut.inspectCurrentQuantityWithBasisCut?` path, which composes the admitted
starting-basis frontier with correction-aware Event activity. A missing starting
basis is **not** interpreted as zero. Invalid basis corrections, invalid basis-cut
roots, or an inadmissible Event correction frontier refuse the whole view rather
than publishing a partial set of plausible balances. An explicitly derived zero
remains visible.

`Loam/Tests/BalanceReview.lean` publishes a selected Movement manifest, poisons a
legacy `memory.loam`, and requires `wallet = 70` from a `100` starting basis plus a
`-30` selected-manifest Event. It also preserves an explicit `cash = 0`, normalizes
a duplicate view coordinate, refuses a selected coordinate without basis evidence,
and refuses malformed basis-correction evidence.
`Loam/Tests/TuiBalances.lean` checks neutral-coordinate wording, nonzero and zero
rows, balance-view presentation order, explicit-empty selection, and read-only
Home navigation.

## Capacity review

Home `c` opens the read-only Capacity workspace. It consumes
`Loam.CapacityReview`, whose quantities delegate to the existing Application
`entitlementAt` projection. The TUI does not maintain balances or derive Capacity
by replaying a second local accounting model.

The configured stream is `capacity.loam` under `LOAM_DATA_DIR`. Capacity keeps its
existing practical bootstrap policy: an absent stream means no retained Capacity
movements yet, so the all-retained review is empty. A configured malformed stream
still refuses. This differs intentionally from Attention, whose absent source is
`Unavailable`.

Rows show remembered Purpose coordinates and their all-retained JPY Entitlement.
Purpose order is first retained representation appearance only; it is not priority
or a budget ranking. Zero or negative derived values are not hidden by the TUI.

This workspace deliberately does not use `CapacityEffective` to manufacture a
cycle. `CapacityWindowInspection` already supports explicit half-open windows, but
choosing which window represents a household cycle requires separately earned
query policy. The first production Capacity workspace therefore claims only the
untimed current all-retained answer already available from the line Capacity
surface.

`Loam/Tests/CapacityReview.lean` checks missing/explicit-empty behavior, projection
agreement for reallocation, and malformed-stream refusal.
`Loam/Tests/TuiCapacity.lean` checks the all-retained presentation, explicit
no-window statement, ordering non-claim, and read-only navigation.

## Reports / Budget Window

Home `p` opens `Reports / Budget Window`. The initial coordinates are the explicit
Gregorian calendar month containing Home's selected day. For example, selected
`2026-09-07` seeds:

```text
[2026-09-01, 2026-10-01)
```

Run is initially focused, so Enter can query that visible month immediately.
Left and Right shift an exact calendar-month window by one month. `m` restores the
calendar month containing the original Home selected day. Start and End remain
ordinary editable fields, so an operator can replace the convenience month with
any explicit valid half-open window.

Arrow movement refuses to rewrite a manually edited non-calendar window; `m`
provides the explicit way back to the selected-day calendar month. Editing or
changing the coordinates clears any previously displayed result so a stale
Remaining value is never shown beside a new unrun window.

This calendar constructor is presentation policy only. It says nothing about the
household's current cycle, budget period, cadence, first Capacity date, or other
canonical temporal regime. The coordinates stay visible and are the exact values
sent to the shared Review boundary.

`Loam.BudgetWindowReview` is the surface-independent production read boundary.
It follows the current authority topology rather than the frozen pre-cutover
Movement sidecars:

```text
selected Movement manifest -> Event + ActualValidity
capacity.loam              -> Capacity
capacity.loam.effective    -> CapacityEffective
actual-routing.loam        -> ActualRouting
corrections.loam           -> EventCorrection when present; absent means empty
```

A malformed or missing required authority refuses. There is no fallback to
`memory.loam` or its frozen ActualValidity sidecar. This matters because Movement
cutover deliberately left those files as rollback/history material rather than
steady-state authority.

For every Purpose represented by retained Capacity evidence, the shared Review
calls the existing `CapacityWindowInspection` component projections over the
operator-visible `[start, end)` window. It displays:

```text
Entitlement
Consumption
Remaining = Entitlement - Consumption
```

Remaining is useful presentation but not retained state. Observation 181 already
qualified it as derived from the two resolved component answers. Observation 196
qualified the separate household window-selection boundary: the same selected Home
day can belong to two valid windows that produce different answers, while differently
named Cycle identities with equal coordinates do not change coordinate-derived
answers. Therefore the calendar-month convenience is not promoted into a household
`current window` claim, and automatic Home Remaining still waits for separately
earned shared window-selection policy.

`Loam/Tests/BudgetWindowReview.lean` builds a selected Movement manifest, writes
independent Capacity/effective/routing evidence, poisons a legacy `memory.loam`,
and requires the manifest-backed `100 entitlement / 30 consumption / 70 remaining`
answer. It also checks reversed-window and missing-manifest refusal.
`Loam/Tests/TuiReports.lean` checks selected-day calendar-month seeding, previous
and next month navigation including year rollover, manual-window preservation,
`m` reset, stale-result clearing, exact query-intent preservation, derived Remaining
presentation, explicit no-cycle wording, and Home navigation.

## Write boundary

Record editing is not considered complete until an already-collected typed
`MovementAdmission.Draft` can be published through the same writer-ownership,
current-world re-read, admission, and manifest publication path used by the line
Movement entrance. The TUI must not duplicate that publisher or create its own
canonical write path.

## Record publication

Home `r` opens the production Record editor on the selected day. Tab and
Shift-Tab move through date, description, FROM/TO locus and integer JPY amount
fields, and Add FROM / Add TO / Drop last row / Preview / Cancel actions.
Right accepts a prefix candidate into the active locus field. Backspace edits;
Escape cancels. The current 80×24 editor supports six effect rows; dropping the
last row retains at least one row on each side. Preview shows every effect and
allows Publish, Edit, or Cancel. No transaction kind is retained.

`Loam.MovementPublisher` is the surface-independent production publication
entrance for collected `MovementAdmission.Draft` values. Both line CLI and TUI
use it for selected-manifest publication. It acquires the existing
WriterOwnership lock, rereads the current selected manifest world, runs
production `MovementAdmission.admit?`, then publishes that world. It does not
read human input or print terminal output. The isolated sidecar regression
fixture remains local to the line Movement CLI and is not a second production
publisher.

Draft balance, positive totals, JPY measure, valid effect tokens and occurrence
date are validated at the shared admission entrance. These are practical
Movement conditions, not new restrictions on neutral Core Events. Locus
suggestions remain read evidence; the current production vocabulary decides
publication, including when it changes after preview.

Successful publication discards the editor and cached Actual cursor, reloads
canonical review evidence and returns Home on the same selected date. A failure
after a successful publication, including reload failure, exits rather than
presenting the same Publish intent again. Exceptions also unwind the terminal
boundary. A normal admission refusal retains the editable form.

Qualification: `Loam/Tests/TuiRecord.lean` exercises invalid drafts, cancellation,
candidate isolation, Edit preservation, stale Locus policy refusal without
CURRENT mutation, canonical publication and fresh shared Actual review. The
retained Screen and sparse-row reconstruction laws apply to Record widgets too.
Terminal glyph width, ANSI, OS locking and IO remain outside those Lean proofs.
Real household migration to an explicit Locus vocabulary is a separate step;
these regression fixtures do not authorize or mutate household data.