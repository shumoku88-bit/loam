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

private def ruleWidth (bounds : Bounds) : Nat :=
  if bounds.width > 1 then bounds.width - 1 else bounds.width

private def ruleLine (bounds : Bounds) (char : Char) : Widget :=
  mutedLine (repeatChar (ruleWidth bounds) char)

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
  | .failed _ => month ++ "  ± unavailable"
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
          if Loam.Tui.Layout.displayWidth grouped ≤ cellWidth then grouped else plain
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
  [ plainLine (centeredText gridWidth (moneyTitle snapshot state))
  , moneyRule paneWidth '┌' '┬' '┐'
  , moneyCalendarHeader paneWidth
  , moneyRule paneWidth '├' '┼' '┤'
  ] ++
  moneyCalendarRows paneWidth snapshot.actual.today pastOpenDates snapshot state ++
  (let summary := moneyMonthSummaryText snapshot state
   if summary.isEmpty then []
   else [plainLine (centeredText gridWidth summary)]) ++
  [mutedLine " underline = today; ! = Scheduled still open; ? = unresolved role"]

private def displayDescription (record : ReviewRecord) : String :=
  if record.description.isEmpty then "(no description)"
  else Loam.ActualReview.displayText record.description

private def actualRecordLines
    (isSelected : Bool) (state : State) (record : ReviewRecord) : List Widget :=
  let prefixSpan :=
    if isSelected then span " ▶ " .series2
    else span "   " .normal
  let markerSpan :=
    if isSelected then span "- " .series2
    else span "- " .muted
  let dateText :=
    match state.zoomLevel with
    | .day => ""
    | .month | .year =>
        match record.date with
        | some d => d ++ "  "
        | none => ""
  let descSpan :=
    span (dateText ++ displayDescription record) (if isSelected then .selected else .normal)
  let titleRow := .row [prefixSpan, markerSpan, descSpan]
  let effectLines := record.event.effects.map fun effect =>
    let effectText := "       " ++ effect.locus.token ++ "  " ++
        toString effect.quantity.quanta ++ " " ++ effect.measure.token
    if isSelected then plainLine effectText else mutedLine effectText
  titleRow :: effectLines

private def actualLines (snapshot : Snapshot) (state : State) : List Widget :=
  let records := (homeActualRecords snapshot state).reverse
  if records.isEmpty then
    [mutedLine "   (none recorded)"]
  else
    records.zipIdx.flatMap fun (record, idx) =>
      let isSelected := state.activePane == .detail && idx == state.detailCursor
      actualRecordLines isSelected state record

private def scheduledLines (snapshot : Snapshot) (state : State) : List Widget :=
  match homeScheduledEvidence snapshot state with
  | .error message =>
      [plainLine ("   [Unavailable] " ++ message)]
  | .ok (.due first rest) =>
      (first :: rest).flatMap fun record =>
        [ plainLine
            ("   - Scheduled: " ++ record.scheduledOn ++ "  [Open]  " ++
              Loam.ScheduledReview.summary record) ] ++
        (record.movement.changes.map fun change =>
          plainLine
            ("       " ++ change.coordinate.token ++ "  " ++
              toString change.quantity.quanta ++ " " ++ record.measure.token))
  | .ok .unknown =>
      [mutedLine "   (unknown; no completeness horizon is claimed)"]

private def pendingLines : PendingEvidence → List Widget
  | .error message =>
      [plainLine ("   [Unavailable] " ++ message)]
  | .ok [] =>
      [mutedLine "   (none; no past-date current-open Scheduled occurrence)"]
  | .ok records =>
      records.map fun record =>
        plainLine
          ("   - " ++ record.scheduledOn ++ "  [Still open]  " ++
            Loam.ScheduledReview.summary record)

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

private def pendingSection (pending : PendingEvidence) : List Widget :=
  match pending with
  | .ok [] => []
  | _ => [blankLine, plainLine " Pending Scheduled:"] ++ pendingLines pending

private def monthNames : List String :=
  ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

private def centeredYearTitle (year : Nat) : String :=
  let title := s!"==  Year {year}  =="
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
  , mutedLine " [Enter] days  [Tab] transactions"
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
  , mutedLine " [Enter] months  [Tab] transactions"
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
    (Loam.Tui.Layout.flowTokens (width - 3) "  " items).map fun line =>
      plainLine ("   " ++ line)
  let flowLines :=
    match snapshot.moneyCalendar with
    | .notRequested => [mutedLine "   flow not requested"]
    | .unavailable => [mutedLine "   flow unavailable"]
    | .failed message =>
        [plainLine "   flow read failed"] ++
        (Loam.Tui.Layout.flowTokens (width - 3) " " (message.splitOn " ")).map
          (fun line => mutedLine ("   " ++ line))
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
    (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : List Widget :=
  match state.zoomLevel with
  | .day =>
      pendingSection pending ++
      [ blankLine
      , plainLine " Actual"
      ] ++
      actualLines snapshot state ++
      [ blankLine
      , plainLine " Scheduled"
      ] ++
      scheduledLines snapshot state
  | .month | .year =>
      [ blankLine
      , plainLine " Actual Transactions"
      ] ++
      actualLines snapshot state

private def wideDetailHeaderRows : Nat := 4

private def wideDetailVisibleRows (panelRows : Nat) : Nat :=
  panelRows - wideDetailHeaderRows

private def widePendingMarkerExplanation (state : State) (pending : PendingEvidence) : Widget :=
  match state.zoomLevel with
  | .day =>
      match pending with
      | .ok [] => blankLine
      | .ok _ => mutedLine " ! = expected date passed; Scheduled is still current-open"
      | .error _ => blankLine
  | .month | .year => blankLine

private def detailPaneLines
    (panelRows : Nat) (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : List Widget :=
  let details := wideDetailLines snapshot state pending
  let visible := wideDetailVisibleRows panelRows
  let offset := Loam.Tui.Scroll.clamp details.length visible state.detailScroll
  let status := String.intercalate "  " (statusTokens snapshot state pending)
  let (headerLabel, headerValue) :=
    match state.zoomLevel with
    | .day => (" Selected Day    ", state.selectedDate)
    | .month =>
        let m := selectedMonth state
        (" Selected Month  ", Loam.Tui.Calendar.monthLabel m)
    | .year =>
        let m := selectedMonth state
        (" Selected Year   ", toString m.year)
  let isDetailFocused := state.activePane == .detail
  let focusBadge :=
    if isDetailFocused then
      [span " [active]" .series2]
    else
      [ span "  [Tab/w] focus" .muted ]
  let scrollInfo :=
    if details.length > visible then
      let maxOffset := Loam.Tui.Scroll.maxOffset details.length visible
      let percent := if maxOffset == 0 then 100 else (offset * 100) / maxOffset
      s!" ({offset + 1}..{min (offset + visible) details.length}/{details.length} lines, {percent}%)"
    else
      ""
  [ .row ([span headerLabel (if isDetailFocused then .selected else .muted), span headerValue .selected] ++ focusBadge)
  , mutedLine (" " ++ status ++ scrollInfo)
  , widePendingMarkerExplanation state pending
  , if !isDetailFocused && details.length > visible then
      mutedLine " [Tab] browse transactions / evidence"
    else blankLine
  ] ++ ((details.drop offset).take visible)

private def widePanelRows (bounds : Bounds) (footerRows : Nat) : Nat :=
  Loam.Tui.Layout.footerBodyCapacity bounds footerRows - 4

private def stackedHomeBody (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let pending := pendingEvidence snapshot
  let pastOpenDates := pendingDates pending
  let (headerLabel, headerValue) :=
    match state.zoomLevel with
    | .day => ("Selected Day", state.selectedDate)
    | .month => ("Selected Month", Loam.Tui.Calendar.monthLabel (selectedMonth state))
    | .year => ("Selected Year", toString (selectedMonth state).year)
  [ ruleLine bounds '='
  , .row
      [ span " LOAM Home: known through " .muted
      , span snapshot.actual.today
      , span "  [Focus: " .muted
      , span state.selectedDate .selected
      , span "]" .muted
      , span "  [View: " .muted
      , span (Loam.Tui.DateJump.zoomLabel state.zoomLevel)
      , span "]" .muted
      ]
  , ruleLine bounds '='
  ] ++
  (match state.zoomLevel with
   | .day =>
       moneyCalendarBlock (Loam.Tui.Layout.contentWidth bounds) snapshot state pastOpenDates
   | .month =>
       monthCalendarPane snapshot state ++ periodSummaryLines (Loam.Tui.Layout.contentWidth bounds) snapshot state
   | .year =>
       yearOverviewPane snapshot state ++ periodSummaryLines (Loam.Tui.Layout.contentWidth bounds) snapshot state) ++
  [ ruleLine bounds '-'
  , plainLine (" " ++ headerLabel ++ " : " ++ headerValue ++ "  [Tab] transactions")
  ] ++
  (Loam.Tui.Layout.flowTokens (Loam.Tui.Layout.contentWidth bounds) "  " (statusTokens snapshot state pending)).map
    (fun text => mutedLine (" " ++ text)) ++
  (match state.zoomLevel with
   | .day =>
       pendingSection pending ++
       [ blankLine
       , plainLine " Actual Transactions:"
       ] ++
       actualLines snapshot state ++
       [ blankLine
       , plainLine " Scheduled:"
       ] ++
       scheduledLines snapshot state
   | .month | .year =>
       [ blankLine
       , plainLine " Actual Transactions:"
       ] ++
       actualLines snapshot state) ++
  [ruleLine bounds '=']

/-- Do not silently clip additional measures or diagnostics below the calendar. -/
private def overviewViewport (height : Nat) (state : State) (rows : List Widget) : List Widget :=
  if rows.length ≤ height then rows
  else
    let visible := height - 1
    let offset := Loam.Tui.Scroll.clamp rows.length visible state.overviewScroll
    let hint := if state.activePane == .calendar then "[Ctrl-u/d] scroll" else "[Tab] calendar"
    (rows.drop offset).take visible ++
      [mutedLine s!" {offset + 1}-{min (offset + visible) rows.length}/{rows.length}  {hint}"]

private def detailPaneWidth (state : State) : Nat :=
  if state.zoomLevel == .day then 50 else 64

private def wideHomeBody
    (bounds : Bounds) (footerRows : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let pending := pendingEvidence snapshot
  let pastOpenDates := pendingDates pending
  let contentWidth := Loam.Tui.Layout.contentWidth bounds
  let dividerWidth := 3
  let rightWidth := detailPaneWidth state
  let leftWidth := contentWidth - dividerWidth - rightWidth
  let panelRows := widePanelRows bounds footerRows
  let leftRows := wideCalendarPane leftWidth snapshot state pastOpenDates
  let left := Widget.column (overviewViewport panelRows state leftRows)
  let right := Widget.column (detailPaneLines panelRows snapshot state pending)
  [ ruleLine bounds '='
  , .row
      [ span " LOAM Home: known through " .muted
      , span snapshot.actual.today
      , span "  [Focus: " .muted
      , span state.selectedDate .selected
      , span "]" .muted
      , span "  [View: " .muted
      , span (Loam.Tui.DateJump.zoomLabel state.zoomLevel)
      , span "]" .muted
      ]
  , ruleLine bounds '='
  ] ++
  Loam.Tui.Layout.sideBySide panelRows leftWidth rightWidth left right ++
  [ruleLine bounds '-']


private def homeBody
    (bounds : Bounds) (footerRows : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  if bounds.width ≥ 120 then wideHomeBody bounds footerRows snapshot state
  else if state.activePane == .detail then
    [ruleLine bounds '=', plainLine " LOAM Home / Transactions", ruleLine bounds '='] ++
    detailPaneLines (widePanelRows bounds footerRows) snapshot state (pendingEvidence snapshot) ++
    [ruleLine bounds '-']
  else
    overviewViewport (Loam.Tui.Layout.footerBodyCapacity bounds footerRows) state
      (stackedHomeBody bounds snapshot state)

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
  .row ([span categoryText] ++ itemSpans)

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
  let copyHelp :=
    [ { key := "[y]", label := "copy screen" }
    , { key := "[Shift+drag]", label := "select text" }
    ]
  if state.activePane == .detail then
    [ { key := "[Esc/Tab/w]", label := "calendar" } ] ++ copyHelp
  else
    [ { key := "[Tab/w]", label := "transactions" }
    , { key := "[Ctrl-u/d]", label := "scroll" }
    ] ++ copyHelp

private def actionHelp (state : State) : List HelpItem :=
  if state.activePane == .detail then
    [{ key := "[q]", label := "quit" }]
  else
    [ { key := "[r]", label := "record" }
    , { key := "[x]", label := "exchange" }
    , { key := "[a]", label := "actual" }
    , { key := "[s]", label := "scheduled" }
    , { key := "[q]", label := "quit" }
    ]

private def householdHelp : List HelpItem :=
  [ { key := "[d]", label := "daily pace" }
  , { key := "[i]", label := "attention" }
  , { key := "[b]", label := "balances" }
  , { key := "[u]", label := "settlements" }
  , { key := "[Space]", label := "commands" }
  , { key := "[v]", label := "reports" }
  ]

private def manageHelp : List HelpItem :=
  [ { key := "[m]", label := "manage loci" }
  , { key := "[o]", label := "observe quantities" }
  ]

private def helpLines (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let (navigationLabel, navigation) := navigationHelp state
  helpGroupLines width navigationLabel navigation ++
    helpGroupLines width "View" (viewHelp state) ++
    helpGroupLines width "Action" (actionHelp state) ++
    helpGroupLines width "Household" householdHelp ++
    helpGroupLines width "Manage" manageHelp

/-- Wide Home shows both panes; narrow Home gives focused transactions the full body. -/
def usesWideLayout (bounds : Bounds) : Bool :=
  decide (120 ≤ bounds.width)

private def homeFooter (bounds : Bounds) (state : State) : List Widget :=
  match state.jumpPrompt with
  | some buffer =>
      let promptLine := plainLine (" Jump to date / month / year: " ++ buffer ++ "█")
      let hintLine := mutedLine " [Enter] jump  [Esc] cancel  (e.g. 2026-10-15, 2026-10, 2026, 15)"
      [ruleLine bounds '-', promptLine, hintLine]
  | none =>
      let help := helpLines bounds state
      if state.notice.isEmpty then
        help
      else
        [plainLine state.notice, blankLine] ++ help

/-- Scroll non-selectable detail evidence when there are no Actual rows. -/
private def scrollDetail
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (forward : Bool) (step : Nat) : State :=
  let state := { state with notice := "" }
  let footerRows := (homeFooter bounds state).length
  let panelRows := widePanelRows bounds footerRows
  let visible := wideDetailVisibleRows panelRows
  let pending := pendingEvidence snapshot
  let content := (wideDetailLines snapshot state pending).length
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
  let (height, rows) :=
    if usesWideLayout bounds then
      let rightWidth := detailPaneWidth state
      let width := Loam.Tui.Layout.contentWidth bounds - 3 - rightWidth
      (widePanelRows bounds footerRows,
       wideCalendarPane width snapshot state (pendingDates (pendingEvidence snapshot)))
    else
      (Loam.Tui.Layout.footerBodyCapacity bounds footerRows, stackedHomeBody bounds snapshot state)
  let visible := if rows.length > height then height - 1 else height
  let current := Loam.Tui.Scroll.clamp rows.length visible state.overviewScroll
  let next :=
    if forward then Loam.Tui.Scroll.forward rows.length visible current 5
    else Loam.Tui.Scroll.backward rows.length visible current 5
  { state with overviewScroll := next }

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
    let actualHeaderRows :=
      match nextState.zoomLevel with
      | .day => (pendingSection pending).length + 2
      | .month | .year => 2
    let idx := nextState.detailCursor
    match records[idx]? with
    | none => nextState
    | some currentRec =>
        let prevRows := (records.take idx).foldl (fun acc r => acc + 1 + r.event.effects.length) 0
        let recStart := actualHeaderRows + prevRows
        let recEnd := recStart + 1 + currentRec.event.effects.length
        let content := (wideDetailLines snapshot nextState pending).length
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
  .column (Loam.Tui.Layout.fitWithFooter bounds body footer)

/-- Production root rendering is Home-only; object workspaces run in their own sessions. -/
def view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  homeView bounds snapshot state

end Loam.Tui.Home
