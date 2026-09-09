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
  let padding := if title.length < 35 then (35 - title.length) / 2 else 0
  repeatChar padding ' ' ++ title

private def calendarHeader : Widget :=
  plainLine " Mon  Tue  Wed  Thu  Fri  Sat  Sun"

private abbrev PendingEvidence := Except String (List Loam.ScheduledReview.Record)

private def pendingEvidence (snapshot : Snapshot) : PendingEvidence :=
  Loam.ScheduledReview.currentOpenBeforeDate snapshot.scheduled snapshot.actual.today

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

private def statusLine
    (snapshot : Snapshot) (state : State) (pending : PendingEvidence) : String :=
  let scheduled :=
    match homeScheduledEvidence snapshot state with
    | .due _ rest => "Due (" ++ toString (rest.length + 1) ++ ")"
    | .unknown => "Unknown"
    | .unknownCompletionScheduled => "Unavailable"
    | .unknownRetirementScheduled => "Unavailable"
    | .unknownReplacementScheduled => "Unavailable"
    | .invalidReplacementGraph => "Unavailable"
    | .conflictingTerminalEvidence => "Unavailable"
  let pendingStatus :=
    match pending with
    | .ok records => toString records.length
    | .error _ => "Unavailable"
  " Scheduled    : " ++ scheduled ++
    "   Pending: " ++ pendingStatus ++
    "   Budget: [c]   Capacity: [e]   Purpose routes: [u]   Roles: [o]   Loci: [m]   Reports: [v]"

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
  , plainLine (" Known Through: " ++ snapshot.actual.today)
  , plainLine (statusLine snapshot state pending)
  , ruleLine bounds '-'
  , plainLine " Pending Scheduled:"
  ] ++
  pendingLines pending ++
  [ blankLine
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
  , mutedLine "   [c] Budget uses the current explicit preset; [e] raw Capacity/actions."
  , mutedLine "   [u] Purpose routes audits explicit Expense Loci and edits Actual routing."
  , mutedLine "   [o] Roles assigns one first AccountingRole only to a virgin admitted Locus."
  , ruleLine bounds '='
  ]

private def helpLines (bounds : Bounds) : List Widget :=
  if bounds.width >= 120 then
    [mutedLine "[h/l] day  [k/j] week  [g] known  [Enter] day  [r] record  [a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [o] roles  [m] loci  [v] reports  [q] quit"]
  else
    [ mutedLine "[h/l] day  [k/j] week  [g] known  [Enter] day  [r] record  [q] quit"
    , mutedLine "[a] actual  [p] scheduled  [i] attention  [c] budget  [e] capacity  [u] purpose routes  [o] roles  [m] loci  [v] reports"
    ]

/-- Reserve the bottom rows for HRA-style stable help and truncate only body rows. -/
private def fitWithFooter (bounds : Bounds) (body footer : List Widget) : List Widget :=
  let available := if bounds.height > 0 then bounds.height - 1 else 0
  let bodyCapacity := available - footer.length
  let visibleBody := body.take bodyCapacity
  let padding := bodyCapacity - visibleBody.length
  visibleBody ++ (List.replicate padding blankLine) ++ footer

/--
HRA-shaped Home presentation over LOAM's already-admitted read answers.
This is presentation only: it adds no household authority, cycle policy,
Scheduled completeness claim, or retained pending status.
-/
def homeView (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  let body := homeBody bounds snapshot state
  let footer :=
    (if state.notice.isEmpty then [] else [plainLine state.notice]) ++ helpLines bounds
  .column (fitWithFooter bounds body footer)

/-- Use the HRA-shaped Home while retaining existing production workspace views. -/
def view (bounds : Bounds) (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .home _ => homeView bounds snapshot state
  | _ => Loam.Tui.Main.view snapshot state

end Loam.Tui.HraHome
