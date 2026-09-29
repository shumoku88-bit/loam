import Loam.ScheduledCoverageReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.ScheduledCoveragePane

open Loam.Tui.Kernel

set_option autoImplicit false

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def cadenceLabel (months : Nat) : String :=
  if months = 1 then "monthly"
  else "every " ++ toString months ++ "m"

private def cellGlyph (cell : Loam.ScheduledCoverageReview.MonthCell) : String :=
  if cell.expected then
    if cell.explicitCount = 0 then "!"
    else if cell.explicitCount = 1 then "●"
    else toString cell.explicitCount
  else if cell.explicitCount = 0 then
    ""
  else
    "+"

private def shortMonth (month : String) : String :=
  match month.splitOn "-" with
  | [_, mm] => mm
  | _ => month

private def monthHeader (month : String) : String :=
  Loam.Tui.Layout.padRight 4 (shortMonth month)

private def coverageCell (cell : Loam.ScheduledCoverageReview.MonthCell) : String :=
  Loam.Tui.Layout.padRight 4 (cellGlyph cell)

private def coveredThrough? (row : Loam.ScheduledCoverageReview.Row) : Option String :=
  let beforeGap :=
    match row.firstMissing with
    | none => row.cells
    | some gap => row.cells.takeWhile fun cell => !(cell.month == gap)
  (beforeGap.reverse.find? fun cell =>
    cell.expected && !(cell.explicitCount == 0)).map (·.month)

private def missingSortKey (row : Loam.ScheduledCoverageReview.Row) : String :=
  match row.firstMissing with
  | some month => month
  | none => "9999-99"

private def rowBefore
    (left right : Loam.ScheduledCoverageReview.Row) : Bool :=
  let leftMissing := missingSortKey left
  let rightMissing := missingSortKey right
  if leftMissing = rightMissing then
    left.rule.name <= right.rule.name
  else
    leftMissing <= rightMissing

private def tableHeader (months : List String) : Widget :=
  line <|
    Loam.Tui.Layout.padRight 18 "Plan" ++
    Loam.Tui.Layout.padRight 11 "Pattern" ++
    String.intercalate "" (months.map monthHeader) ++
    Loam.Tui.Layout.padRight 10 "Through" ++
    "Next gap"

private def tableRow (row : Loam.ScheduledCoverageReview.Row) : Widget :=
  let through :=
    match coveredThrough? row with
    | some month => month
    | none => "—"
  let gap :=
    match row.firstMissing with
    | some month => month
    | none => "—"
  line <|
    Loam.Tui.Layout.padRight 18 row.rule.name ++
    Loam.Tui.Layout.padRight 11 (cadenceLabel row.rule.everyMonths) ++
    String.intercalate "" (row.cells.map coverageCell) ++
    Loam.Tui.Layout.padRight 10 through ++
    gap

/--
Compact future-plan coverage for the Scheduled workspace.

Blank cells are intentionally silent: the monitoring pattern does not expect a
plan in that month. Only explicit evidence, a configured missing month, or an
off-pattern occurrence gets a glyph.
-/
def lines (snapshot : Loam.ScheduledCoverageReview.Snapshot) : List Widget :=
  if snapshot.rows.isEmpty then
    [ muted "No plan monitoring rules configured yet."
    , muted "Select an explicit plan in Months/List and press m to monitor it."
    , muted "No rule never means that an obligation is not due."
    ]
  else
    let rows := snapshot.rows.mergeSort rowBefore
    [ muted ("Future plan coverage after " ++ snapshot.observedAt)
    , muted <|
        match snapshot.months.head?, snapshot.months.getLast? with
        | some first, some last => "Window: " ++ first ++ " .. " ++ last
        | _, _ => "Window: (empty)"
    , line ""
    , tableHeader snapshot.months
    ] ++
    rows.map tableRow ++
    [ line ""
    , muted "● filled   ! expected but missing   + explicit off-pattern   blank = not expected"
    , muted "Through = last expected filled month before the first gap."
    , muted "Patterns monitor coverage only; they do not create recurrence authority."
    ]

end Loam.Tui.ScheduledCoveragePane
