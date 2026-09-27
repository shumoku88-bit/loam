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

private def centeredMonthTitle (state : State) : String :=
  let title := monthTitle state
  let width := Loam.Tui.Layout.displayWidth title
  let padding := if width < 35 then (35 - width) / 2 else 0
  repeatChar padding ' ' ++ title

private def calendarHeader : Widget :=
  plainLine " Mon  Tue  Wed  Thu  Fri  Sat  Sun"

private abbrev PendingEvidence := Except String (List Loam.ScheduledReview.Record)

private def pendingEvidence (snapshot : Snapshot) : PendingEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled =>
      Loam.ScheduledReview.currentOpenBeforeDate scheduled snapshot.actual.today

private def pendingDates : PendingEvidence → List String
  | .ok records => records.map (fun record => record.scheduledOn)
  | .error _ => []

/-- Pure calendar presentation; marker dates are supplied evidence, not classified here. -/
def calendarSpans
    (today : String) (pastOpenDates : List String) (state : State) (row : Nat) : List Span :=
  (List.range 7).map fun col =>
    match calendarSlot state row col with
    | none => span "     "
    | some date =>
        let day :=
          match date.splitOn "-" with
          | [_, _, text] => text
          | _ => "  "
        let marker := if pastOpenDates.any (fun pending => pending == date) then "!" else " "
        if date == state.selectedDate then
          span ("[" ++ day ++ marker ++ "]")
            (if date == today then .selectedUnderlined else .selected)
        else
          span (" " ++ day ++ marker ++ " ")
            (if date == today then .underlined else .normal)

private def calendarRows (today : String) (pastOpenDates : List String) (state : State) : List Widget :=
  (List.range 6).map fun row => .row (calendarSpans today pastOpenDates state row)

private def moneyWindow (state : State) : String × String :=
  Loam.Tui.Calendar.monthWindow (selectedMonth state)

private def moneyMeasureInfo
    (snapshot : Snapshot) (state : State) : Option (MoneyCalendarSnapshot × List Loam.Core.MeasureId) :=
  match snapshot.moneyCalendar with
  | .loaded money =>
      let window := moneyWindow state
      some (money, money.flow.measuresInWindow window.1 window.2)
  | _ => none

private def moneyMeasure?
    (snapshot : Snapshot) (state : State) : Option Loam.Core.MeasureId := do
  let (_, measures) ← moneyMeasureInfo snapshot state
  measures.head?

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

private def moneyDateSpan
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

private def commaEveryThreeFromRight : List Char → Nat → List Char
  | [], _ => []
  | char :: rest, count =>
      if count = 3 then
        ',' :: char :: commaEveryThreeFromRight rest 1
      else
        char :: commaEveryThreeFromRight rest (count + 1)

private def groupThousands (text : String) : String :=
  let reversed :=
    commaEveryThreeFromRight text.toList.reverse 0
  String.ofList reversed.reverse

private def groupedAmountText (text : String) : String :=
  match text.splitOn "." with
  | [whole] => groupThousands whole
  | [whole, fractional] => groupThousands whole ++ "." ++ fractional
  | _ => text

private def moneyAmountSpan
    (paneWidth : Nat) (today : String)
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
            Loam.MeasurePresentation.formatQuanta money.presentation row.measure amount
          let plain := signText ++ rendered
          let grouped := signText ++ groupedAmountText rendered
          if Loam.Tui.Layout.displayWidth grouped ≤ cellWidth then grouped else plain
    | _, _ => ""
  span (Loam.Tui.Layout.padLeft cellWidth text)
    (if date == state.selectedDate then
      if date == today then .selectedUnderlined else .selected
    else
      .normal)

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
      | some date => moneyAmountSpan paneWidth today snapshot state date true
    let minusLine := moneyGridRow <| dates.map fun slot =>
      match slot with
      | none => blankMoneyCell paneWidth
      | some date => moneyAmountSpan paneWidth today snapshot state date false
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
  [mutedLine " underline = today; ! = Scheduled still open; ? = unresolved role"]

private def displayDescription (record : ReviewRecord) : String :=
  if record.description.isEmpty then "(no description)"
  else Loam.ActualReview.displayText record.description

private def actualRecordLines (record : ReviewRecord) : List Widget :=
  [plainLine ("   - " ++ displayDescription record)] ++
  (record.event.effects.map fun effect =>
    plainLine
      ("       " ++ effect.locus.token ++ "  " ++
        toString effect.quantity.quanta ++ " " ++ effect.measure.token))

private def actualLines (snapshot : Snapshot) (state : State) : List Widget :=
  let records := (homeActualRecords snapshot state).reverse
  if records.isEmpty then
    [mutedLine "   (none recorded)"]
  else
    records.flatMap actualRecordLines

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

private def shortPaceDate (date : String) : String :=
  String.ofList (date.toList.drop 5)

/--
Home favors exact recent values over a shape-only graph.

The review boundary may derive seven days, while Home keeps the last five rows
to preserve the calendar as the dominant object in the left pane.
-/
private def readFailureDetailLines (message : String) : List Widget :=
  (Loam.Tui.Layout.flowTokens 36 " " (message.splitOn " ")).take 3 |>.map fun text =>
    mutedLine ("   " ++ text)

private def dailyPaceHistoryLines (snapshot : Snapshot) : List Widget :=
  match snapshot.paceHistory with
  | .notRequested =>
      [mutedLine " Recent pace (current truth): not requested"]
  | .unavailable =>
      [mutedLine " Recent pace (current truth): unavailable"]
  | .failed message =>
      [mutedLine " Recent pace (current truth): failed"] ++
        readFailureDetailLines message
  | .loaded history =>
      let recent := (history.reverse.take 5).reverse
      if recent.isEmpty then
        [mutedLine " Recent pace (current truth): unavailable"]
      else
        [mutedLine " Recent pace (recomputed current truth)"] ++
        (recent.map fun point =>
          match point.dailyPaceQuanta? with
          | some quanta =>
              mutedLine
                ("   " ++ shortPaceDate point.observedAt ++ "  " ++
                  toString quanta ++ " jpy/day")
          | none =>
              mutedLine
                ("   " ++ shortPaceDate point.observedAt ++ "  unavailable"))

private def dailyPaceText (snapshot : Snapshot) : String :=
  match snapshot.pace with
  | .notRequested => "Daily pace: not requested"
  | .unavailable => "Daily pace: unavailable"
  | .failed _ => "Daily pace: failed"
  | .loaded pace =>
      match pace.dailyPaceQuanta? with
      | none => "Daily pace: unavailable"
      | some quanta =>
          "Daily pace: " ++ toString quanta ++ " jpy/day  (" ++
            toString pace.remainingDays ++ " days; " ++
            toString pace.availableThroughEnd.quanta ++
            " jpy through " ++ pace.endExclusive ++ ")"

private def nextScheduledText (snapshot : Snapshot) : String :=
  match snapshot.scheduled with
  | .error _ => "Next Scheduled: unavailable"
  | .ok scheduled =>
      match Loam.ScheduledReview.earliestCurrentOpenRecord scheduled with
      | .error _ => "Next Scheduled: unavailable"
      | .ok none => "Next Scheduled: none current-open"
      | .ok (some record) =>
          let status :=
            if decide (record.scheduledOn < snapshot.actual.today) then "  [Still open]"
            else ""
          "Next Scheduled: " ++ record.scheduledOn ++ status ++ "  " ++
            Loam.ScheduledReview.summary record

private def attentionText (snapshot : Snapshot) : String :=
  match snapshot.attention with
  | .notRequested => "Attention: not requested"
  | .unavailable => "Attention: not configured"
  | .failed _ => "Attention: failed"
  | .loaded attention =>
      match attention.openItems with
      | [] => "Attention: 0 open"
      | [first] =>
          "Attention: 1 open  " ++
            Loam.ActualReview.shortText 72 (Loam.AttentionReview.summary first)
      | _ =>
          "Attention: " ++ toString attention.openItems.length ++ " open  [i] manage"

private def attentionLine (snapshot : Snapshot) : Widget :=
  match snapshot.attention with
  | .loaded { openItems := _ :: _ } =>
      plainLine (" " ++ attentionText snapshot)
  | _ => mutedLine (" " ++ attentionText snapshot)

private def wideAttentionLines (snapshot : Snapshot) : List Widget :=
  match snapshot.attention with
  | .notRequested =>
      [ mutedLine " Attention"
      , mutedLine "   not requested"
      ]
  | .unavailable =>
      [ mutedLine " Attention"
      , mutedLine "   not configured"
      ]
  | .failed _ =>
      [ mutedLine " Attention"
      , mutedLine "   failed"
      ]
  | .loaded attention =>
      match attention.openItems with
      | [] =>
          [ mutedLine " Attention"
          , mutedLine "   0 open"
          ]
      | [first] =>
          [ plainLine " Attention"
          , plainLine "   1 open"
          , plainLine ("   " ++
              Loam.ActualReview.shortText 34 (Loam.AttentionReview.summary first))
          ]
      | _ =>
          [ plainLine " Attention"
          , plainLine ("   " ++ toString attention.openItems.length ++ " open")
          , mutedLine "   [i] manage"
          ]

private def dailyPaceLine (snapshot : Snapshot) : Widget :=
  match snapshot.pace with
  | .notRequested => mutedLine (" " ++ dailyPaceText snapshot)
  | .unavailable => mutedLine (" " ++ dailyPaceText snapshot)
  | .failed _ => mutedLine (" " ++ dailyPaceText snapshot)
  | .loaded pace =>
      match pace.dailyPaceQuanta? with
      | none => mutedLine (" " ++ dailyPaceText snapshot)
      | some _ => plainLine (" " ++ dailyPaceText snapshot)

private def nextScheduledLine (snapshot : Snapshot) : Widget :=
  match snapshot.scheduled with
  | .error _ => mutedLine (" " ++ nextScheduledText snapshot)
  | .ok scheduled =>
      match Loam.ScheduledReview.earliestCurrentOpenRecord scheduled with
      | .error _ => mutedLine (" " ++ nextScheduledText snapshot)
      | .ok none => mutedLine (" " ++ nextScheduledText snapshot)
      | .ok (some _) => plainLine (" " ++ nextScheduledText snapshot)

private def homeSummaryLines (snapshot : Snapshot) : List Widget :=
  [dailyPaceLine snapshot] ++
  dailyPaceHistoryLines snapshot ++
  [nextScheduledLine snapshot, attentionLine snapshot]

private def wideHomeSummaryLines (snapshot : Snapshot) : List Widget :=
  let currentPaceLines :=
    match snapshot.pace with
    | .notRequested =>
        [ mutedLine " Daily pace"
        , mutedLine "   not requested"
        ]
    | .unavailable =>
        [ mutedLine " Daily pace"
        , mutedLine "   unavailable"
        ]
    | .failed _ =>
        [ mutedLine " Daily pace"
        , mutedLine "   failed"
        ]
    | .loaded pace =>
        match pace.dailyPaceQuanta? with
        | none =>
            [ mutedLine " Daily pace"
            , mutedLine "   unavailable"
            ]
        | some quanta =>
            [ plainLine " Daily pace"
            , plainLine ("   " ++ toString quanta ++ " jpy/day")
            , mutedLine
                ("   " ++ toString pace.availableThroughEnd.quanta ++
                  " jpy through " ++ pace.endExclusive)
            ]
  let paceLines := currentPaceLines ++ dailyPaceHistoryLines snapshot
  let scheduledLines :=
    match snapshot.scheduled with
    | .error _ =>
        [ mutedLine " Next Scheduled"
        , mutedLine "   unavailable"
        ]
    | .ok scheduled =>
        match Loam.ScheduledReview.earliestCurrentOpenRecord scheduled with
        | .error _ =>
            [ mutedLine " Next Scheduled"
            , mutedLine "   unavailable"
            ]
        | .ok none =>
            [ mutedLine " Next Scheduled"
            , mutedLine "   none current-open"
            ]
        | .ok (some record) =>
            let status :=
              if decide (record.scheduledOn < snapshot.actual.today) then "  [Still open]"
              else ""
            [ plainLine " Next Scheduled"
            , plainLine ("   " ++ record.scheduledOn ++ status)
            , plainLine ("   " ++ Loam.ScheduledReview.summary record)
            ]
  paceLines ++ [blankLine] ++ scheduledLines ++
    [blankLine] ++ wideAttentionLines snapshot

private def pendingSection (pending : PendingEvidence) : List Widget :=
  match pending with
  | .ok [] => []
  | _ => [blankLine, plainLine " Pending Scheduled:"] ++ pendingLines pending

private def stackedHomeBody (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let pending := pendingEvidence snapshot
  let pastOpenDates := pendingDates pending
  [ ruleLine bounds '='
  , .row
      [ span " LOAM Home: known through " .muted
      , span snapshot.actual.today
      , span "  [Focus: " .muted
      , span state.selectedDate .selected
      , span "]" .muted
      ]
  , ruleLine bounds '='
  ] ++
  (match state.calendarMode with
   | .plain =>
       [ plainLine (centeredMonthTitle state)
       , calendarHeader
       ] ++
       calendarRows snapshot.actual.today pastOpenDates state ++
       [mutedLine " underline = today"] ++
       (if pastOpenDates.isEmpty then [] else
         [mutedLine " ! = expected date passed; Scheduled is still current-open"]) ++
       [blankLine] ++
       homeSummaryLines snapshot
   | .money =>
       moneyCalendarBlock (Loam.Tui.Layout.contentWidth bounds) snapshot state pastOpenDates) ++
  [ ruleLine bounds '-'
  , plainLine (" Selected Day : " ++ state.selectedDate ++ "  [Enter] open day workspace")
  ] ++
  (Loam.Tui.Layout.flowTokens (Loam.Tui.Layout.contentWidth bounds) "  " (statusTokens snapshot state pending)).map
    (fun text => mutedLine (" " ++ text)) ++
  pendingSection pending ++
  [ blankLine
  , plainLine " Actual Transactions:"
  ] ++
  actualLines snapshot state ++
  [ blankLine
  , plainLine " Scheduled:"
  ] ++
  scheduledLines snapshot state ++
  [ruleLine bounds '=']

private def wideCalendarPane
    (paneWidth : Nat)
    (snapshot : Snapshot) (state : State) (pastOpenDates : List String) : Widget :=
  .column <|
    match state.calendarMode with
    | .plain =>
        [ plainLine (centeredMonthTitle state)
        , calendarHeader
        ] ++
        calendarRows snapshot.actual.today pastOpenDates state ++
        [mutedLine " underline = today"] ++
        (if pastOpenDates.isEmpty then [] else
          [mutedLine " ! = still current-open"]) ++
        [blankLine] ++
        wideHomeSummaryLines snapshot
    | .money =>
        moneyCalendarBlock paneWidth snapshot state pastOpenDates

private def wideDetailLines
    (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : List Widget :=
  pendingSection pending ++
  [ blankLine
  , plainLine " Actual"
  ] ++
  actualLines snapshot state ++
  [ blankLine
  , plainLine " Scheduled"
  ] ++
  scheduledLines snapshot state

private def wideDetailHeaderRows : Nat := 4

private def wideDetailVisibleRows (panelRows : Nat) : Nat :=
  panelRows - wideDetailHeaderRows

private def widePendingMarkerExplanation : PendingEvidence → Widget
  | .ok [] => blankLine
  | .ok _ => mutedLine " ! = expected date passed; Scheduled is still current-open"
  | .error _ => blankLine

private def wideScrollHint (content visible offset : Nat) : Widget :=
  if content ≤ visible then blankLine
  else
    let maxOffset := Loam.Tui.Scroll.maxOffset content visible
    let direction :=
      if offset = 0 then "↓"
      else if offset = maxOffset then "↑"
      else "↑↓"
    mutedLine (" " ++ direction ++ " scroll  (Ctrl-U/D)")

private def wideSelectedDayPane
    (panelRows : Nat) (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : Widget :=
  let details := wideDetailLines snapshot state pending
  let visible := wideDetailVisibleRows panelRows
  let offset := Loam.Tui.Scroll.clamp details.length visible state.detailScroll
  let status := String.intercalate "  " (statusTokens snapshot state pending)
  .column
    ([ .row [span " Selected Day  " .muted, span state.selectedDate .selected]
     , mutedLine (" " ++ status)
     , widePendingMarkerExplanation pending
     , wideScrollHint details.length visible offset
     ] ++
     ((details.drop offset).take visible))

private def widePanelRows (bounds : Bounds) (footerRows : Nat) : Nat :=
  Loam.Tui.Layout.footerBodyCapacity bounds footerRows - 4

private def wideHomeBody
    (bounds : Bounds) (footerRows : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let pending := pendingEvidence snapshot
  let pastOpenDates := pendingDates pending
  let contentWidth := Loam.Tui.Layout.contentWidth bounds
  let dividerWidth := 3
  let rightWidth :=
    match state.calendarMode with
    | .plain => 64
    | .money => 50
  let leftWidth := contentWidth - dividerWidth - rightWidth
  let panelRows := widePanelRows bounds footerRows
  let left := wideCalendarPane leftWidth snapshot state pastOpenDates
  let right := wideSelectedDayPane panelRows snapshot state pending
  [ ruleLine bounds '='
  , .row
      [ span " LOAM Home: known through " .muted
      , span snapshot.actual.today
      , span "  [Focus: " .muted
      , span state.selectedDate .selected
      , span "]" .muted
      ]
  , ruleLine bounds '='
  ] ++
  Loam.Tui.Layout.sideBySide panelRows leftWidth rightWidth left right ++
  [ruleLine bounds '=']

private def homeBody
    (bounds : Bounds) (footerRows : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  if bounds.width ≥ 120 then wideHomeBody bounds footerRows snapshot state
  else stackedHomeBody bounds snapshot state

private def dayHelpTokens : List String :=
  ["Day:", "[h/l] day", "[k/j] week", "[t] today", "[f] money", "[Enter] open",
   "[r] record", "[x] exchange", "[a] actual", "[s] scheduled", "[q] quit"]

private def householdHelpTokens : List String :=
  ["Household:", "[i] attention", "[b] balances", "[c] budget", "[e] capacity",
   "[v] reports"]

private def manageHelpTokens : List String :=
  ["Manage:", "[p] purpose routing", "[m] manage loci", "[o] observe quantities"]

private def helpLines (bounds : Bounds) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  (Loam.Tui.Layout.flowLines width "  "
    [dayHelpTokens, householdHelpTokens, manageHelpTokens]).map mutedLine

/-- Wide Home is a spatial projection; narrow Home retains the stacked projection. -/
def usesWideLayout (bounds : Bounds) : Bool :=
  decide (120 ≤ bounds.width)

/-- Layout width may expose a local detail viewport, but never changes arrow-key meaning. -/
def detailScrollDirection?
    (bounds : Bounds) : Loam.Tui.Terminal.Key → Option Bool
  | .ctrl 'u' => if usesWideLayout bounds then some false else none
  | .ctrl 'd' => if usesWideLayout bounds then some true else none
  | _ => none

private def homeFooter (bounds : Bounds) (state : State) : List Widget :=
  let help := helpLines bounds
  if usesWideLayout bounds then
    (if state.notice.isEmpty then [blankLine] else [plainLine state.notice]) ++ help
  else
    (if state.notice.isEmpty then [] else [plainLine state.notice]) ++ help

/-- Move only the wide Home detail viewport. -/
def scrollWideDetail
    (bounds : Bounds) (snapshot : Snapshot) (state : State) (forward : Bool) : State :=
  if !usesWideLayout bounds then state
  else
    let footerRows := (homeFooter bounds state).length
    let panelRows := widePanelRows bounds footerRows
    let visible := wideDetailVisibleRows panelRows
    let pending := pendingEvidence snapshot
    let content := (wideDetailLines snapshot state pending).length
    let current := Loam.Tui.Scroll.clamp content visible state.detailScroll
    let next :=
      if forward then Loam.Tui.Scroll.forward content visible current 1
      else Loam.Tui.Scroll.backward content visible current 1
    { state with detailScroll := next, notice := "" }

/--
Production Home presentation over LOAM's already-admitted read answers.
This is presentation only: it adds no household authority, cycle policy,
Scheduled completeness claim, or retained pending status.
-/
def homeView (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  let footer := homeFooter bounds state
  let body := homeBody bounds footer.length snapshot state
  .column (Loam.Tui.Layout.fitWithFooter bounds body footer)

/-- Production root rendering is Home-only; object workspaces run in their own sessions. -/
def view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  homeView bounds snapshot state

end Loam.Tui.Home
