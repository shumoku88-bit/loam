# LOAM GUI — household workbench

Status: **read-only Tauri 2 workbench**. No GUI write action exists yet.

The first slice takes the dense, keyboard-oriented ledger idea from Let's家計簿
and the restrained workbench organization of Actual Budget. It uses original
HTML/CSS/components, not assets or code extracted from either product.

## Shape and authority

```text
actual.loam
   |
fully admitted ActualAuthority image / shared ActualReview
   |
loam explain actual --machine --month YYYY-MM
   |
thin asynchronous Tauri command (ACTUAL1 schema 2)
   |
calendar + monthly ledger | simultaneous evidence / correction comparison
```

The GUI never reads `actual.loam` itself. Rust starts the ordinary `loam` binary
and validates presentation framing, exact quantity text and lineage ownership.
Accounting arithmetic, correction admission and household authority stay in LOAM.
JavaScript handles selection, filtering, layout and exact-field comparison only.

## Current interaction

- Keep the monthly ledger visible while reading the selected record's Effects.
- Calendar Left/Right moves focus by a day; Up/Down by a week, including month
  boundaries and leap days. Enter/Space confirms a date; moving focus does not
  confirm it. Crossing months reads the new month without auto-selecting a day.
- The calendar and ledger each have one roving Tab entry, rather than a Tab stop
  on every day/row. Tab/Shift+Tab follows the controls between regions.
- Select a calendar date, jump to its visible record, or switch to day-only scope.
- Literal search across current monthly descriptions, IDs, dates and Effects;
  whitespace-separated terms are ANDed, with presentation-only NFKC/case folding.
- Filter by a Locus involved in the movement, and switch date ordering.
- Move between rows with Up/Down/Home/End; Enter moves focus to the inspector.
- Open search with `/` or Cmd/Ctrl+F; change months with Alt+Left/Right outside
  text editors; Cmd/Ctrl+K opens a searchable command palette.
- Inspector tab arrows/Home/End move focus; Enter/Space activates the focused tab.
  Esc returns from the inspector or docked calendar to the ledger. In an empty
  ledger it focuses the empty-state region rather than losing the keyboard cursor.
- Esc closes the command palette or calendar/data popup and restores its opener.
  Return anchors survive read-driven DOM replacement. Text editors, native select
  popups, modified arrows and IME composition keep their own editing keys.
- Focus rings and region borders distinguish keyboard focus from selected evidence.
  A pending read respects an explicitly confirmed day and never steals focus from
  another region when it completes.
- Inspect retained Event-correction ancestors, choose an adjacent correction
  pair, and compare dates, descriptions and the complete Effect composition.
- Resize the ledger/inspector separator by pointer or Left/Right/Home/End.
- Fold the calendar, select compact/comfortable row spacing, and use the system
  light/dark theme. Narrow windows stack the ledger and inspector.
- Remember only disposable preferences: data path, scope, sorting, density,
  calendar visibility and inspector width. Record contents are never cached in
  local storage.

Filtering never leaves a hidden row masquerading as the selected record. Changing
months/data sources immediately removes the previous read answer; only the newest
request may publish a response or error. Loading/refusal is visible, not a zero
household answer.

## Correction comparison boundary

ACTUAL1 schema 2 is replaceable presentation plumbing, not another household
schema or external compatibility contract. Current rows remain month-scoped.
Only ancestors linked by admitted **EventCorrection** edges are included, even
when their dates are unknown or outside the displayed month. Oldest-to-newest
order follows the edges, not dates or file order.

Transport rows are tab-separated:

```text
ACTUAL1 meta schema 2
ACTUAL1 meta implementation loam
ACTUAL1 meta question actual-month
ACTUAL1 meta month YYYY-MM
ACTUAL1 record CURRENT_ID DATE ESCAPED_TEXT
ACTUAL1 effect CURRENT_ID LOCUS MEASURE EXACT_QUANTA
ACTUAL1 history CURRENT_ID ANCESTOR_ID REPLACEMENT_ID DATE_OR_EMPTY ESCAPED_TEXT
ACTUAL1 history-effect CURRENT_ID ANCESTOR_ID LOCUS MEASURE EXACT_QUANTA
...
ACTUAL1 meta status complete
```

Descriptions use LOAM's lossless single-line escaping (`\\`, `\n`, `\r`, `\t`);
remaining control characters are made visibly distinguishable in the webview, not
collapsed to a replacement character before comparison.

Historical records are contained in their current owner's block and terminate at
that current record. The Rust adapter rejects duplicate identities, malformed or
misowned Effects, open/misordered history, wrong-month current rows, nonexact
quantity text and incomplete streams. It does not redo semantic admission.

Dates are each Event's **current admitted occurrence date**, not the time the
correction was recorded. ActualValidity/date-only revision history is **not**
shown. No missing date, correction timestamp or classification is inferred.

Effect comparison uses exact `(Locus, Measure, quanta)` tuples, ignoring list
order but preserving multiplicity. It does not guess cross-Event Effect identity,
compute a balance/delta, or collapse multi-Measure/split records into their first
positive amount. Quantity text remains exact even beyond JavaScript's safe
integer range. A simple two-Effect, equal/opposite, same-Measure record can have a
single quantity summary; all other records point to their full evidence.

## Run on macOS

Install Rust/Tauri prerequisites once, then from the repository:

```sh
cargo install tauri-cli --version "^2.0.0" --locked   # first time only
./gui/dev
```

`gui/dev` builds the ordinary LOAM binary first and starts Tauri. Rebuild both
sides after transport changes; the adapter deliberately does not retain the
superseded schema 1 parser.

The same default household root as LOAM is used. Another root is available under
`データ` and remembered locally. Development overrides:

```text
LOAM_GUI_REPO_ROOT=/path/to/loam
LOAM_GUI_LOAM_BIN=/path/to/loam
```

## Qualification

From the repository root:

```sh
lake build loam Loam.Tests.ActualObservationCli
lake env lean --run Loam/Tests/ActualObservationCli.lean
cargo test --locked --manifest-path gui/src-tauri/Cargo.toml
cargo clippy --locked --manifest-path gui/src-tauri/Cargo.toml --all-targets -- -D warnings
```

Frontend logic tests need Node.js only. Playwright is a **test-only dependency**;
there is no frontend framework, runtime npm dependency or bundler:

```sh
cd gui
npm test
npm ci
npx playwright install chromium
npm run test:browser
```

Browser tests serve only the four web assets from a temporary local HTTP server
and inject an in-memory mock of the bounded Tauri read command. All evidence is
synthetic; no real household data or paths are opened. They qualify selection,
keyboard/filter behavior, day/week movement and month-boundary confirmation,
Tab/Shift+Tab order, popup return anchors across reloads, IME/editor priority,
unknown-date correction comparisons, exact quantities, stale-success/stale-error
races, visible refusal, responsive/dark layout,
pointer/keyboard separator operation and markup-safe rendering. Screenshots go
to a temporary directory (override with `LOAM_GUI_SCREENSHOT_DIR`).

Browser specimens qualify web interaction, not native WKWebView rendering or the
entire authority-to-webview pipeline. Lean and Rust tests qualify their respective
read/transport boundaries separately.

## Next slice, deliberately not implemented here

A safe editable ledger can reuse the same inspector for a **proposed correction
versus retained evidence** preview, then submit through LOAM's existing admitted
publication path. The comparison above is retained history, not an editable
proposal. Bulk edits, CSV import, graph-to-ledger linking, saved search filters
and report navigation are later slices; there are no dead navigation buttons
pretending those capabilities exist.
