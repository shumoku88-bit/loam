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

private def hasExpectedExplicit (row : Loam.ScheduledCoverageReview.Row) : Bool :=
  row.cells.any fun cell => cell.expected && !(cell.explicitCount == 0)

private def hasOffPattern (row : Loam.ScheduledCoverageReview.Row) : Bool :=
  row.cells.any fun cell => !cell.expected && !(cell.explicitCount == 0)

private def hasGap (row : Loam.ScheduledCoverageReview.Row) : Bool :=
  match row.firstMissing with
  | some _ => true
  | none => false

private def statusLabel (row : Loam.ScheduledCoverageReview.Row) : String :=
  if !hasExpectedExplicit row && hasGap row then
    "empty"
  else if hasGap row && hasOffPattern row then
    "gap+off"
  else if hasGap row then
    "gap"
  else if hasOffPattern row then
    "off-pattern"
  else
    "ok"

private def statusPriority (row : Loam.ScheduledCoverageReview.Row) : Nat :=
  if !hasExpectedExplicit row && hasGap row then
    0
  else if hasGap row then
    1
  else if hasOffPattern row then
    2
  else
    3

private def missingSortKey (row : Loam.ScheduledCoverageReview.Row) : String :=
  match row.firstMissing with
  | some month => month
  | none => "9999-99"

private def rowBefore
    (left right : Loam.ScheduledCoverageReview.Row) : Bool :=
  let leftPriority := statusPriority left
  let rightPriority := statusPriority right
  if leftPriority = rightPriority then
    let leftMissing := missingSortKey left
    let rightMissing := missingSortKey right
    if leftMissing = rightMissing then
      left.rule.name <= right.rule.name
    else
      leftMissing <= rightMissing
  else
    leftPriority < rightPriority

private def attentionText?
    (row : Loam.ScheduledCoverageReview.Row) : Option String :=
  match row.firstMissing with
  | some gap =>
      if !hasExpectedExplicit row then
        some (row.rule.name ++ ": no expected explicit plan in view; next gap " ++ gap)
      else if hasOffPattern row then
        some (row.rule.name ++ ": next gap " ++ gap ++ "; explicit off-pattern plan also exists")
      else
        some (row.rule.name ++ ": next gap " ++ gap)
  | none =>
      if hasOffPattern row then
        some (row.rule.name ++ ": explicit off-pattern plan exists")
      else
        none

private def attentionLines
    (rows : List Loam.ScheduledCoverageReview.Row) : List Widget :=
  let messages := rows.filterMap attentionText?
  if messages.isEmpty then
    [ line "Attention"
    , muted "  none in this window"
    ]
  else
    let shown := messages.take 5
    [line "Attention"] ++
      shown.map (fun message => muted ("  " ++ message)) ++
      (if messages.length > shown.length then
        [muted ("  ... and " ++ toString (messages.length - shown.length) ++ " more")]
       else [])

private def tableHeader (months : List String) : Widget :=
  line <|
    Loam.Tui.Layout.padRight 18 "Rule" ++
    Loam.Tui.Layout.padRight 11 "Pace" ++
    Loam.Tui.Layout.padRight 11 "Through" ++
    Loam.Tui.Layout.padRight 11 "Next gap" ++
    Loam.Tui.Layout.padRight 11 "Status" ++
    String.intercalate "" (months.map monthHeader)

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
    Loam.Tui.Layout.padRight 11 through ++
    Loam.Tui.Layout.padRight 11 gap ++
    Loam.Tui.Layout.padRight 11 (statusLabel row) ++
    String.intercalate "" (row.cells.map coverageCell)

def lines (snapshot : Loam.ScheduledCoverageReview.Snapshot) : List Widget :=
  if snapshot.rows.isEmpty then
    [ muted "No Scheduled coverage rules configured."
    , muted "Use Scheduled / m to start monitoring an explicit plan."
    , muted "Absence of a rule never implies that an obligation is not due."
    ]
  else
    let rows := snapshot.rows.mergeSort rowBefore
    [ muted ("Future explicit-plan coverage after " ++ snapshot.observedAt)
    , muted <|
        match snapshot.months.head?, snapshot.months.getLast? with
        | some first, some last => "Window: " ++ first ++ " .. " ++ last
        | _, _ => "Window: (empty)"
    ] ++
    attentionLines rows ++
    [ line ""
    , tableHeader snapshot.months
    ] ++
    rows.map tableRow ++
    [ muted "● explicit expected   ! expected but missing   · not expected   + explicit off-pattern"
    , muted "Status: empty = no expected explicit plan in view; gap = next expected month is missing."
    , muted "Coverage rules are monitoring only; they do not create recurrence authority."
    ]

end Loam.Tui.ScheduledCoveragePane
