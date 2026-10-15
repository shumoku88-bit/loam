import Loam.Review.AttentionReview
import Loam.Review.ScheduledReview
import Loam.Tui.DateJump
import Loam.Tui.CalendarGeometry
import Loam.Tui.Layout
import Loam.Tui.HomeLauncher
import Loam.Tui.Main
import Loam.Tui.Scroll
import Loam.Tui.Terminal

namespace Loam.Tui.Home

open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def wrappedLines (width : Nat) (text : String) (style : Style := .normal) : List Widget :=
  (Loam.Tui.Layout.wrapColumns (width - 1) text).map fun line =>
    .row [span " ", span line style]

private def monthTitle (state : State) : String :=
  Loam.Tui.Calendar.monthLabel (selectedMonth state)

private abbrev PendingEvidence := Except String (List Loam.ScheduledReview.Record)

private def pendingEvidence (snapshot : Snapshot) : PendingEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled =>
      Loam.ScheduledReview.currentOpenBeforeDate scheduled snapshot.actual.today

private def pendingDates : PendingEvidence → List String
  | .ok records => records.map (fun record => record.scheduledOn)
  | .error _ => []

private def moneyWindow (state : State) : String × String :=
  Loam.Tui.Calendar.monthWindow (selectedMonth state)

private def moneyMeasureInfo
    (snapshot : Snapshot) (state : State) : Option (MoneyCalendarSnapshot × List Loam.Core.MeasureId) :=
  match snapshot.moneyCalendar with
  | .loaded money =>
      let window := moneyWindow state
      some (money, money.flow.measuresInWindow window.1 window.2)
  | _ => none

private def moneyTitle (snapshot : Snapshot) (state : State) : String :=
  let month := monthTitle state
  match snapshot.moneyCalendar with
  | .notRequested => month ++ "  ± not requested"
  | .unavailable => month ++ "  ± unavailable"
  | .failed _ => month ++ "  ± read failed"
  | .loaded money =>
      let window := moneyWindow state
      let measures := money.flow.measuresInWindow window.1 window.2
      match measures with
      | [] => month ++ "  ±"
      | measure :: rest =>
          month ++ "  ± " ++ measure.token ++
            (if rest.isEmpty then "" else "  (" ++ toString measures.length ++ " measures)")

private def centeredText (width : Nat) (text : String) : String :=
  let textWidth := Loam.Tui.Layout.displayWidth text
  let padding := if textWidth < width then (width - textWidth) / 2 else 0
  repeatChar padding ' ' ++ text

/-!
The 7 money cells and 8 border/intersection glyphs occupy exactly
`8 + 7 * cellWidth`. A 14-column cap keeps a wide terminal from producing
indefinitely stretched day rectangles. When the readable minimum cannot fit,
retain the pre-existing compact rendering policy; never mistake it for a
proof-qualified fit.
-/
private def moneyCellWidth (paneWidth : Nat) : Nat :=
  match Loam.Tui.CalendarGeometry.maxFitCell? (paneWidth - 2) 10 14 1 with
  | some width => width
  | none => (paneWidth - 8) / 7

private def moneyGridWidth (paneWidth : Nat) : Nat :=
  8 + 7 * moneyCellWidth paneWidth

/-- Keep unoccupied width as intentional, nearly symmetric outer whitespace. -/
private def moneyGridCentered (paneWidth : Nat) (row : Widget) : Widget :=
  let inset := Loam.Tui.CalendarGeometry.leftMargin paneWidth (moneyGridWidth paneWidth)
  match row with
  | .row spans => .row (span (repeatChar inset ' ') :: spans)
  | .column _ => row

private def moneyRule
    (paneWidth : Nat) (left middle right : Char)
    (highlightCol : Option Nat := none)
    (isTopHighlight isBottomHighlight : Bool := false) : Widget :=
  let cellWidth := moneyCellWidth paneWidth
  let normalSegment := repeatChar cellWidth '─'
  let spans : List Span := Id.run do
    let mut acc : List Span := []
    for col in List.range 7 do
      let jChar := if col == 0 then left else middle
      let jSpan :=
        match highlightCol with
        | some h =>
            if isTopHighlight && col == h then
              span "╭" .series1
            else if isTopHighlight && col == h + 1 then
              span "╮" .series1
            else if isBottomHighlight && col == h then
              span "╰" .series1
            else if isBottomHighlight && col == h + 1 then
              span "╯" .series1
            else
              span (String.singleton jChar) .muted
        | none => span (String.singleton jChar) .muted
      acc := acc ++ [jSpan]
      let segSpan :=
        match highlightCol with
        | some h =>
            if (isTopHighlight || isBottomHighlight) && col == h then
              span normalSegment .series1
            else
              span normalSegment .muted
        | none => span normalSegment .muted
      acc := acc ++ [segSpan]
    let lastChar := right
    let lastSpan :=
      match highlightCol with
      | some h =>
          if isTopHighlight && h == 6 then
            span "╮" .series1
          else if isBottomHighlight && h == 6 then
            span "╯" .series1
          else
            span (String.singleton lastChar) .muted
      | none => span (String.singleton lastChar) .muted
    acc := acc ++ [lastSpan]
    return acc
  .row spans

private def moneyGridSpans
    (cells : List Span) (highlightCol : Option Nat := none) : List Span :=
  let sep (col : Nat) : Span :=
    match highlightCol with
    | some h =>
        if col == h || col == h + 1 then span "│" .series1
        else span "│" .muted
    | none => span "│" .muted
  let rec loop (cols : List (Span × Nat)) : List Span :=
    match cols with
    | [] => [sep 7]
    | (cell, idx) :: rest => sep idx :: cell :: loop rest
  loop cells.zipIdx

private def moneyGridRow (cells : List Span) (highlightCol : Option Nat := none) : Widget :=
  .row (moneyGridSpans cells highlightCol)

private def centerPill (width : Nat) (text : String) : String :=
  let textWidth := Loam.Tui.Layout.displayWidth text
  let leftPad := if textWidth < width then (width - textWidth) / 2 else 0
  let rightPad := if width > textWidth + leftPad then width - (textWidth + leftPad) else 0
  repeatChar leftPad ' ' ++ text ++ repeatChar rightPad ' '

private def moneyCalendarHeader (paneWidth : Nat) : Widget :=
  let cellWidth := moneyCellWidth paneWidth
  moneyGridRow <|
    ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map fun label =>
      span (centerPill cellWidth label) .muted

private def shortDay (date : String) : String :=
  match date.splitOn "-" with
  | [_, _, text] =>
      match text.toNat? with
      | some day => toString day
      | none => text
  | _ => date

private def moneyRowFor?
    (snapshot : Snapshot) (state : State) (date : String) :
    Option Loam.CalendarMoneyReview.Row := do
  let (money, measures) ← moneyMeasureInfo snapshot state
  let measure ← measures.head?
  money.flow.rowFor? date measure

private def moneyCellStyle
    (today : String) (state : State) (date : String) (isCurrentMonth : Bool := true) : Style :=
  if date == state.selectedDate then
    if date == today then .selectedUnderlined else .selected
  else if !isCurrentMonth then
    .muted
  else if date == today then
    .underlined
  else
    .normal

private def moneyDateSlotSpan
    (paneWidth : Nat) (today : String) (pastOpenDates : List String)
    (snapshot : Snapshot) (state : State) (slot : Loam.Tui.Calendar.DaySlot) : Span :=
  let cellWidth := moneyCellWidth paneWidth
  let pending := slot.isCurrentMonth && pastOpenDates.any fun candidate => candidate == slot.date
  let unresolved :=
    if slot.isCurrentMonth then
      match moneyRowFor? snapshot state slot.date with
      | some row => decide (0 < row.unresolvedEffectCount)
      | none => false
    else false
  let markers := (if pending then "!" else "") ++ (if unresolved then "?" else "")
  let text := " " ++ shortDay slot.date ++ markers
  span (Loam.Tui.Layout.padRight cellWidth text)
    (moneyCellStyle today state slot.date slot.isCurrentMonth)

/-- One shared calendar day cell; focus, Today, overdue Scheduled and role unknown
markers all compose in this larger money calendar. -/
def moneyDateSpan
    (paneWidth : Nat) (today : String) (pastOpenDates : List String)
    (snapshot : Snapshot) (state : State) (date : String) : Span :=
  moneyDateSlotSpan paneWidth today pastOpenDates snapshot state { date := date, isCurrentMonth := true }

private def groupedQuantaText
    (money : MoneyCalendarSnapshot)
    (measure : Loam.Core.MeasureId)
    (quanta : Int) : String :=
  Loam.MeasurePresentation.formatGroupedAmount money.presentation measure quanta

/-- Shared period flow presentation over the existing directional summary.
Day zoom names its month totals; every Measure and read state remains distinct. -/
private def periodSummaryLines
    (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let m := selectedMonth state
  let isYear := state.zoomLevel == .year
  let firstMonth := if isYear then { m with month := 1 } else m
  let lastMonth := if isYear then { m with month := 12 } else m
  -- Lexical bounds over admitted ISO dates, not dates to publish. Day 32 includes
  -- the final month's last day without overflowing the four-digit year domain.
  let window := (Loam.Tui.Calendar.dateForDay firstMonth 1, Loam.Tui.Calendar.dateForDay lastMonth 32)
  let label := if isYear then s!"Year Flow ({m.year})" else s!"Month Flow ({monthTitle state})"
  let tokens (items : List String) : List Widget :=
    (Loam.Tui.Layout.flowTokens (width - 3) "  " items).flatMap fun line =>
      wrappedLines width line
  let flowLines :=
    match snapshot.moneyCalendar with
    | .notRequested => wrappedLines width "flow not requested" .muted
    | .unavailable => wrappedLines width "flow unavailable" .muted
    | .failed message =>
        wrappedLines width "flow read failed" ++ wrappedLines width message .muted
    | .loaded money =>
        let measures := money.flow.measuresInWindow window.1 window.2
        if measures.isEmpty then
          wrappedLines width "No recorded income/expense flow." .muted
        else
          measures.flatMap fun measure =>
            let summary := money.flow.summaryForWindow window.1 window.2 measure
            let format := groupedQuantaText money measure
            let net := summary.plus.quanta - summary.minus.quanta
            let netText := (if net > 0 then "+" else "") ++ format net
            let divisor := if isYear then some 12 else Loam.Tui.Calendar.daysInMonth? m
            wrappedLines width ("Measure: " ++ measure.token ++
              (if summary.unresolvedEffectCount == 0 then "" else " [partial]")) ++
            (if summary.unresolvedEffectCount == 0 then [] else
              tokens [s!"? {summary.unresolvedEffectCount} unresolved effects"]) ++
            tokens ["In: +" ++ format summary.plus.quanta, "Out: -" ++ format summary.minus.quanta] ++
            tokens ["Net: " ++ netText] ++
            (if state.zoomLevel == .day then [] else
              match divisor with
              | some days =>
                  let avg := format (summary.minus.quanta / (days : Int))
                  let unit := if isYear then "month" else "day"
                  tokens [s!"Out/{unit}: ~{avg}", if isYear then "(full year)" else "(full month)"]
              | none => [])
  (if state.zoomLevel == .day then [] else
    [.row [span " ", span (repeatChar (width - 2) '─') .muted]]) ++
  wrappedLines width label ++
    (if state.zoomLevel == .day then [] else
      let count := (homeActualRecords snapshot state).length
      wrappedLines width (toString count ++ (if count == 1 then " transaction recorded" else " transactions recorded")) .muted) ++
    flowLines

private def moneyAmountSlotSpan
    (paneWidth : Nat)
    (snapshot : Snapshot) (state : State)
    (slot : Loam.Tui.Calendar.DaySlot) (positive : Bool) : Span :=
  let cellWidth := moneyCellWidth paneWidth
  if !slot.isCurrentMonth then
    span (repeatChar cellWidth ' ') .muted
  else
    let text :=
      match moneyRowFor? snapshot state slot.date, moneyMeasureInfo snapshot state with
      | some row, some (money, _) =>
          let directional := row.directional
          let amount := if positive then directional.plus.quanta else directional.minus.quanta
          if amount = 0 then ""
          else
            let signText := if positive then "+" else "-"
            let rendered :=
              Loam.MeasurePresentation.formatAmount money.presentation row.measure amount
            let plain := signText ++ rendered
            let grouped :=
              signText ++
                Loam.MeasurePresentation.formatGroupedAmount
                  money.presentation row.measure amount
            if Loam.Tui.Layout.displayWidth grouped ≤ cellWidth then grouped
            else if Loam.Tui.Layout.displayWidth plain ≤ cellWidth then plain
            else "…"
      | _, _ => ""
    span (Loam.Tui.Layout.padLeft cellWidth text)
      (if slot.date == state.selectedDate then .selected else .normal)

private def moneyAmountSpan
    (paneWidth : Nat)
    (snapshot : Snapshot) (state : State)
    (date : String) (positive : Bool) : Span :=
  moneyAmountSlotSpan paneWidth snapshot state { date := date, isCurrentMonth := true } positive

private def blankMoneyCell (paneWidth : Nat) : Span :=
  span (repeatChar (moneyCellWidth paneWidth) ' ')

private def selectedSlotPosition? (state : State) : Option (Nat × Nat) :=
  let m := selectedMonth state
  let slots := Loam.Tui.Calendar.gridSlots m
  (slots.zipIdx.find? (fun (s, _) => s.date == state.selectedDate)).map fun (_, idx) =>
    (idx / 7, idx % 7)

private def moneyCalendarRows
    (paneWidth : Nat) (today : String) (pastOpenDates : List String)
    (snapshot : Snapshot) (state : State) (selPos? : Option (Nat × Nat)) : List Widget :=
  let daySlots := Loam.Tui.Calendar.gridSlots (selectedMonth state)
  (List.range 6).flatMap fun row =>
    let isSelRow := selPos?.map (·.1) == some row
    let selCol := if isSelRow then selPos?.map (·.2) else none
    let slots := (List.range 7).map fun col =>
      (daySlots[row * 7 + col]?).getD { date := "", isCurrentMonth := false }
    let dateLine := moneyGridRow (slots.map fun slot =>
      if slot.date.isEmpty then blankMoneyCell paneWidth
      else moneyDateSlotSpan paneWidth today pastOpenDates snapshot state slot) selCol
    let plusLine := moneyGridRow (slots.map fun slot =>
      if slot.date.isEmpty then blankMoneyCell paneWidth
      else moneyAmountSlotSpan paneWidth snapshot state slot true) selCol
    let minusLine := moneyGridRow (slots.map fun slot =>
      if slot.date.isEmpty then blankMoneyCell paneWidth
      else moneyAmountSlotSpan paneWidth snapshot state slot false) selCol
    let nextIsSelRow := selPos?.map (·.1) == some (row + 1)
    let bottomRule :=
      if row = 5 then
        moneyRule paneWidth '└' '┴' '┘' selCol false isSelRow
      else
        let ruleHighlight := if isSelRow then selCol else if nextIsSelRow then selPos?.map (·.2) else none
        moneyRule paneWidth '├' '┼' '┤' ruleHighlight nextIsSelRow isSelRow
    [ dateLine
    , plusLine
    , minusLine
    , bottomRule
    ]

private def moneyCalendarBlock
    (paneWidth : Nat) (snapshot : Snapshot) (state : State)
    (pastOpenDates : List String) : List Widget :=
  let gridWidth := moneyGridWidth paneWidth
  let title := moneyTitle snapshot state
  let title := if Loam.Tui.Layout.displayWidth title ≤ gridWidth then title
    else Loam.Tui.Layout.clip (gridWidth - 1) title ++ "…"
  let selPos? := selectedSlotPosition? state
  let topRowHighlight := if selPos?.map (·.1) == some 0 then selPos?.map (·.2) else none
  let gridRows :=
    [ plainLine (centeredText gridWidth title)
    , moneyRule paneWidth '┌' '┬' '┐'
    , moneyCalendarHeader paneWidth
    , moneyRule paneWidth '├' '┼' '┤' topRowHighlight true false
    ] ++ moneyCalendarRows paneWidth snapshot.actual.today pastOpenDates snapshot state selPos?
  (gridRows.map (moneyGridCentered paneWidth)) ++
    [blankLine] ++ periodSummaryLines paneWidth snapshot state


private def displayDescription (record : ReviewRecord) : String :=
  if record.description.isEmpty then "(no description)"
  else Loam.ActualReview.displayText record.description

/-- Detail retains its quanta convention independently of optional money-calendar reads. -/
private def effectLines
    (width : Nat) (locus : String) (measure : Loam.Core.MeasureId) (quanta : Int) : List Widget :=
  let amount := (if quanta > 0 then "+" else "") ++
    Loam.MeasurePresentation.groupDisplayedNumber (toString quanta) ++ " " ++ measure.token
  let amountWidth := Loam.Tui.Layout.displayWidth amount
  if Loam.Tui.Layout.displayWidth locus + amountWidth + 5 ≤ width then
    [ .row [span "   ", span (Loam.Tui.Layout.padRight (width - amountWidth - 5) locus),
        span "  ", span amount] ]
  else
    wrappedLines width locus ++ wrappedLines width ("Quanta: " ++ amount)

private def actualRecordLines
    (width : Nat) (isSelected : Bool) (state : State)
    (record : ReviewRecord) : List Widget :=
  let dateText :=
    match state.zoomLevel with
    | .day => ""
    | .month | .year => record.date.getD "date unknown" ++ "  "
  let title := dateText ++ displayDescription record
  let titleRows := (Loam.Tui.Layout.wrapColumns (width - 5) title).zipIdx.map fun (line, index) =>
    .row [span (if index == 0 then (if isSelected then " ▶ - " else "   - ") else "     ") .muted,
      span (Loam.Tui.Layout.padRight (width - 5) line)
        (if isSelected && state.activePane == .detail then .selected else .normal)]
  titleRows ++ record.event.effects.flatMap fun effect =>
    effectLines width effect.locus.token effect.measure effect.quantity.quanta

private def actualLines (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let records := (homeActualRecords snapshot state).reverse
  if records.isEmpty then wrappedLines width "(none recorded)" .muted
  else records.zipIdx.flatMap fun (record, idx) =>
    actualRecordLines width (idx == state.detailCursor) state record

private def scheduledLines (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  match homeScheduledEvidence snapshot state with
  | .error message =>
      wrappedLines width "Scheduled: Unavailable" ++ wrappedLines width message
  | .ok (.due first rest) =>
      wrappedLines width s!"Scheduled: Due ({rest.length + 1})" ++
      (first :: rest).flatMap fun record =>
        wrappedLines width
          ("Scheduled: " ++ record.scheduledOn ++ "  [Open]  " ++ Loam.ScheduledReview.summary record) ++
        record.movement.changes.flatMap fun change =>
          effectLines width change.coordinate.token record.measure change.quantity.quanta
  | .ok .unknown => wrappedLines width "Scheduled: Unknown" ++
      wrappedLines width "Unknown; completeness not established."

private def pendingLines (width : Nat) : PendingEvidence → List Widget
  | .error message => wrappedLines width ("[Unavailable] " ++ message)
  | .ok [] => wrappedLines width "(none; no past-date current-open Scheduled occurrence)" .muted
  | .ok records => records.flatMap fun record =>
      wrappedLines width
        (record.scheduledOn ++ "  [Still open]  " ++ Loam.ScheduledReview.summary record)

private def pendingSection (width : Nat) (pending : PendingEvidence) : List Widget :=
  match pending with
  | .ok [] => []
  | .ok records => [blankLine] ++ wrappedLines width s!"Pending Scheduled: {records.length}" ++
      pendingLines width pending
  | .error _ => [blankLine] ++ wrappedLines width "Pending Scheduled: Unavailable" ++
      pendingLines width pending

private def monthNames : List String :=
  ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

/-- Two aligned rows per month: selection/Today belong to the name, never the count. -/
private def monthCellRows
    (cellWidth : Nat) (today : String) (state : State) (snapshot : Snapshot)
    (year month : Nat) : List (List Span) :=
  let mName := Loam.Tui.Calendar.padded 2 month ++ " " ++
    monthNames.getD (month - 1) (toString month)
  let count := (recordsForMonth snapshot year month).length
  let cur := selectedMonth state
  let isSelected := cur.year == year && cur.month == month
  let isTodayMonth :=
    match Loam.Tui.Calendar.monthOf? today with
    | some tm => tm.year == year && tm.month == month
    | none => false
  let nameStyle :=
    if isSelected then
      if isTodayMonth then .selectedUnderlined else .selected
    else if isTodayMonth then .underlined else .normal
  let label := if isSelected then "[" ++ mName ++ "]" else " " ++ mName ++ " "
  let countLabel := if count == 1 then " record" else " records"
  let countText := " " ++ toString count ++ countLabel
  [ [span label nameStyle, span (repeatChar (cellWidth - Loam.Tui.Layout.displayWidth label) ' ')]
  , [span (" " ++ toString count) (if count == 0 then .muted else .normal),
     span countLabel .muted, span (repeatChar (cellWidth - Loam.Tui.Layout.displayWidth countText) ' ')]
  ]

private def monthQuarterRows
    (columns cellWidth : Nat) (today : String) (state : State) (snapshot : Snapshot)
    (year startMonth : Nat) : List Widget :=
  let cells := (List.range 3).map fun col =>
    monthCellRows cellWidth today state snapshot year (startMonth + col)
  (List.range ((3 + columns - 1) / columns)).flatMap fun group =>
    let visibleCells := (cells.drop (group * columns)).take columns
    (List.range 2).map fun row =>
      .row ([span " "] ++ (visibleCells.zipIdx).flatMap fun (cell, index) =>
        (if index == 0 then [] else [span "  "]) ++ cell.getD row [])

private def monthCalendarPane
    (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let year := (selectedMonth state).year
  -- The year's total bounds every month's digit count. Never fit by clipping counts.
  let minimumCell := max 14 ((toString (recordsForYear snapshot year).length).length + 9)
  let columns := if width ≥ minimumCell * 3 + 5 then 3
    else if width ≥ minimumCell * 2 + 3 then 2 else 1
  let cellWidth := min 28 ((width - 1 - (columns - 1) * 2) / columns)
  [blankLine] ++ [1, 4, 7, 10].flatMap (fun startMonth =>
    monthQuarterRows columns cellWidth snapshot.actual.today state snapshot year startMonth ++ [blankLine])

private def yearOverviewPane
    (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let curYear := (selectedMonth state).year
  -- Keep the five neighboring choices inside the existing DateJump year domain.
  let startYear := max 1000 (min 9995 (curYear - 2))
  let years := List.range 5 |>.map fun i => startYear + i
  let tableWidth := min 36 (width - 1)
  let countWidth := tableWidth - 10
  let rows := years.map fun y =>
    let count := (recordsForYear snapshot y).length
    let isSelected := curYear == y
    let isTodayYear :=
      match Loam.Tui.Calendar.monthOf? snapshot.actual.today with
      | some tm => tm.year == y
      | none => false
    let style :=
      if isSelected then
        if isTodayYear then .selectedUnderlined else .selected
      else if isTodayYear then .underlined else .normal
    let label := if isSelected then "[" ++ toString y ++ "]" else " " ++ toString y ++ " "
    .row [span " ", span label style, span "   ",
      span (Loam.Tui.Layout.padLeft countWidth (toString count)) (if count == 0 then .muted else .normal)]
  [blankLine,
   .row [span " Year     " .muted, span (Loam.Tui.Layout.padLeft countWidth "Records") .muted],
   blankLine] ++ rows ++ [blankLine]

/-- One quiet 7-column Week strip. All rows share their exact terminal
    column geometry. Calendar/Actual/Scheduled evidence is not modified. -/
private def weekCellWidth (paneWidth : Nat) : Nat :=
  match Loam.Tui.CalendarGeometry.maxFitCell? (paneWidth - 2) 8 12 1 with
  | some width => width
  | none => (paneWidth - 8) / 7

private def weekStripRow (paneWidth : Nat) (cells : List (String × Style)) : Widget :=
  let cellWidth := weekCellWidth paneWidth
  let occupied := Loam.Tui.CalendarGeometry.gridWidth cellWidth 1
  let inset := Loam.Tui.CalendarGeometry.leftMargin paneWidth occupied
  .row <| [span (repeatChar inset ' ')] ++
    (cells.zipIdx).flatMap fun ((label, style), index) =>
      (if index == 0 then [] else [span " " .muted]) ++
      [span (centerPill cellWidth label) style]

/-- An empty marker means *no explicitly open occurrence on this date*, not a
    proof that no Scheduled obligation exists. Read failures remain S?. -/
private def weekScheduledMark
    (openRecords : Except String (List Loam.ScheduledReview.Record))
    (date : String) (cellWidth : Nat) : String :=
  match openRecords with
  | .error _ => "S?"
  | .ok records =>
      let count := (records.filter fun record => record.scheduledOn == date).length
      if count == 0 then ""
      else
        let full := "S" ++ toString count
        if Loam.Tui.Layout.displayWidth full ≤ cellWidth then full else "S+"

private def weekStripRows
    (paneWidth : Nat) (snapshot : Snapshot) (state : State)
    (slots : List Loam.Tui.Calendar.DaySlot) : List Widget :=
  let cellWidth := weekCellWidth paneWidth
  let openRecords : Except String (List Loam.ScheduledReview.Record) :=
    match snapshot.scheduled with
    | .error message => .error message
    | .ok scheduled => Loam.ScheduledReview.orderedCurrentOpenRecords scheduled
  let weekdays := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  if cellWidth ≥ 8 then
    let dayLabels := (slots.zip weekdays).map fun (slot, weekday) =>
      let day := shortDay slot.date
      let title := weekday ++ " " ++ day
      let isSelected := slot.date == state.selectedDate
      let isToday := slot.date == snapshot.actual.today
      let label := if isSelected then
        if cellWidth ≥ title.length + 4 then "[ " ++ title ++ " ]"
        else "[" ++ title ++ "]"
        else title
      let style :=
        if isSelected then
          if isToday then Style.selectedUnderlined else Style.selected
        else
          moneyCellStyle snapshot.actual.today state slot.date slot.isCurrentMonth
      (label, style)
    let dayStatus := slots.map fun slot =>
      let scheduled := weekScheduledMark openRecords slot.date cellWidth
      let isSelected := slot.date == state.selectedDate
      let isToday := slot.date == snapshot.actual.today
      let label :=
        if scheduled.isEmpty && isToday then
          if cellWidth ≥ 5 then "Today" else "T"
        else scheduled
      let style :=
        if isSelected then
          if isToday then Style.underlined else Style.normal
        else if isToday then Style.underlined
        else Style.muted
      (label, style)
    [ weekStripRow paneWidth dayLabels
    , weekStripRow paneWidth dayStatus
    ]
  else
    let dayLabels := slots.map fun slot =>
      let day := shortDay slot.date
      let label := if slot.date == state.selectedDate then
        if cellWidth ≥ 4 then "[" ++ day ++ "]" else ">" ++ day
        else day
      (label, moneyCellStyle snapshot.actual.today state slot.date slot.isCurrentMonth)
    let dayStatus := slots.map fun slot =>
      let scheduled := weekScheduledMark openRecords slot.date cellWidth
      let label :=
        if scheduled.isEmpty && slot.date == snapshot.actual.today then
          if cellWidth ≥ 5 then "Today" else "T"
        else scheduled
      (label, if slot.date == snapshot.actual.today then Style.underlined
         else if slot.date == state.selectedDate then Style.normal
         else Style.muted)
    [ weekStripRow paneWidth (weekdays.map fun day => (day, Style.muted))
    , weekStripRow paneWidth dayLabels
    , weekStripRow paneWidth dayStatus
    ]

/-- The week is one contiguous navigator. Daily evidence belongs only to Detail. -/
private def weekTitle (state : State) : String :=
  let slots := (Loam.Tui.Calendar.weekSlotsForDate? state.selectedDate).getD []
  match slots.head?, slots.reverse.head? with
  | some first, some last => s!"Week {first.date} .. {last.date}"
  | _, _ => "Week unavailable"

private def weekNavigationRows
    (paneWidth : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let slots := (Loam.Tui.Calendar.weekSlotsForDate? state.selectedDate).getD []
  wrappedLines paneWidth (weekTitle state) ++ weekStripRows paneWidth snapshot state slots

/-- Exact directional flow over the same admitted read answer, not a balance. -/
private def dayFlowLines
    (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  match snapshot.moneyCalendar with
  | .notRequested => wrappedLines width "Flow not requested"
  | .unavailable => wrappedLines width "Flow unavailable"
  | .failed message =>
      wrappedLines width "Flow read failed" ++ wrappedLines width message
  | .loaded money =>
      let window := moneyWindow state
      let measures := money.flow.measuresInWindow window.1 window.2
      let lines := measures.filterMap fun measure =>
        (money.flow.rowFor? state.selectedDate measure).map fun row =>
          let format := groupedQuantaText money measure
          let plus := row.directional.plus.quanta
          let minus := row.directional.minus.quanta
          let net := plus - minus
          let sign := if net > 0 then "+" else ""
          let unresolvedLabel := if row.unresolvedEffectCount == 0 then ""
            else s!"  [? {row.unresolvedEffectCount} unresolved]"
          s!"{measure.token}  In:+{format plus}  Out:-{format minus}  Net:{sign}{format net}{unresolvedLabel}"
      if lines.isEmpty then wrappedLines width "No recorded income/expense flow on this day." .muted
      else lines.flatMap (wrappedLines width)

private def wideCalendarPane
    (paneWidth : Nat)
    (snapshot : Snapshot) (state : State) (pastOpenDates : List String)
    (compactDay : Bool) : List Widget :=
  match state.zoomLevel with
  | .day =>
      if compactDay then
        weekNavigationRows paneWidth snapshot state ++ [blankLine] ++
          periodSummaryLines paneWidth snapshot state
      else
        moneyCalendarBlock paneWidth snapshot state pastOpenDates
  | .month =>
      monthCalendarPane paneWidth snapshot state ++ periodSummaryLines paneWidth snapshot state
  | .year =>
      yearOverviewPane paneWidth snapshot state ++ periodSummaryLines paneWidth snapshot state

private def detailPrefix
    (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  match state.zoomLevel with
  | .day => dayFlowLines width snapshot state ++ [blankLine, plainLine " Actual"]
  | .month | .year => [plainLine s!" Actual Transactions: {(homeActualRecords snapshot state).length}"]

private def wideDetailLines
    (width : Nat) (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : List Widget :=
  detailPrefix width snapshot state ++ actualLines width snapshot state ++
    (if state.zoomLevel == .day then
      [blankLine] ++ scheduledLines width snapshot state ++ pendingSection width pending
     else [])

-- Tiny bodies keep readable evidence rather than spending every row on borders.
private def detailVisibleRows (panelRows : Nat) : Nat :=
  if panelRows < 3 then panelRows else panelRows - 2

private def widePanelRows (bounds : Bounds) (footerRows : Nat) : Nat :=
  Loam.Tui.Layout.footerBodyCapacity bounds footerRows - 2

private def detailPaneWidth (bounds : Bounds) (state : State) : Nat :=
  min 72 (max (if state.zoomLevel == .day then 50 else 64)
    (Loam.Tui.Layout.contentWidth bounds * 36 / 100))

private def detailInnerWidth (bounds : Bounds) (state : State) : Nat :=
  (if bounds.width ≥ 120 then detailPaneWidth bounds state
   else Loam.Tui.Layout.contentWidth bounds) - 2

/-- Width-dependent rows over one immutable admitted Home snapshot. Session-local only.
The IO shell discards this projection whenever a workspace returns/reloads evidence. -/
structure DetailLayout where
  width : Nat
  columns : Nat
  selectedDate : String
  zoomLevel : Loam.Tui.DateJump.ZoomLevel
  records : Array ReviewRecord
  starts : Array Nat
  counts : Array Nat
  rows : Array Widget
  /-- Date/period overview at every width, independent of the transaction cursor. -/
  overviewRows : List Widget

private def detailViewport (layout : DetailLayout) (state : State)
    (offset visible : Nat) : List Widget :=
  let selectedRows := match layout.records[state.detailCursor]? with
    | none => #[]
    | some record => (actualRecordLines layout.width true state record).toArray
  let start := layout.starts[state.detailCursor]?.getD layout.rows.size
  (List.range (min visible (layout.rows.size - offset))).filterMap fun i =>
    let row := offset + i
    if start ≤ row && row < start + selectedRows.size then selectedRows[row - start]?
    else layout.rows[row]?

private def selectedPeriod (state : State) : String :=
  match state.zoomLevel with
  | .day => "Day " ++ state.selectedDate
  | .month => "Month " ++ monthTitle state
  | .year => "Year " ++ toString (selectedMonth state).year

private def viewportLabel (total visible offset : Nat) : String :=
  if total == 0 then "0/0"
  else if visible == 0 then s!"0/{total} ↓"
  else s!"{offset + 1}-{min (offset + visible) total}/{total}" ++
    (if offset > 0 then " ↑" else "") ++ (if offset + visible < total then " ↓" else "")

private def detailPanel
    (width height : Nat) (state : State) (layout : DetailLayout) : Widget :=
  let visible := detailVisibleRows height
  let offset := Loam.Tui.Scroll.clamp layout.rows.size visible state.detailScroll
  let content := .column (detailViewport layout state offset visible)
  if height < 3 then content
  else Loam.Tui.Layout.framedPanel width height (selectedPeriod state ++ " / Detail")
    content (state.activePane == .detail) (some (viewportLabel layout.rows.size visible offset))

private def homeContext (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let viewName := Loam.Tui.DateJump.zoomLabel state.zoomLevel
  [ Widget.row [span " LOAM Home" .normal, span (if width ≥ 80 then "   known through " else "  through ") .muted, span snapshot.actual.today]
  , Widget.row [span " Focus: " .muted, span state.selectedDate,
      span "   View: " .muted, span viewName]
  ].map fun row => Loam.Tui.Layout.clipWidgetRow width row

private def calendarRows
    (width : Nat) (snapshot : Snapshot) (state : State) (compactDay : Bool) : List Widget :=
  wideCalendarPane width snapshot state (pendingDates (pendingEvidence snapshot)) compactDay

/-- Prepare wrapping and the wide overview once, not for every queued selection event. -/
def prepareDetail (bounds : Bounds) (snapshot : Snapshot) (state : State) : DetailLayout := Id.run do
  let width := detailInnerWidth bounds state
  let records := (homeActualRecords snapshot state).reverse.toArray
  let pending := pendingEvidence snapshot
  let mut start := (detailPrefix width snapshot state).length
  let mut starts := #[]
  let mut counts := #[]
  for record in records do
    let count := (actualRecordLines width false state record).length
    starts := starts.push start
    counts := counts.push count
    start := start + count
  return {
    width := width
    columns := bounds.width
    selectedDate := state.selectedDate
    zoomLevel := state.zoomLevel
    records := records
    starts := starts
    counts := counts
    rows := (wideDetailLines width snapshot {state with detailCursor := records.size} pending).toArray
    overviewRows := calendarRows
      ((if bounds.width ≥ 120 then
        Loam.Tui.Layout.contentWidth bounds - 1 - detailPaneWidth bounds state
       else Loam.Tui.Layout.contentWidth bounds) - 2)
      snapshot state (bounds.width < 120)
  }

/-- Reuse only while period and wrapping width agree. Snapshot lifetime is shell-owned. -/
def detailLayoutFor (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (cached : Option DetailLayout := none) : DetailLayout :=
  match cached with
  | some layout =>
      if layout.columns == bounds.width &&
          layout.selectedDate == state.selectedDate && layout.zoomLevel == state.zoomLevel then layout
      else prepareDetail bounds snapshot state
  | none => prepareDetail bounds snapshot state

/-- Follow the selected calendar cell, but never undo explicit overview browsing. -/
private def overviewOffset (visible : Nat) (rows : List Widget) (state : State)
    (compactDay : Bool := false) : Nat :=
  -- The week ribbon fits its selected day within the first rows. Start at its
  -- title rather than scrolling the title out of sight to follow the selection.
  let offset := if state.overviewManualScroll then state.overviewScroll
    else if compactDay && state.zoomLevel == .day then 0
    else match rows.zipIdx.find? (fun (row, _) => row.lines.flatten.any fun cell =>
        cell.style == .selected || cell.style == .selectedUnderlined) with
    | none => state.overviewScroll
    | some (_, index) =>
        if state.zoomLevel == .month then
          -- Keep a month name/count pair together. When it cannot fit from the
          -- top, start at the selected name, not an orphan count from its neighbor.
          if index + min 2 visible ≤ visible then 0 else index
        else
          let focusRows := if state.zoomLevel == .day then min 3 visible else min 1 visible
          index + focusRows - visible
  Loam.Tui.Scroll.clamp rows.length visible offset

/-- Overflow is in the border rather than consuming or moving a content row. -/
private def calendarPanel
    (width height : Nat) (snapshot : Snapshot) (state : State)
    (layout : DetailLayout) (compactDay : Bool := false) : Widget :=
  let rows := layout.overviewRows
  let visible := if height < 3 then height else height - 2
  let offset := overviewOffset visible rows state compactDay
  if height < 3 then
    if compactDay && !state.overviewManualScroll then
      let slots := (Loam.Tui.Calendar.weekSlotsForDate? state.selectedDate).getD []
      let strip := weekStripRows (width - 2) snapshot state slots
      -- At small widths the second strip row is the dates; at larger ones the first is.
      .column ((strip.drop (if weekCellWidth (width - 2) < 8 then 1 else 0)).take height)
    else .column ((rows.drop offset).take visible)
  else
    let title := match state.zoomLevel with
      | .day => "Calendar / " ++ monthTitle state
      | .month => s!"Months / {(selectedMonth state).year}"
      | .year => "Years"
    Loam.Tui.Layout.framedPanel width height title
      (.column ((rows.drop offset).take visible)) (state.activePane == .calendar)
      (some (viewportLabel rows.length visible offset))

/-- A compact Day never merges the two roles. Fit the complete week navigator,
    or use one unframed date strip on short terminals; Detail gets the remainder. -/
private def stackedDayHeights
    (bounds : Bounds) (footerRows : Nat) (state : State) (layout : DetailLayout) : Option (Nat × Nat) :=
  let available := widePanelRows bounds footerRows
  if bounds.width < 120 && state.zoomLevel == .day then
    let innerWidth := Loam.Tui.Layout.contentWidth bounds - 2
    let weekRows := (wrappedLines innerWidth (weekTitle state)).length +
      (if weekCellWidth innerWidth ≥ 8 then 2 else 3)
    let fullOverview := layout.overviewRows.length + 2
    -- Do not hide month evidence above a mostly empty Detail when both fit.
    let top := if available ≥ fullOverview + layout.rows.size + 2 then fullOverview
      else if available ≥ weekRows + 2 + 4 then weekRows + 2 else min 1 available
    some (top, available - top)
  else none

private def homeBody
    (bounds : Bounds) (footerRows : Nat) (snapshot : Snapshot) (state : State)
    (layout : DetailLayout) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let height := widePanelRows bounds footerRows
  let context := homeContext bounds snapshot state
  if bounds.width ≥ 120 then
    let rightWidth := detailPaneWidth bounds state
    let leftWidth := width - 1 - rightWidth
    let left := calendarPanel leftWidth height snapshot state layout false
    let right := detailPanel rightWidth height state layout
    context ++ Loam.Tui.Layout.sideBySide height leftWidth rightWidth left right " "
  else
    match stackedDayHeights bounds footerRows state layout with
    | some (calendarHeight, detailHeight) =>
        let calendar := calendarPanel width calendarHeight snapshot state layout true
        let detail := detailPanel width detailHeight state layout
        context ++ Loam.Tui.Layout.widgetRows calendar ++ Loam.Tui.Layout.widgetRows detail
    | none =>
        let panel := if state.activePane == .detail then
            detailPanel width height state layout
          else calendarPanel width height snapshot state layout true
        context ++ Loam.Tui.Layout.widgetRows panel

private structure HelpItem where
  key : String
  label : String

private def helpItemWidth (item : HelpItem) : Nat :=
  Loam.Tui.Layout.displayWidth item.key + 1 + Loam.Tui.Layout.displayWidth item.label

private def wrapHelpItems (width : Nat) (items : List HelpItem) : List (List HelpItem) :=
  let separatorWidth := 3
  let rec loop
      (current : List HelpItem) (currentWidth : Nat)
      (remaining : List HelpItem) (acc : List (List HelpItem)) : List (List HelpItem) :=
    match remaining with
    | [] =>
        if current.isEmpty then acc.reverse
        else (current.reverse :: acc).reverse
    | item :: rest =>
        let itemWidth := helpItemWidth item
        if current.isEmpty then
          loop [item] itemWidth rest acc
        else if currentWidth + separatorWidth + itemWidth ≤ width then
          loop (item :: current) (currentWidth + separatorWidth + itemWidth) rest acc
        else
          loop [item] itemWidth rest (current.reverse :: acc)
  loop [] 0 items []

private def helpRow (category : String) (showCategory : Bool) (items : List HelpItem) : Widget :=
  let categoryWidth := 11
  let categoryText :=
    if showCategory then Loam.Tui.Layout.padRight categoryWidth category
    else String.ofList (List.replicate categoryWidth ' ')
  let itemSpans :=
    (items.zipIdx).flatMap fun (item, index) =>
      (if index = 0 then [] else [span "   " .muted]) ++
      [span item.key, span (" " ++ item.label) .muted]
  .row ([span categoryText .muted] ++ itemSpans)

private def helpGroupLines
    (width : Nat) (category : String) (items : List HelpItem) : List Widget :=
  let categoryWidth := 11
  let itemWidth := width - min width categoryWidth
  (wrapHelpItems itemWidth items).zipIdx.map fun (row, index) =>
    helpRow category (index = 0) row

private def navigationHelp (state : State) : String × List HelpItem :=
  if state.activePane == .detail then
    ("Detail",
      [ { key := "[j/k]", label := "select" }
      , { key := "[Enter]", label := "open" }
      , { key := "[Ctrl-d/u]", label := "page" }
      ])
  else
    match state.zoomLevel with
    | .day =>
        ("Day",
          [ { key := "[h/l]", label := "day" }
          , { key := "[k/j]", label := "week" }
          , { key := "[Enter]", label := "open" }
          , { key := "[t]", label := "today" }
          , { key := "[/]", label := "jump" }
          , { key := "[z]", label := "zoom" }
          ])
    | .month =>
        ("Month",
          [ { key := "[h/l]", label := "month" }
          , { key := "[k/j]", label := "quarter" }
          , { key := "[Enter]", label := "days" }
          , { key := "[t]", label := "today" }
          , { key := "[/]", label := "jump" }
          , { key := "[z]", label := "zoom" }
          ])
    | .year =>
        ("Year",
          [ { key := "[h/l/k/j]", label := "year" }
          , { key := "[Enter]", label := "months" }
          , { key := "[t]", label := "today" }
          , { key := "[/]", label := "jump" }
          , { key := "[z]", label := "zoom" }
          ])

private def viewHelp (state : State) : List HelpItem :=
  if state.activePane == .detail then
    [ { key := "[Esc/Tab/w]", label := "calendar" } ]
  else
    [ { key := "[Tab/w]", label := "transactions" }
    , { key := "[Ctrl-u/d]", label := "scroll" }
    ]

/-- Summary of open Scheduled occurrences relative to today for Home indicators. -/
structure ScheduledSummary where
  overdueCount : Nat := 0
  nextDate : Option String := none
  nextIsToday : Bool := false

private def summarizeScheduled
    (today : String) (records : List Loam.ScheduledReview.Record) : ScheduledSummary :=
  let overdue := records.filter fun r => r.scheduledOn < today
  let upcoming := records.filter fun r => r.scheduledOn ≥ today
  let nextDate := upcoming.head?.map fun r => r.scheduledOn
  { overdueCount := overdue.length, nextDate, nextIsToday := nextDate == some today }

def scheduledSummary (snapshot : Snapshot) : ScheduledSummary :=
  match snapshot.scheduled with
  | .error _ => {}
  | .ok scheduled =>
      match Loam.ScheduledReview.orderedCurrentOpenRecords scheduled with
      | .error _ => {}
      | .ok records => summarizeScheduled snapshot.actual.today records

def scheduledBadge (width : Nat) (summary : ScheduledSummary) : String :=
  let overdueText :=
    if summary.overdueCount == 0 then ""
    else if width ≥ 100 then s!"! {summary.overdueCount} overdue"
    else s!"!{summary.overdueCount}"
  let upcomingText :=
    match summary.nextDate with
    | none => ""
    | some date =>
        if summary.nextIsToday then
          if width ≥ 100 then "today!" else "today"
        else
          let shortDate := if date.length ≥ 10 then (date.drop 5).toString else date
          if width ≥ 100 && summary.overdueCount == 0 then s!"next: {shortDate}"
          else shortDate
  if !overdueText.isEmpty && !upcomingText.isEmpty then
    s!" ({overdueText}, {upcomingText})"
  else if !overdueText.isEmpty then
    s!" ({overdueText})"
  else if !upcomingText.isEmpty then
    s!" ({upcomingText})"
  else ""

/-- Summary of open Attention items relative to today for Home indicators. -/
structure AttentionSummary where
  openCount : Nat := 0
  overdueCount : Nat := 0
  dueTodayCount : Nat := 0
  earliestDue : Option String := none

def attentionSummary (snapshot : Snapshot) : AttentionSummary :=
  match snapshot.attention with
  | .unavailable => {}
  | .available snap =>
      let today := snapshot.actual.today
      let items := snap.openItems
      let openCount := items.length
      let dueDates := items.filterMap fun item =>
        match item.due with
        | .dueOn date => some date
        | _ => none
      let sortedDue := dueDates.mergeSort (fun a b => a ≤ b)
      let overdueCount := (sortedDue.filter fun d => d < today).length
      let dueTodayCount := (sortedDue.filter fun d => d == today).length
      let upcomingDue := sortedDue.filter fun d => d > today
      let earliestDue := upcomingDue.head?
      { openCount, overdueCount, dueTodayCount, earliestDue }

def attentionBadge (width : Nat) (summary : AttentionSummary) : String :=
  if summary.openCount == 0 then ""
  else if summary.overdueCount > 0 then
    if width ≥ 100 then s!" (! {summary.overdueCount} overdue)"
    else s!" (!{summary.overdueCount})"
  else if summary.dueTodayCount > 0 then
    if width ≥ 100 then " (! due today)"
    else " (!today)"
  else if let some date := summary.earliestDue then
    let shortDate := if date.length ≥ 10 then (date.drop 5).toString else date
    if width ≥ 100 then s!" (due {shortDate})"
    else s!" (!1)"
  else
    if width ≥ 100 then s!" ({summary.openCount} open)"
    else s!" ({summary.openCount})"

private def actionHelp (width : Nat) (snapshot : Snapshot) (state : State) : List HelpItem :=
  let schedBadge := scheduledBadge width (scheduledSummary snapshot)
  [ { key := "[r]", label := "record" }
  , { key := "[a]", label := "actual" }
  , { key := "[s]", label := s!"scheduled{schedBadge}" }
  , { key := "[q]", label := if state.activePane == .detail then "back" else "home" }
  , { key := "[g]", label := "home" }
  ]

private def commandHelp (width : Nat) (snapshot : Snapshot) : List HelpItem :=
  let attnBadge := attentionBadge width (attentionSummary snapshot)
  [ { key := "[i]", label := s!"attention{attnBadge}" }
  , { key := "[d]", label := "daily pace" }
  , { key := "[b]", label := "balances" }
  , { key := "[Space]", label := "commands" }
  ]

private def fullHelpLines (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  if width < 79 then
    let (navigationLabel, navigation) := navigationHelp state
    let groups := [(navigationLabel, navigation), ("View", viewHelp state),
      ("Action", actionHelp width snapshot state), ("Commands", commandHelp width snapshot)]
    groups.flatMap fun (label, items) =>
      [mutedLine (" " ++ label)] ++
      (Loam.Tui.Layout.flowTokens (width - 1) "  " (items.map fun item => item.key ++ " " ++ item.label)).flatMap
        (fun line => wrappedLines width line)
  else
    let (navigationLabel, navigation) := navigationHelp state
    helpGroupLines width navigationLabel navigation ++
      helpGroupLines width "View" (viewHelp state) ++
      helpGroupLines width "Action" (actionHelp width snapshot state) ++
      helpGroupLines width "Commands" (commandHelp width snapshot)

private def helpEvidenceLines (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  fullHelpLines bounds snapshot state ++ [blankLine] ++
    ["PgUp/PgDn scroll complete Detail evidence; j/k resumes transaction selection.",
     "Calendar: Ctrl-u/d browses the month overview; moving date resumes date focus.",
     "underline = today; ! = past-date Scheduled still open; ? = unresolved role; … = amount too wide.",
     "Month/Year: brackets mark the selected period; underline marks the current month/year.",
     "Week: [day] selected; S# = evidenced current-open Scheduled; S+ = count too wide; S? = unavailable.",
     "A blank week marker is no evidenced open plan, not a completeness claim.",
     "Unknown Scheduled means completeness is not established. Flow is not a balance.",
     "Detail Effects show retained quanta and explicit Measure, independent of money presentation."].flatMap
      (fun line => wrappedLines width line)

/-- Two operation rows; the full grammar and legends remain in read-only help. -/
private def helpLines (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let isDetail := state.activePane == .detail
  let unit := match state.zoomLevel with | .day => "day" | .month => "month" | .year => "year"
  let enterLabel := if isDetail then "open" else
    match state.zoomLevel with | .day => "open" | .month => "days" | .year => "months"
  let navigation :=
    if width < 48 then
      if isDetail then [("j/k", "select"), ("Tab", "back"), ("?", "help")]
      else [("h/l", unit), ("Tab", "pane"), ("?", "help")]
    else if width < 79 then
      if isDetail then [("j/k", "select"), ("Enter", "open"), ("Tab", "back"), ("?", "help")]
      else [("h/l", unit), ("Enter", enterLabel), ("Tab", "pane"), ("?", "help")]
    else if isDetail then
      [("j/k", "select"), ("Enter", "open"), ("Esc/Tab/w", "calendar"), ("?", "help")]
    else
      let stride := match state.zoomLevel with | .day => "week" | .month => "quarter" | .year => "year"
      [("h/l", unit), ("k/j", stride), ("Enter", enterLabel), ("Tab/w", "pane"), ("?", "help")]
  let backLabel := if isDetail then "back" else "home"
  let actions :=
    if width < 79 then [("r", "rec"), ("Space", "cmds"), ("q", backLabel)]
    else [("r", "record"), ("Space", "commands"), ("q", backLabel),
      ("t", "today"), ("/", "jump"), ("z", "zoom")]
  [Loam.Tui.Layout.shortcutRow navigation " ", Loam.Tui.Layout.shortcutRow actions " "]

private def signalLines (bounds : Bounds) (snapshot : Snapshot) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let scheduled := match snapshot.scheduled with
    | .error _ => "s: unavailable"
    | .ok evidence => match Loam.ScheduledReview.orderedCurrentOpenRecords evidence with
      | .error _ => "s: unavailable"
      | .ok records =>
          let badge := scheduledBadge (min width 99) (summarizeScheduled snapshot.actual.today records)
          if badge.isEmpty then "" else "s" ++ badge
  let attention := attentionBadge (min width 99) (attentionSummary snapshot)
  let signals := (if scheduled.isEmpty then [] else [scheduled]) ++
    (if attention.isEmpty then [] else ["i" ++ attention])
  if signals.isEmpty then [blankLine]
  else (Loam.Tui.Layout.flowTokens (width - 1) "  " signals).flatMap fun line =>
    wrappedLines width line

private def homeFooter (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := if state.notice.isEmpty then signalLines bounds snapshot
    else wrappedLines width state.notice
  let help := if state.helpOpen then
      [Loam.Tui.Layout.shortcutRow [("j/k", "scroll"), ("C-u/d", "page")] " ",
       Loam.Tui.Layout.shortcutRow [("?", "close"), ("Esc/q", "back")] " "]
    else helpLines bounds state
  let operations := match state.jumpPrompt with
    | none => help
    | some buffer =>
        let caption := if width < 50 then "Jump: " else "Jump to date / month / year: "
        let prompt :=
          [.row [span caption .muted,
            Loam.Tui.Layout.inputSpan (width - Loam.Tui.Layout.displayWidth caption) true buffer],
           Loam.Tui.Layout.shortcutRow [("Enter", "jump"), ("Esc", "cancel")]] ++
          wrappedLines width "e.g. 2026-10-15, 2026-10, 2026, 15" .muted
        prompt ++ List.replicate (help.length - prompt.length) blankLine
  let rows := feedback ++ operations
  Loam.Tui.Layout.boundFeedbackFooter bounds rows

/-- Scroll non-selectable detail evidence when there are no Actual rows. -/
private def scrollDetail
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (forward : Bool) (step : Nat)
    (layout : DetailLayout) : State :=
  let state := { state with notice := "" }
  let footerRows := (homeFooter bounds snapshot state).length
  let panelRows := widePanelRows bounds footerRows
  let visible := match stackedDayHeights bounds footerRows state layout with
    | some (_, detailHeight) => detailVisibleRows detailHeight
    | none => detailVisibleRows panelRows
  let content := layout.rows.size
  let current := Loam.Tui.Scroll.clamp content visible state.detailScroll
  let step := min step (max 1 visible)
  let next :=
    if forward then Loam.Tui.Scroll.forward content visible current step
    else Loam.Tui.Scroll.backward content visible current step
  { state with detailScroll := next, detailManualScroll := true }

/-- Scroll the calendar, including overflow in short terminals. -/
private def scrollOverview
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (forward : Bool)
    (layout : DetailLayout) : State :=
  let state := { state with notice := "" }
  let footerRows := (homeFooter bounds snapshot state).length
  let stacked := stackedDayHeights bounds footerRows state layout
  let compactDay := bounds.width < 120
  let rows := layout.overviewRows
  let visible := match stacked with
    | some (calendarHeight, _) => detailVisibleRows calendarHeight
    | none => detailVisibleRows (widePanelRows bounds footerRows)
  let current := overviewOffset visible rows state compactDay
  -- Short viewports must not skip rows between successive overview pages.
  let step := min 5 (max 1 visible)
  let next :=
    if forward then Loam.Tui.Scroll.forward rows.length visible current step
    else Loam.Tui.Scroll.backward rows.length visible current step
  { state with overviewScroll := next, overviewManualScroll := true }

/-- Move detail cursor and scroll viewport so the selected record is visible. -/
def moveDetailCursor
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (offset : Int)
    (cached : Option DetailLayout := none) : State :=
  let layout := detailLayoutFor bounds snapshot state cached
  let nextCursor := max 0 (min ((layout.records.size - 1 : Nat) : Int)
    ((state.detailCursor : Int) + offset))
  let nextState := {state with detailCursor := nextCursor.toNat, detailManualScroll := false}
  if layout.records.isEmpty then nextState
  else
    let footerRows := (homeFooter bounds snapshot nextState).length
    let panelRows := widePanelRows bounds footerRows
    let visible := match stackedDayHeights bounds footerRows nextState layout with
      | some (_, detailHeight) => detailVisibleRows detailHeight
      | none => detailVisibleRows panelRows
    let idx := nextState.detailCursor
    match layout.starts[idx]?, layout.counts[idx]? with
    | some recStart, some count =>
        let recEnd := recStart + count
        let content := layout.rows.size
        let currentScroll := Loam.Tui.Scroll.clamp content visible nextState.detailScroll
        let adjustedScroll :=
          if recStart < currentScroll || recEnd - recStart > visible then
            recStart
          else if recEnd > currentScroll + visible then
            recEnd - visible
          else currentScroll
        let finalScroll := Loam.Tui.Scroll.clamp content visible adjustedScroll
        { nextState with detailScroll := finalScroll }
    | _, _ => nextState

/-- Reconcile reloads and geometry without changing any household evidence. -/
def reconcileState (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (cached : Option DetailLayout := none) : State :=
  if state.helpOpen || state.launcherOpen then state
  else
    let layout := detailLayoutFor bounds snapshot state cached
    let state := {state with detailCursor := min state.detailCursor (layout.records.size - 1)}
    if state.detailManualScroll || layout.records.isEmpty then
      let footerRows := (homeFooter bounds snapshot state).length
      let panelRows := widePanelRows bounds footerRows
      let visible := match stackedDayHeights bounds footerRows state layout with
        | some (_, detailHeight) => detailVisibleRows detailHeight
        | none => detailVisibleRows panelRows
      {state with detailScroll := Loam.Tui.Scroll.clamp layout.rows.size visible state.detailScroll}
    else moveDetailCursor bounds snapshot state 0 (some layout)

private def repeatUpdate (state : State) (event : Loam.Tui.Main.Event) (repeatCount : Nat) : State :=
  let rec loop (st : State) (rem : Nat) : State :=
    match rem with
    | 0 => st
    | rem + 1 => loop (update st event).state rem
  loop state repeatCount

/-- Pure local navigation. `none` delegates a workspace entrance to the IO shell. -/
def navigationKey
    (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (key : Loam.Tui.Terminal.Key) (repeatCount : Nat := 1)
    (cached : Option DetailLayout := none) : Option State :=
  if state.launcherOpen then
    match key with
    | .enter | .input 'g' | .input 'G' => some {state with launcherOpen := false, notice := ""}
    | .input 'r' | .input 'R' | .input 's' | .input 'S'
    | .input 'a' | .input 'A' | .input 'b' | .input 'B'
    | .input 'd' | .input 'D' | .input 'i' | .input 'I'
    | .input ' ' | .input 'q' | .input 'Q' => none
    | _ => some state
  else if !state.helpOpen && state.jumpPrompt.isNone &&
      ((state.activePane == .calendar && (key == .escape || key == .input 'q' || key == .input 'Q')) ||
        key == .input 'g' || key == .input 'G') then
    some {state with launcherOpen := true, notice := ""}
  else if state.helpOpen then
    let rows := helpEvidenceLines {bounds with width := bounds.width - 2} snapshot state
    let footerRows := (homeFooter bounds snapshot state).length
    let visible := detailVisibleRows (widePanelRows bounds footerRows)
    let current := Loam.Tui.Scroll.clamp rows.length visible state.helpScroll
    let page := max 1 visible
    some <| match key with
    | .escape | .input '?' | .input 'q' | .input 'Q' => {state with helpOpen := false}
    | .up | .input 'k' => {state with helpScroll := Loam.Tui.Scroll.backward rows.length visible current repeatCount}
    | .down | .input 'j' => {state with helpScroll := Loam.Tui.Scroll.forward rows.length visible current repeatCount}
    | .ctrl 'u' | .pageUp => {state with helpScroll := Loam.Tui.Scroll.backward rows.length visible current page}
    | .ctrl 'd' | .pageDown => {state with helpScroll := Loam.Tui.Scroll.forward rows.length visible current page}
    | .home => {state with helpScroll := 0}
    | .«end» => {state with helpScroll := rows.length - visible}
    | _ => state
  else
    let prepared := detailLayoutFor bounds snapshot state cached
    let layout := some prepared
    let state := reconcileState bounds snapshot state layout
    let handled := fun next => some (reconcileState bounds snapshot next layout)
    if state.jumpPrompt.isSome then
      handled <| match key with
      | .escape => closeJumpPrompt state
      | .backspace | .delete => backspaceJump state
      | .enter => executeJump state
      | .input char =>
          if char.isDigit || char == '-' || char == '/' then appendJumpChar state char else state
      | .paste text =>
          let clean := Loam.Tui.Terminal.singleLinePaste text
          let valid := clean.toList.filter fun c => c.isDigit || c == '-' || c == '/'
          valid.foldl appendJumpChar state
      | _ => state
    else
      match key with
      | .input '?' => some {state with helpOpen := true, helpScroll := 0}
      | .input '/' => handled (openJumpPrompt state)
      | .input 'z' | .input 'Z' => handled (cycleZoomLevel state)
      | .tab | .input 'w' | .input 'W' => handled (toggleActivePane state)
      | .input 't' | .input 'T' =>
          handled { state with
            selectedDate := snapshot.actual.today
            notice := ""
            detailCursor := 0
            detailScroll := 0
            detailManualScroll := false
            overviewScroll := 0
            overviewManualScroll := false
            activePane := .calendar
          }
      | .pageUp | .pageDown =>
          let forward := key == .pageDown
          if state.activePane == .calendar then handled (scrollOverview bounds snapshot state forward prepared)
          else
            let footerRows := (homeFooter bounds snapshot state).length
            let height := match stackedDayHeights bounds footerRows state prepared with
              | some (_, detailHeight) => detailHeight
              | none => widePanelRows bounds footerRows
            some (scrollDetail bounds snapshot state forward (max 1 (detailVisibleRows height)) prepared)
      | .ctrl 'u' | .ctrl 'd' =>
          let forward := key == .ctrl 'd'
          if state.activePane == .calendar then
            handled (scrollOverview bounds snapshot state forward prepared)
          else if prepared.records.isEmpty then
            some (scrollDetail bounds snapshot state forward 5 prepared)
          else handled (moveDetailCursor bounds snapshot { state with notice := "" } (if forward then 5 else -5) layout)
      | .home =>
          if state.activePane == .detail then
            handled (moveDetailCursor bounds snapshot { state with notice := "" } (-10000) layout)
          else
            handled { state with
              selectedDate := snapshot.actual.today
              notice := ""
              detailCursor := 0
              detailScroll := 0
              detailManualScroll := false
              overviewScroll := 0
              overviewManualScroll := false
            }
      | .«end» =>
          if state.activePane == .detail then
            handled (moveDetailCursor bounds snapshot { state with notice := "" } 10000 layout)
          else handled state
      | .escape | .enter =>
          if state.activePane == .detail then
            if key == .escape then handled (focusCalendar state) else none
          else
            match state.zoomLevel with
            | .year => handled (setZoomLevel state .month)
            | .month => handled (setZoomLevel state .day)
            | .day => if key == .escape then handled state else none
      | .input 'q' | .input 'Q' =>
          if state.activePane == .detail then handled (focusCalendar state) else none
      | .input 'h' | .input 'H' | .left =>
          handled (if state.activePane == .detail then state else (update state .left).state)
      | .input 'l' | .input 'L' | .right =>
          handled (if state.activePane == .detail then state else (update state .right).state)
      | .input 'j' | .input 'J' | .down =>
          let delta : Int := repeatCount
          handled (if state.activePane == .detail then moveDetailCursor bounds snapshot state delta layout else repeatUpdate state .down repeatCount)
      | .input 'k' | .input 'K' | .up =>
          let delta : Int := - (repeatCount : Int)
          handled (if state.activePane == .detail then moveDetailCursor bounds snapshot state delta layout else repeatUpdate state .up repeatCount)
      | _ => none

/--
Production Home presentation over LOAM's already-admitted read answers.
This is presentation only: it adds no household authority, cycle policy,
Scheduled completeness claim, or retained pending status.
-/
def homeView (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (cached : Option DetailLayout := none) : Widget :=
  let layout := detailLayoutFor bounds snapshot state cached
  let state := if state.helpOpen then state else reconcileState bounds snapshot state (some layout)
  let footer := homeFooter bounds snapshot state
  let body := if state.helpOpen then
      let width := Loam.Tui.Layout.contentWidth bounds
      let height := widePanelRows bounds footer.length
      let rows := helpEvidenceLines {bounds with width := bounds.width - 2} snapshot state
      let visible := detailVisibleRows height
      let offset := Loam.Tui.Scroll.clamp rows.length visible state.helpScroll
      let content := .column ((rows.drop offset).take visible)
      let panel := if height < 3 then content else
        Loam.Tui.Layout.framedPanel width height "Home / Help" content true
          (some (viewportLabel rows.length visible offset))
      homeContext bounds snapshot state ++ Loam.Tui.Layout.widgetRows panel
    else homeBody bounds footer.length snapshot state layout
  .column ((Loam.Tui.Layout.fitWithFooter bounds body footer).map fun row =>
    Loam.Tui.Layout.clipWidgetRow (Loam.Tui.Layout.contentWidth bounds) row)

/-- Production root rendering is Home-only; object workspaces run in their own sessions. -/
def view (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (cached : Option DetailLayout := none) : Widget :=
  if state.launcherOpen then
    Loam.Tui.HomeLauncher.view bounds state.selectedDate state.notice
      (Loam.Tui.HomeLauncher.growthStage snapshot.actual.allRecords)
  else homeView bounds snapshot state cached

end Loam.Tui.Home
