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

private def calendarHeader : Widget :=
  plainLine " Mon  Tue  Wed  Thu  Fri  Sat  Sun"

private def hraCalendarSpans (state : State) (row : Nat) : List Span :=
  (List.range 7).map fun col =>
    match calendarSlot state row col with
    | none => span "     "
    | some date =>
        let day :=
          match date.splitOn "-" with
          | [_, _, text] => text
          | _ => "  "
        if date == state.selectedDate then
          span ("[" ++ day ++ "]") .selected
        else
          span (" " ++ day ++ "  ")

private def calendarRows (state : State) : List Widget :=
  (List.range 6).map fun row => .row (hraCalendarSpans state row)

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
  | .due first rest =>
      (first :: rest).flatMap fun record =>
        [ plainLine
            ("   - Scheduled: " ++ record.scheduledOn ++ "  [Open]  " ++
              Loam.ScheduledReview.summary record) ] ++
        (record.movement.changes.map fun change =>
          plainLine
            ("       " ++ change.coordinate.token ++ "  " ++
              toString change.quantity.quanta ++ " " ++ record.measure.token))
  | .unknown =>
      [mutedLine "   (unknown; no completeness horizon is claimed)"]
  | .unknownCompletionScheduled =>
      [plainLine "   [Unavailable] completion evidence references an unknown Scheduled identity"]
  | .unknownRetirementScheduled =>
      [plainLine "   [Unavailable] retirement evidence references an unknown Scheduled identity"]
  | .unknownReplacementScheduled =>
      [plainLine "   [Unavailable] replacement evidence references an unknown Scheduled identity"]
  | .invalidReplacementGraph =>
      [plainLine "   [Unavailable] Scheduled replacement graph is invalid"]
  | .conflictingTerminalEvidence =>
      [plainLine "   [Unavailable] Scheduled terminal evidence conflicts"]

private def statusLine (snapshot : Snapshot) (state : State) : String :=
  let scheduled :=
    match homeScheduledEvidence snapshot state with
    | .due _ rest => "Due (" ++ toString (rest.length + 1) ++ ")"
    | .unknown => "Unknown"
    | .unknownCompletionScheduled => "Unavailable"
    | .unknownRetirementScheduled => "Unavailable"
    | .unknownReplacementScheduled => "Unavailable"
    | .invalidReplacementGraph => "Unavailable"
    | .conflictingTerminalEvidence => "Unavailable"
  " Scheduled    : " ++ scheduled ++
    "   Attention: [i]   Capacity: [e]   Reports: [v]"

private def homeBody (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  [ ruleLine bounds '='
  , .row
      [ span " LOAM Home: known through " .muted
      , span snapshot.actual.today
      , span "  [Focus: " .muted
      , span state.selectedDate .selected
      , span "]" .muted
      ]
  , ruleLine bounds '='
  , plainLine ("            " ++ monthTitle state)
  , calendarHeader
  ] ++
  calendarRows state ++
  [ ruleLine bounds '-'
  , plainLine (" Selected Day : " ++ state.selectedDate)
  , plainLine (" Known Through: " ++ snapshot.actual.today)
  , plainLine (statusLine snapshot state)
  , ruleLine bounds '-'
  , plainLine " Actual Transactions:"
  ] ++
  actualLines snapshot state ++
  [ blankLine
  , plainLine " Planned Payments:"
  ] ++
  scheduledLines snapshot state ++
  [ blankLine
  , plainLine " Household Workspaces:"
  , mutedLine "   [i] Attention is current-open evidence; selected-day membership is not inferred."
  , mutedLine "   [e] Capacity is all-retained entitlement; no household cycle is inferred."
  , ruleLine bounds '='
  ]

private def helpLines (bounds : Bounds) : List Widget :=
  if bounds.width >= 112 then
    [mutedLine "[h/l] day  [k/j] week  [g] known  [r] record  [a] actual  [p] scheduled  [i] attention  [e] capacity  [v] reports  [q] quit"]
  else
    [ mutedLine "[h/l] day  [k/j] week  [g] known  [r] record  [q] quit"
    , mutedLine "[a] actual  [p] scheduled  [i] attention  [e] capacity  [v] reports"
    ]

private def padBeforeFooter (bounds : Bounds) (body footer : List Widget) : List Widget :=
  let used := body.length + footer.length
  let available := if bounds.height > 0 then bounds.height - 1 else 0
  let padding := if used < available then available - used else 0
  body ++ (List.replicate padding blankLine) ++ footer

/--
HRA-shaped Home presentation over LOAM's already-admitted read answers.
This is presentation only: it adds no household authority, cycle policy, or
Scheduled completeness claim.
-/
def homeView (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  let body := homeBody bounds snapshot state
  let footer :=
    (if state.notice.isEmpty then [] else [plainLine state.notice]) ++ helpLines bounds
  .column (padBeforeFooter bounds body footer)

/-- Use the HRA-shaped Home while retaining existing production workspace views. -/
def view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .home _ => homeView bounds snapshot state
  | _ => Loam.Tui.Main.view snapshot state

end Loam.Tui.HraHome
