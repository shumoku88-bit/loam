import Loam.Review.ScheduledCoverageReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.ScheduledCoveragePane

open Loam.Tui.Kernel

set_option autoImplicit false

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def cadenceLabel (months : Nat) : String :=
  if months = 0 then "undecided"
  else if months = 1 then "monthly"
  else if months = 12 then "yearly"
  else "every " ++ toString months ++ "m"

private def rowBefore
    (left right : Loam.ScheduledCoverageReview.Row) : Bool :=
  if left.rule.everyMonths = 0 then
    if right.rule.everyMonths = 0 then left.rule.name <= right.rule.name else false
  else if right.rule.everyMonths = 0 then
    true
  else if left.rule.everyMonths = right.rule.everyMonths then
    left.rule.name <= right.rule.name
  else
    left.rule.everyMonths < right.rule.everyMonths

def orderedRows
    (snapshot : Loam.ScheduledCoverageReview.Snapshot) :
    List Loam.ScheduledCoverageReview.Row :=
  snapshot.rows.mergeSort rowBefore

private def monthLabel (month : String) : String :=
  match month.splitOn "-" with
  | [_, monthNumber] =>
      match monthNumber with
      | "01" => "Jan"
      | "02" => "Feb"
      | "03" => "Mar"
      | "04" => "Apr"
      | "05" => "May"
      | "06" => "Jun"
      | "07" => "Jul"
      | "08" => "Aug"
      | "09" => "Sep"
      | "10" => "Oct"
      | "11" => "Nov"
      | "12" => "Dec"
      | _ => monthNumber
  | _ => month

private def monthCellText (cell : Loam.ScheduledCoverageReview.MonthCell) : String :=
  if !cell.explicitDays.isEmpty then
    if cell.explicitDays.length <= 3 then
      String.intercalate "," cell.explicitDays
    else
      toString cell.explicitDays.length ++ " plans"
  else if cell.expected then
    "!"
  else
    ""

private def monthColumnWidth : Nat := 8

private def paceWidth (width : Nat) : Nat :=
  if width >= 31 then 11 else 0

private def planWidth (width : Nat) : Nat :=
  min 28 (max 2 (width - paceWidth width - monthColumnWidth))

/-- Number of complete month columns that fit; Plan narrows before a month is cut. -/
def monthWindowSize (width : Nat) : Nat :=
  (width - planWidth width - paceWidth width) / monthColumnWidth

private def fitName (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text <= width then Loam.Tui.Layout.padRight width text
  else Loam.Tui.Layout.padRight width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

private def tableHeader (width : Nat) (months : List String) : Widget :=
  muted <|
    Loam.Tui.Layout.padRight (planWidth width) "Plan" ++
    Loam.Tui.Layout.padRight (paceWidth width) "Pace" ++
    String.intercalate "" (months.map fun month =>
      Loam.Tui.Layout.padRight monthColumnWidth (monthLabel month))

private def tableRow
    (width : Nat) (selected : Bool) (monthOffset monthCount : Nat)
    (row : Loam.ScheduledCoverageReview.Row) : Widget :=
  let marker := if selected then "> " else "  "
  let cells := (row.cells.drop monthOffset).take monthCount
  let text :=
    marker ++
    fitName (planWidth width - 2) row.rule.name ++
    Loam.Tui.Layout.padRight (paceWidth width) (cadenceLabel row.rule.everyMonths) ++
    String.intercalate "" (cells.map fun cell =>
      Loam.Tui.Layout.padRight monthColumnWidth (monthCellText cell))
  .row [span (Loam.Tui.Layout.padRight width text) (if selected then .selected else .normal)]

/-- Bounded table projection; row indices remain those of `orderedRows`. -/
def tableWindow
    (snapshot : Loam.ScheduledCoverageReview.Snapshot)
    (selectedRow monthOffset monthCount width height : Nat) : List Widget :=
  if snapshot.rows.isEmpty then
    [muted "No recurring plans are being monitored."]
  else
    let rows := orderedRows snapshot
    let selected := min selectedRow (rows.length - 1)
    let capacity := height - (if height >= 2 then 1 else 0)
    let start := Loam.Tui.Layout.trailingWindowStart selected (max 1 capacity)
    let visibleMonths := (snapshot.months.drop monthOffset).take monthCount
    (if height < 2 then [] else [tableHeader width visibleMonths]) ++
      ((rows.drop start).take capacity).zipIdx.map fun (row, offset) =>
        tableRow width (start + offset == selected) monthOffset monthCount row

/--
Series Calendar for recurring-plan management.

Rows are replaceable read-side plan selectors and columns are calendar months.
An explicit Scheduled occurrence shows its real day. A monitored expected month
with no matching explicit occurrence shows !. Months not expected by the current
pace remain completely blank.
-/
def linesSelectedWindow
    (snapshot : Loam.ScheduledCoverageReview.Snapshot)
    (selectedRow monthOffset monthCount : Nat) : List Widget :=
  if snapshot.rows.isEmpty then
    [ muted "No recurring plans are being monitored."
    , muted "Create a plan, or use Months/List to establish a recurring pattern."
    , muted "No monitoring row never means that an obligation is not due."
    ]
  else
    let rows := orderedRows snapshot
    let selected := min selectedRow (rows.length - 1)
    let visibleMonths := (snapshot.months.drop monthOffset).take monthCount
    [ muted ("Known through " ++ snapshot.observedAt)
    , muted <|
        match visibleMonths.head?, visibleMonths.getLast? with
        | some first, some last => "Month window: " ++ first ++ " .. " ++ last
        | _, _ => "Month window: (empty)"
    , line ""
    , tableHeader (39 + monthColumnWidth * max 1 monthCount) visibleMonths
    ] ++
    (rows.zipIdx.map fun (row, index) =>
      tableRow (39 + monthColumnWidth * max 1 monthCount) (index = selected) monthOffset monthCount row) ++
    [ line ""
    , muted "08 / 15 / 08,18 = explicit Scheduled day(s); ! = expected month with no explicit plan."
    , muted "Empty cell = no occurrence expected at the current pace; undecided expects no future months."
    , muted "Monitoring guides extension; it does not create recurrence authority."
    ]

def linesSelected
    (snapshot : Loam.ScheduledCoverageReview.Snapshot)
    (selectedRow : Nat) : List Widget :=
  linesSelectedWindow snapshot selectedRow 0 snapshot.months.length

def lines (snapshot : Loam.ScheduledCoverageReview.Snapshot) : List Widget :=
  linesSelected snapshot 0

end Loam.Tui.ScheduledCoveragePane
