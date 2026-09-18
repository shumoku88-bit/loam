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
    "·"
  else
    "+"

private def monthHeader (month : String) : String :=
  Loam.Tui.Layout.padRight 8 month

private def coverageCell (cell : Loam.ScheduledCoverageReview.MonthCell) : String :=
  Loam.Tui.Layout.padRight 8 (cellGlyph cell)

private def coveredThrough? (row : Loam.ScheduledCoverageReview.Row) : Option String :=
  let beforeGap :=
    match row.firstMissing with
    | none => row.cells
    | some gap => row.cells.takeWhile fun cell => !(cell.month == gap)
  (beforeGap.reverse.find? fun cell =>
    cell.expected && !(cell.explicitCount == 0)).map (·.month)

private def rowLine (row : Loam.ScheduledCoverageReview.Row) : Widget :=
  let through :=
    match coveredThrough? row with
    | some month => "  through " ++ month
    | none => "  through —"
  let gap :=
    match row.firstMissing with
    | some month => "  next gap " ++ month
    | none => "  no gap in view"
  line <|
    Loam.Tui.Layout.padRight 18 row.rule.name ++
    Loam.Tui.Layout.padRight 10 (cadenceLabel row.rule.everyMonths) ++
    String.intercalate "" (row.cells.map coverageCell) ++ through ++ gap

def lines (snapshot : Loam.ScheduledCoverageReview.Snapshot) : List Widget :=
  if snapshot.rows.isEmpty then
    [ muted "No Scheduled coverage rules configured."
    , muted "Add config/scheduled-coverage.tsv to monitor monthly or multi-month expectations."
    , muted "Absence of a rule never implies that an obligation is not due."
    ]
  else
    [ muted ("Future explicit-plan coverage after " ++ snapshot.observedAt)
    , line <|
        Loam.Tui.Layout.padRight 18 "Rule" ++
        Loam.Tui.Layout.padRight 10 "Cadence" ++
        String.intercalate "" (snapshot.months.map monthHeader)
    ] ++
    snapshot.rows.map rowLine ++
    [ muted "● explicit expected slot   ! expected but not explicit   · not expected   + explicit off-pattern"
    , muted "Coverage rules are read-side monitoring expectations only; they do not create recurrence authority."
    ]

end Loam.Tui.ScheduledCoveragePane
