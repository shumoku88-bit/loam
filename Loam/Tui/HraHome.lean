import Loam.Tui.Layout
import Loam.Tui.Main

namespace Loam.Tui.HraHome

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
def hraCalendarSpans
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
  (List.range 6).map fun row => .row (hraCalendarSpans today pastOpenDates state row)

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
  | .ok .unknownCompletionScheduled =>
      [plainLine "   [Unavailable] completion evidence references an unknown Scheduled identity"]
  | .ok .unknownRetirementScheduled =>
      [plainLine "   [Unavailable] retirement evidence references an unknown Scheduled identity"]
  | .ok .unknownReplacementScheduled =>
      [plainLine "   [Unavailable] replacement evidence references an unknown Scheduled identity"]
  | .ok .invalidReplacementGraph =>
      [plainLine "   [Unavailable] Scheduled replacement graph is invalid"]
  | .ok .conflictingTerminalEvidence =>
      [plainLine "   [Unavailable] Scheduled terminal evidence conflicts"]

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
    | .ok .unknownCompletionScheduled => "Unavailable"
    | .ok .unknownRetirementScheduled => "Unavailable"
    | .ok .unknownReplacementScheduled => "Unavailable"
    | .ok .invalidReplacementGraph => "Unavailable"
    | .ok .conflictingTerminalEvidence => "Unavailable"
  let pendingStatus :=
    match pending with
    | .ok records => toString records.length
    | .error _ => "Unavailable"
  ["Scheduled: " ++ scheduled, "Pending: " ++ pendingStatus]

private def pendingSection (pending : PendingEvidence) : List Widget :=
  match pending with
  | .ok [] => []
  | _ => [blankLine, plainLine " Pending Scheduled:"] ++ pendingLines pending

private def homeBody (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
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

/--
HRA-shaped Home presentation over LOAM's already-admitted read answers.
This is presentation only: it adds no household authority, cycle policy,
Scheduled completeness claim, or retained pending status.
-/
def homeView (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  let body := homeBody bounds snapshot state
  let footer :=
    (if state.notice.isEmpty then [] else [plainLine state.notice]) ++ helpLines bounds
  .column (Loam.Tui.Layout.fitWithFooter bounds body footer)

/-- Production root rendering is Home-only; object workspaces run in their own sessions. -/
def view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  homeView bounds snapshot state

end Loam.Tui.HraHome
