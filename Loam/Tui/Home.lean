import Loam.Tui.DateJump
import Loam.Tui.Layout
import Loam.Tui.Main
import Loam.Tui.Scroll
import Loam.Tui.Terminal

namespace Loam.Tui.Home

open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def fitText (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text ≤ width then
    Loam.Tui.Layout.padRight width text
  else
    Loam.Tui.Layout.padRight width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

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

private def moneyCellWidth (paneWidth : Nat) : Nat :=
  (paneWidth - 8) / 7

private def moneyGridWidth (paneWidth : Nat) : Nat :=
  8 + 7 * moneyCellWidth paneWidth

private def moneyRule
    (paneWidth : Nat) (left middle right : Char) : Widget :=
  let cellWidth := moneyCellWidth paneWidth
  let segment := repeatChar cellWidth '─'
  mutedLine <|
    String.ofList [left] ++
      String.intercalate (String.ofList [middle]) (List.replicate 7 segment) ++
      String.ofList [right]

private def moneyGridSpans : List Span → List Span
  | [] => [span "│" .muted]
  | cell :: rest => span "│" .muted :: cell :: moneyGridSpans rest

private def moneyGridRow (cells : List Span) : Widget :=
  .row (moneyGridSpans cells)

private def moneyCalendarHeader (paneWidth : Nat) : Widget :=
  let cellWidth := moneyCellWidth paneWidth
  moneyGridRow <|
    ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map fun label =>
      span (Loam.Tui.Layout.padRight cellWidth (" " ++ label)) .muted

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
    (today : String) (state : State) (date : String) : Style :=
  if date == state.selectedDate then
    if date == today then .selectedUnderlined else .selected
  else if date == today then
    .underlined
  else
    .normal

/-- One shared calendar day cell; focus, Today, overdue Scheduled and role unknown
markers all compose in this larger money calendar. -/
def moneyDateSpan
    (paneWidth : Nat) (today : String) (pastOpenDates : List String)
    (snapshot : Snapshot) (state : State) (date : String) : Span :=
  let cellWidth := moneyCellWidth paneWidth
  let pending := pastOpenDates.any fun candidate => candidate == date
  let unresolved :=
    match moneyRowFor? snapshot state date with
    | some row => decide (0 < row.unresolvedEffectCount)
    | none => false
  let markers := (if pending then "!" else "") ++ (if unresolved then "?" else "")
  let text := " " ++ shortDay date ++ markers
  span (Loam.Tui.Layout.padRight cellWidth text)
    (moneyCellStyle today state date)

private def groupedQuantaText
    (money : MoneyCalendarSnapshot)
    (measure : Loam.Core.MeasureId)
    (quanta : Int) : String :=
  Loam.MeasurePresentation.formatGroupedAmount money.presentation measure quanta

private def moneyMonthSummaryText
    (snapshot : Snapshot) (state : State) : String :=
  match moneyMeasureInfo snapshot state with
  | none => ""
  | some (_, []) => ""
  | some (money, measure :: _) =>
      let window := moneyWindow state
      let summary := money.flow.summaryForWindow window.1 window.2 measure
      let plusText := "+" ++ groupedQuantaText money measure summary.plus.quanta
      let minusText := "-" ++ groupedQuantaText money measure summary.minus.quanta
      let net := summary.plus.quanta - summary.minus.quanta
      let netText :=
        if net > 0 then "+" ++ groupedQuantaText money measure net
        else groupedQuantaText money measure net
      plusText ++ "   " ++ minusText ++ "   = " ++ netText ++
        (if summary.unresolvedEffectCount = 0 then "" else "  ?")

private def moneyAmountSpan
    (paneWidth : Nat)
    (snapshot : Snapshot) (state : State)
    (date : String) (positive : Bool) : Span :=
  let cellWidth := moneyCellWidth paneWidth
  let text :=
    match moneyRowFor? snapshot state date, moneyMeasureInfo snapshot state with
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
    (if date == state.selectedDate then .selected else .normal)

private def blankMoneyCell (paneWidth : Nat) : Span :=
  span (repeatChar (moneyCellWidth paneWidth) ' ')

private def moneyCalendarRows
    (paneWidth : Nat) (today : String) (pastOpenDates : List String)
    (snapshot : Snapshot) (state : State) : List Widget :=
  (List.range 6).flatMap fun row =>
    let dates := (List.range 7).map fun col => calendarSlot state row col
    let dateLine := moneyGridRow <| dates.map fun slot =>
      match slot with
      | none => blankMoneyCell paneWidth
      | some date => moneyDateSpan paneWidth today pastOpenDates snapshot state date
    let plusLine := moneyGridRow <| dates.map fun slot =>
      match slot with
      | none => blankMoneyCell paneWidth
      | some date => moneyAmountSpan paneWidth snapshot state date true
    let minusLine := moneyGridRow <| dates.map fun slot =>
      match slot with
      | none => blankMoneyCell paneWidth
      | some date => moneyAmountSpan paneWidth snapshot state date false
    [ dateLine
    , plusLine
    , minusLine
    , if row = 5 then
        moneyRule paneWidth '└' '┴' '┘'
      else
        moneyRule paneWidth '├' '┼' '┤'
    ]

private def moneyCalendarBlock
    (paneWidth : Nat) (snapshot : Snapshot) (state : State)
    (pastOpenDates : List String) : List Widget :=
  let gridWidth := moneyGridWidth paneWidth
  let title := moneyTitle snapshot state
  let title := if Loam.Tui.Layout.displayWidth title ≤ gridWidth then title
    else Loam.Tui.Layout.clip (gridWidth - 1) title ++ "…"
  [ plainLine (centeredText gridWidth title)
  , moneyRule paneWidth '┌' '┬' '┐'
  , moneyCalendarHeader paneWidth
  , moneyRule paneWidth '├' '┼' '┤'
  ] ++
  moneyCalendarRows paneWidth snapshot.actual.today pastOpenDates snapshot state ++
  (let summary := moneyMonthSummaryText snapshot state
   if summary.isEmpty then []
   else wrappedLines paneWidth summary) ++
  wrappedLines paneWidth "underline = today; ! = Scheduled still open; ? = unresolved role; … = amount too wide" .muted ++
  (match snapshot.moneyCalendar with
   | .failed message => wrappedLines paneWidth message .muted
   | _ => [])

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
  | .error message => wrappedLines width ("[Unavailable] " ++ message)
  | .ok (.due first rest) =>
      (first :: rest).flatMap fun record =>
        wrappedLines width
          ("Scheduled: " ++ record.scheduledOn ++ "  [Open]  " ++ Loam.ScheduledReview.summary record) ++
        record.movement.changes.flatMap fun change =>
          effectLines width change.coordinate.token record.measure change.quantity.quanta
  | .ok .unknown => wrappedLines width "(unknown; no completeness horizon is claimed)" .muted

private def pendingLines (width : Nat) : PendingEvidence → List Widget
  | .error message => wrappedLines width ("[Unavailable] " ++ message)
  | .ok [] => wrappedLines width "(none; no past-date current-open Scheduled occurrence)" .muted
  | .ok records => records.flatMap fun record =>
      wrappedLines width
        (record.scheduledOn ++ "  [Still open]  " ++ Loam.ScheduledReview.summary record)

private def statusTokens
    (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : List String :=
  match state.zoomLevel with
  | .day =>
      let scheduled :=
        match homeScheduledEvidence snapshot state with
        | .error _ => "Unavailable"
        | .ok (.due _ rest) => "Due (" ++ toString (rest.length + 1) ++ ")"
        | .ok .unknown => "Unknown"
      let pendingStatus :=
        match pending with
        | .ok records => toString records.length
        | .error _ => "Unavailable"
      ["Scheduled: " ++ scheduled, "Pending: " ++ pendingStatus]
  | .month =>
      let m := selectedMonth state
      let count := (recordsForMonth snapshot m.year m.month).length
      [s!"Transactions: {count}"]
  | .year =>
      let y := (selectedMonth state).year
      let count := (recordsForYear snapshot y).length
      [s!"Transactions: {count}"]

private def pendingSection (width : Nat) (pending : PendingEvidence) : List Widget :=
  match pending with
  | .ok [] => []
  | _ => [mutedLine " Pending Scheduled:"] ++ pendingLines width pending ++ [blankLine]

private def monthNames : List String :=
  ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

private def centeredYearTitle (year : Nat) : String :=
  let title := s!"Year {year}"
  let width := Loam.Tui.Layout.displayWidth title
  let padding := if width < 35 then (35 - width) / 2 else 0
  repeatChar padding ' ' ++ title

private def monthCellSpans
    (today : String) (state : State) (snapshot : Snapshot) (year month : Nat) : List Span :=
  let mName := monthNames.getD (month - 1) (toString month)
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
    else
      if isTodayMonth then .underlined else .normal
  let label := if isSelected then "[" ++ mName ++ "]" else " " ++ mName ++ " "
  let countText := if count == 0 then "  -   " else Loam.Tui.Layout.padRight 6 (toString count ++ "t")
  [ span label nameStyle
  , span (" " ++ countText) .muted
  , span "  "
  ]

private def monthQuarterRow
    (today : String) (state : State) (snapshot : Snapshot) (year startMonth : Nat) : Widget :=
  let spans := (List.range 3).flatMap fun col =>
    monthCellSpans today state snapshot year (startMonth + col)
  .row (span " " :: spans)

private def monthCalendarPane
    (snapshot : Snapshot) (state : State) : List Widget :=
  let year := (selectedMonth state).year
  let today := snapshot.actual.today
  [ plainLine (centeredYearTitle year)
  , blankLine
  , monthQuarterRow today state snapshot year 1
  , blankLine
  , monthQuarterRow today state snapshot year 4
  , blankLine
  , monthQuarterRow today state snapshot year 7
  , blankLine
  , monthQuarterRow today state snapshot year 10
  , blankLine
  , mutedLine " underline = current month"
  , blankLine
  ]

private def yearOverviewPane
    (snapshot : Snapshot) (state : State) : List Widget :=
  let curYear := (selectedMonth state).year
  let today := snapshot.actual.today
  let startYear := if curYear < 2 then 1 else curYear - 2
  let years := List.range 5 |>.map fun i => startYear + i
  let rows := years.map fun y =>
    let count := (recordsForYear snapshot y).length
    let isSelected := (selectedMonth state).year == y
    let isTodayYear :=
      match Loam.Tui.Calendar.monthOf? today with
      | some tm => tm.year == y
      | none => false
    let style :=
      if isSelected then
        if isTodayYear then .selectedUnderlined else .selected
      else
        if isTodayYear then .underlined else .normal
    let label := if isSelected then "[" ++ toString y ++ "]" else " " ++ toString y ++ " "
    let countText := if count == 0 then "no transactions" else (toString count ++ " transactions")
    .row
      [ span "   "
      , span label style
      , span ("     " ++ countText) .muted
      ]
  [ plainLine "           Years Overview"
  , blankLine
  ] ++ rows ++
  [ blankLine
  , mutedLine " underline = current year"
  , blankLine
  ]

/-- One period summary for both layouts. Measures and read states remain distinct. -/
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
    | .notRequested => [mutedLine "   flow not requested"]
    | .unavailable => [mutedLine "   flow unavailable"]
    | .failed message =>
        [plainLine "   flow read failed"] ++
        wrappedLines width message .muted
    | .loaded money =>
        let measures := money.flow.measuresInWindow window.1 window.2
        if measures.isEmpty then
          [mutedLine "   No recorded income/expense flow."]
        else
          measures.flatMap fun measure =>
            let summary := money.flow.summaryForWindow window.1 window.2 measure
            let format := groupedQuantaText money measure
            let net := summary.plus.quanta - summary.minus.quanta
            let netText := (if net > 0 then "+" else "") ++ format net
            let divisor := if isYear then some 12 else Loam.Tui.Calendar.daysInMonth? m
            [plainLine (" " ++ measure.token ++
              (if summary.unresolvedEffectCount == 0 then "" else " [partial]"))] ++
            (if summary.unresolvedEffectCount == 0 then [] else
              tokens [s!"? {summary.unresolvedEffectCount} unresolved effects"]) ++
            tokens ["In: +" ++ format summary.plus.quanta, "Out: -" ++ format summary.minus.quanta] ++
            tokens ["Net: " ++ netText] ++
            (match divisor with
             | some days =>
                 let avg := format (summary.minus.quanta / (days : Int))
                 let unit := if isYear then "month" else "day"
                 tokens [s!"Out/{unit}: ~{avg}", if isYear then "(full year)" else "(full month)"]
             | none => [])
  [ plainLine (" " ++ label)
  , mutedLine s!" {(homeActualRecords snapshot state).length} transactions recorded"
  ] ++ flowLines

private def wideCalendarPane
    (paneWidth : Nat)
    (snapshot : Snapshot) (state : State) (pastOpenDates : List String) : List Widget :=
  match state.zoomLevel with
  | .day =>
      moneyCalendarBlock paneWidth snapshot state pastOpenDates
  | .month =>
      monthCalendarPane snapshot state ++ periodSummaryLines paneWidth snapshot state
  | .year =>
      yearOverviewPane snapshot state ++ periodSummaryLines paneWidth snapshot state

private def wideDetailLines
    (width : Nat) (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : List Widget :=
  match state.zoomLevel with
  | .day =>
      pendingSection width pending ++ [mutedLine " Actual"] ++ actualLines width snapshot state ++
      [blankLine, mutedLine " Scheduled"] ++ scheduledLines width snapshot state
  | .month | .year =>
      [mutedLine " Actual Transactions"] ++ actualLines width snapshot state

-- Two borders, a status row and a blank separator. Shared by rendering and navigation.
private def wideDetailVisibleRows (panelRows : Nat) : Nat := panelRows - 4

private def widePanelRows (bounds : Bounds) (footerRows : Nat) : Nat :=
  Loam.Tui.Layout.footerBodyCapacity bounds footerRows - 2

private def detailPaneWidth (bounds : Bounds) (state : State) : Nat :=
  min 72 (max (if state.zoomLevel == .day then 50 else 64)
    (Loam.Tui.Layout.contentWidth bounds * 36 / 100))

private def detailInnerWidth (bounds : Bounds) (state : State) : Nat :=
  (if bounds.width ≥ 120 then detailPaneWidth bounds state
   else Loam.Tui.Layout.contentWidth bounds) - 2

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
    (width height : Nat) (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : Widget :=
  let details := wideDetailLines (width - 2) snapshot state pending
  let visible := wideDetailVisibleRows height
  let offset := Loam.Tui.Scroll.clamp details.length visible state.detailScroll
  let focused := state.activePane == .detail
  let status := String.intercalate "  " (statusTokens snapshot state pending)
  let content := [mutedLine (fitText (width - 2) (" " ++ status)), blankLine] ++
    (details.drop offset).take visible
  let title := selectedPeriod state ++ " / Detail" ++ (if focused then " [active]" else "")
  Loam.Tui.Layout.framedPanel width height title (.column content) focused
    (some (viewportLabel details.length visible offset))

private def homeContext (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  [ Widget.row [span " LOAM Home" .normal, span (if width ≥ 80 then " / Calendar   known through " else "  known through ") .muted, span snapshot.actual.today]
  , Widget.row [span " Focus: " .muted, span state.selectedDate,
      span "   View: " .muted, span (Loam.Tui.DateJump.zoomLabel state.zoomLevel)]
  ].map fun row => .row ((Loam.Tui.Layout.clipCells width row.lines.flatten).map fun cell =>
    span (String.singleton cell.glyph) cell.style)

private def calendarRows
    (width : Nat) (snapshot : Snapshot) (state : State) (includeDetails : Bool) : List Widget :=
  let pending := pendingEvidence snapshot
  wideCalendarPane width snapshot state (pendingDates pending) ++
    (if includeDetails then
      [blankLine, mutedLine (" " ++ selectedPeriod state)] ++
      wrappedLines width (String.intercalate "  " (statusTokens snapshot state pending)) .muted ++
      wideDetailLines width snapshot state pending
     else [])

/-- Follow the selected calendar cell, but never undo explicit overview browsing. -/
private def overviewOffset (visible : Nat) (rows : List Widget) (state : State) : Nat :=
  let offset := if state.overviewManualScroll then state.overviewScroll else
    match rows.zipIdx.find? (fun (row, _) => row.lines.flatten.any fun cell =>
        cell.style == .selected || cell.style == .selectedUnderlined) with
    | none => state.overviewScroll
    | some (_, index) =>
        let focusRows := if state.zoomLevel == .day then min 3 visible else min 1 visible
        index + focusRows - visible
  Loam.Tui.Scroll.clamp rows.length visible offset

/-- Overflow is in the border rather than consuming or moving a content row. -/
private def calendarPanel
    (width height : Nat) (snapshot : Snapshot) (state : State) (includeDetails : Bool) : Widget :=
  let rows := calendarRows (width - 2) snapshot state includeDetails
  let visible := height - 2
  let offset := overviewOffset visible rows state
  let focused := state.activePane == .calendar
  Loam.Tui.Layout.framedPanel width height
    ("Calendar" ++ (if focused then " [active]" else ""))
    (.column ((rows.drop offset).take visible)) focused
    (some (viewportLabel rows.length visible offset))

private def homeBody
    (bounds : Bounds) (footerRows : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let height := widePanelRows bounds footerRows
  let context := homeContext bounds snapshot state
  if bounds.width ≥ 120 then
    let rightWidth := detailPaneWidth bounds state
    let leftWidth := width - 1 - rightWidth
    let left := calendarPanel leftWidth height snapshot state false
    let right := detailPanel rightWidth height snapshot state (pendingEvidence snapshot)
    context ++ Loam.Tui.Layout.sideBySide height leftWidth rightWidth left right " "
  else
    let panel := if state.activePane == .detail then
        detailPanel width height snapshot state (pendingEvidence snapshot)
      else calendarPanel width height snapshot state true
    context ++ panel.lines.map fun cells =>
      .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)

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

private def actionHelp (state : State) : List HelpItem :=
  if state.activePane == .detail then
    [{ key := "[q]", label := "quit" }]
  else
    [ { key := "[r]", label := "record" }
    , { key := "[a]", label := "actual" }
    , { key := "[s]", label := "scheduled" }
    , { key := "[q]", label := "quit" }
    ]

private def commandHelp : List HelpItem :=
  [ { key := "[i]", label := "attention" }
  , { key := "[d]", label := "daily pace" }
  , { key := "[b]", label := "balances" }
  , { key := "[Space]", label := "commands" }
  ]

private def helpLines (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  if width < 79 then
    let navigation := if state.activePane == .detail then
        [("j/k", "select"), ("Enter", "open"), ("C-u/d", "page")]
      else match state.zoomLevel with
        | .day => [("h/l", "day"), ("k/j", "week"), ("Enter", "open")]
        | .month => [("h/l", "month"), ("k/j", "quarter"), ("Enter", "days")]
        | .year => [("h/l/k/j", "year"), ("Enter", "months")]
    let view := if state.activePane == .detail then
        [("Esc/Tab/w", "calendar"), ("t", "today")]
      else [("Tab/w", "pane"), ("C-u/d", "scroll"), ("/", "jump"), ("z", "zoom")]
    [ Loam.Tui.Layout.shortcutRow navigation " "
    , Loam.Tui.Layout.shortcutRow view " "
    , Loam.Tui.Layout.shortcutRow [("r", "rec"), ("a", "actual"), ("s", "plans"), ("q", "quit")] " "
    , Loam.Tui.Layout.shortcutRow [("i", "attn"), ("d", "pace"), ("b", "bal"), ("Space", "cmds")] " "
    ]
  else
    let (navigationLabel, navigation) := navigationHelp state
    helpGroupLines width navigationLabel navigation ++
      helpGroupLines width "View" (viewHelp state) ++
      helpGroupLines width "Action" (actionHelp state) ++
      helpGroupLines width "Commands" commandHelp

/-- Wide Home shows both panes; narrow Home gives focused transactions the full body. -/
def usesWideLayout (bounds : Bounds) : Bool :=
  decide (120 ≤ bounds.width)

private def homeFooter (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := if state.notice.isEmpty then [blankLine]
    else wrappedLines width state.notice .muted
  let help := helpLines bounds state
  let operations := match state.jumpPrompt with
    | none => help
    | some buffer =>
        let prompt := wrappedLines width ("Jump to date / month / year: " ++ buffer ++ "█") ++
          [Loam.Tui.Layout.shortcutRow [("Enter", "jump"), ("Esc", "cancel")]] ++
          wrappedLines width "e.g. 2026-10-15, 2026-10, 2026, 15" .muted
        prompt ++ List.replicate (help.length - prompt.length) blankLine
  let rows := feedback ++ operations
  let capacity := bounds.height - 1
  if rows.length ≤ capacity then rows
  else if capacity == 0 then []
  else rows.take (capacity - 1) ++ [mutedLine " … more feedback/help; enlarge terminal"]

/-- Scroll non-selectable detail evidence when there are no Actual rows. -/
private def scrollDetail
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (forward : Bool) (step : Nat) : State :=
  let state := { state with notice := "" }
  let footerRows := (homeFooter bounds state).length
  let panelRows := widePanelRows bounds footerRows
  let visible := wideDetailVisibleRows panelRows
  let pending := pendingEvidence snapshot
  let content := (wideDetailLines (detailInnerWidth bounds state) snapshot state pending).length
  let current := Loam.Tui.Scroll.clamp content visible state.detailScroll
  let next :=
    if forward then Loam.Tui.Scroll.forward content visible current step
    else Loam.Tui.Scroll.backward content visible current step
  { state with detailScroll := next }

/-- Scroll the calendar, including overflow in short terminals. -/
private def scrollOverview
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (forward : Bool) : State :=
  let state := { state with notice := "" }
  let footerRows := (homeFooter bounds state).length
  let width := if usesWideLayout bounds then
      Loam.Tui.Layout.contentWidth bounds - 1 - detailPaneWidth bounds state - 2
    else Loam.Tui.Layout.contentWidth bounds - 2
  let rows := calendarRows width snapshot state (!usesWideLayout bounds)
  let visible := widePanelRows bounds footerRows - 2
  let current := overviewOffset visible rows state
  let next :=
    if forward then Loam.Tui.Scroll.forward rows.length visible current 5
    else Loam.Tui.Scroll.backward rows.length visible current 5
  { state with overviewScroll := next, overviewManualScroll := true }

/-- Move detail cursor and scroll viewport so the selected record is visible. -/
def moveDetailCursor
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (offset : Int) : State :=
  let nextState := Loam.Tui.Main.moveDetailCursor snapshot state offset
  let records := (homeActualRecords snapshot nextState).reverse
  if records.isEmpty then nextState
  else
    let footerRows := (homeFooter bounds nextState).length
    let panelRows := widePanelRows bounds footerRows
    let visible := wideDetailVisibleRows panelRows
    let pending := pendingEvidence snapshot
    let width := detailInnerWidth bounds nextState
    let actualHeaderRows :=
      match nextState.zoomLevel with
      | .day => (pendingSection width pending).length + 1
      | .month | .year => 1
    let idx := nextState.detailCursor
    match records[idx]? with
    | none => nextState
    | some currentRec =>
        let recordRows := fun record =>
          (actualRecordLines width false nextState record).length
        let prevRows := (records.take idx).foldl (fun acc r => acc + recordRows r) 0
        let recStart := actualHeaderRows + prevRows
        let recEnd := recStart + recordRows currentRec
        let content := (wideDetailLines width snapshot nextState pending).length
        let currentScroll := Loam.Tui.Scroll.clamp content visible nextState.detailScroll
        let adjustedScroll :=
          if recStart < currentScroll || recEnd - recStart > visible then
            recStart
          else if recEnd > currentScroll + visible then
            recEnd - visible
          else currentScroll
        let finalScroll := Loam.Tui.Scroll.clamp content visible adjustedScroll
        { nextState with detailScroll := finalScroll }

/-- Reconcile reloads and geometry without changing any household evidence. -/
def reconcileState (bounds : Bounds) (snapshot : Snapshot) (state : State) : State :=
  let state := normalizeDetailCursor snapshot state
  if state.activePane == .detail then moveDetailCursor bounds snapshot state 0 else state

private def repeatUpdate (state : State) (event : Loam.Tui.Main.Event) (repeatCount : Nat) : State :=
  let rec loop (st : State) (rem : Nat) : State :=
    match rem with
    | 0 => st
    | rem + 1 => loop (update st event).state rem
  loop state repeatCount

/-- Pure local navigation. `none` delegates a workspace entrance to the IO shell. -/
def navigationKey
    (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (key : Loam.Tui.Terminal.Key) (repeatCount : Nat := 1) : Option State :=
  let state := reconcileState bounds snapshot state
  let handled := fun next => some (reconcileState bounds snapshot next)
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
    | .input '/' => handled (openJumpPrompt state)
    | .input 'z' | .input 'Z' => handled (cycleZoomLevel state)
    | .tab | .input 'w' | .input 'W' => handled (toggleActivePane state)
    | .input 't' | .input 'T' =>
        handled { state with
          selectedDate := snapshot.actual.today
          notice := ""
          detailCursor := 0
          detailScroll := 0
          overviewScroll := 0
          overviewManualScroll := false
          activePane := .calendar
        }
    | .ctrl 'u' | .ctrl 'd' | .pageUp | .pageDown =>
        let forward := key == .ctrl 'd' || key == .pageDown
        if state.activePane == .calendar then handled (scrollOverview bounds snapshot state forward)
        else if (homeActualRecords snapshot state).isEmpty then
          some (scrollDetail bounds snapshot state forward 5)
        else handled (moveDetailCursor bounds snapshot { state with notice := "" } (if forward then 5 else -5))
    | .home =>
        if state.activePane == .detail then
          handled (moveDetailCursor bounds snapshot { state with notice := "" } (-10000))
        else
          handled { state with
            selectedDate := snapshot.actual.today
            notice := ""
            detailCursor := 0
            detailScroll := 0
            overviewScroll := 0
            overviewManualScroll := false
          }
    | .«end» =>
        if state.activePane == .detail then
          handled (moveDetailCursor bounds snapshot { state with notice := "" } 10000)
        else handled state
    | .escape | .enter =>
        if state.activePane == .detail then
          if key == .escape then handled (focusCalendar state) else none
        else
          match state.zoomLevel with
          | .year => handled (setZoomLevel state .month)
          | .month => handled (setZoomLevel state .day)
          | .day => if key == .escape then handled state else none
    | .input 'h' | .input 'H' | .left =>
        handled (if state.activePane == .detail then state else (update state .left).state)
    | .input 'l' | .input 'L' | .right =>
        handled (if state.activePane == .detail then state else (update state .right).state)
    | .input 'j' | .input 'J' | .down =>
        let delta : Int := repeatCount
        handled (if state.activePane == .detail then moveDetailCursor bounds snapshot state delta else repeatUpdate state .down repeatCount)
    | .input 'k' | .input 'K' | .up =>
        let delta : Int := - (repeatCount : Int)
        handled (if state.activePane == .detail then moveDetailCursor bounds snapshot state delta else repeatUpdate state .up repeatCount)
    | _ => none

/--
Production Home presentation over LOAM's already-admitted read answers.
This is presentation only: it adds no household authority, cycle policy,
Scheduled completeness claim, or retained pending status.
-/
def homeView (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  let state := reconcileState bounds snapshot state
  let footer := homeFooter bounds state
  let body := homeBody bounds footer.length snapshot state
  .column ((Loam.Tui.Layout.fitWithFooter bounds body footer).map fun row =>
    .row ((Loam.Tui.Layout.clipCells (Loam.Tui.Layout.contentWidth bounds) row.lines.flatten).map fun cell =>
      span (String.singleton cell.glyph) cell.style))

/-- Production root rendering is Home-only; object workspaces run in their own sessions. -/
def view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  homeView bounds snapshot state

end Loam.Tui.Home
