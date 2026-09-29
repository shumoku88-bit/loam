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
  else if months = 12 then "yearly"
  else "every " ++ toString months ++ "m"

private def coveredThrough? (row : Loam.ScheduledCoverageReview.Row) : Option String :=
  let beforeGap :=
    match row.firstMissing with
    | none => row.cells
    | some gap => row.cells.takeWhile fun cell => !(cell.month == gap)
  (beforeGap.reverse.find? fun cell =>
    cell.expected && !(cell.explicitCount == 0)).map (·.month)

private def rowBefore
    (left right : Loam.ScheduledCoverageReview.Row) : Bool :=
  if left.rule.everyMonths = right.rule.everyMonths then
    left.rule.name <= right.rule.name
  else
    left.rule.everyMonths < right.rule.everyMonths

def orderedRows
    (snapshot : Loam.ScheduledCoverageReview.Snapshot) :
    List Loam.ScheduledCoverageReview.Row :=
  snapshot.rows.mergeSort rowBefore

private def tableHeader : Widget :=
  line <|
    Loam.Tui.Layout.padRight 28 "Plan" ++
    Loam.Tui.Layout.padRight 12 "Pattern" ++
    Loam.Tui.Layout.padRight 15 "Filled through" ++
    "Next needed"

private def tableRow
    (selected : Bool) (row : Loam.ScheduledCoverageReview.Row) : Widget :=
  let through :=
    match coveredThrough? row with
    | some month => month
    | none => "—"
  let nextNeeded :=
    match row.firstMissing with
    | some month => month ++ "  !"
    | none => "none in view"
  let prefix := if selected then "> " else "  "
  let text :=
    prefix ++
    Loam.Tui.Layout.padRight 26 row.rule.name ++
    Loam.Tui.Layout.padRight 12 (cadenceLabel row.rule.everyMonths) ++
    Loam.Tui.Layout.padRight 15 through ++
    nextNeeded
  .row [span text (if selected then .selected else .normal)]

/--
Quiet Scheduled overview.

The primary answer is how far each monitored plan is filled and which expected
month needs attention next. Exact month-by-month evidence remains available in
the Months projection instead of turning the overview into a symbol matrix.
-/
def linesSelected
    (snapshot : Loam.ScheduledCoverageReview.Snapshot)
    (selectedRow : Nat) : List Widget :=
  if snapshot.rows.isEmpty then
    [ muted "No recurring plans are being monitored."
    , muted "Create a plan, or use Months/List to establish a recurring pattern."
    , muted "No monitoring rule never means that an obligation is not due."
    ]
  else
    let rows := orderedRows snapshot
    let selected := min selectedRow (rows.length - 1)
    [ muted ("Known through " ++ snapshot.observedAt)
    , muted <|
        match snapshot.months.head?, snapshot.months.getLast? with
        | some first, some last => "Looking ahead: " ++ first ++ " .. " ++ last
        | _, _ => "Looking ahead: (empty)"
    , line ""
    , tableHeader
    ] ++
    (rows.zipIdx.map fun (row, index) => tableRow (index = selected) row) ++
    [ line ""
    , muted "! = the next expected month has no explicit Scheduled plan yet."
    , muted "Select a row here to extend it or change its pace; use Exact dates only when needed."
    , muted "Monitoring guides extension; it does not create recurrence authority."
    ]

def lines (snapshot : Loam.ScheduledCoverageReview.Snapshot) : List Widget :=
  linesSelected snapshot 0

end Loam.Tui.ScheduledCoveragePane
