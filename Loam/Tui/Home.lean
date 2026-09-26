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
private def dailyPaceHistoryLines (snapshot : Snapshot) : List Widget :=
  match snapshot.paceHistory with
  | .notRequested =>
      [mutedLine " Recent pace (current truth): not requested"]
  | .unavailable =>
      [mutedLine " Recent pace (current truth): unavailable"]
  | .failed _ =>
      [mutedLine " Recent pace (current truth): failed"]
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
  , plainLine (centeredMonthTitle state)
  , calendarHeader
  ] ++
  calendarRows snapshot.actual.today pastOpenDates state ++
  [mutedLine " underline = today"] ++
  (if pastOpenDates.isEmpty then [] else
    [mutedLine " ! = expected date passed; Scheduled is still current-open"]) ++
  [blankLine] ++
  homeSummaryLines snapshot ++
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
    (snapshot : Snapshot) (state : State) (pastOpenDates : List String) : Widget :=
  .column
    ([ plainLine (centeredMonthTitle state)
     , calendarHeader
     ] ++
     calendarRows snapshot.actual.today pastOpenDates state ++
     [mutedLine " underline = today"] ++
     (if pastOpenDates.isEmpty then [] else
       [mutedLine " ! = still current-open"]) ++
     [blankLine] ++
     wideHomeSummaryLines snapshot)

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
  let leftWidth := 41
  let dividerWidth := 3
  let rightWidth := contentWidth - leftWidth - dividerWidth
  let panelRows := widePanelRows bounds footerRows
  let left := wideCalendarPane snapshot state pastOpenDates
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
  ["Day:", "[h/l] day", "[k/j] week", "[t] today", "[Enter] open",
   "[r] record", "[a] actual", "[s] scheduled", "[q] quit"]

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
