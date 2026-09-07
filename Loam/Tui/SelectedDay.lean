import Loam.Tui.Main

namespace Loam.Tui.SelectedDay

open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

inductive Pane where
  | actual
  | scheduled
  deriving Repr, DecidableEq, BEq

structure State where
  focusDate : String
  pane : Pane := .actual
  actualRow : Nat := 0
  scheduledRow : Nat := 0
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
  | focusLeft
  | focusRight
  | recordNew
  | correctActual
  | correctDate
  | completeScheduled
  | cancelScheduled
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | recordNew
  | correctActual
  | correctDate
  | completeScheduled
  | cancelScheduled
  | back
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  command : Command := .stay


def initial (focusDate : String) : State :=
  { focusDate := focusDate }

/-- Selected-day Actual is exactly the existing shared ActualReview day answer. -/
def actualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.focusDate

/-- Selected-day Scheduled evidence preserves the shared open-world answer. -/
def scheduledEvidence (snapshot : Snapshot) (state : State) : ScheduledEvidence :=
  Loam.ScheduledReview.dayEvidence snapshot.scheduled state.focusDate


def scheduledRecords (snapshot : Snapshot) (state : State) : List ScheduledRecord :=
  Loam.ScheduledReview.explicitDueRecords (scheduledEvidence snapshot state)


def selectedActual? (snapshot : Snapshot) (state : State) : Option ReviewRecord :=
  (actualRecords snapshot state)[state.actualRow]?


def selectedScheduled? (snapshot : Snapshot) (state : State) : Option ScheduledRecord :=
  (scheduledRecords snapshot state)[state.scheduledRow]?

private def clampState (snapshot : Snapshot) (state : State) : State :=
  let actualCount := (actualRecords snapshot state).length
  let scheduledCount := (scheduledRecords snapshot state).length
  let actualRow := if actualCount = 0 then 0 else min state.actualRow (actualCount - 1)
  let scheduledRow := if scheduledCount = 0 then 0 else min state.scheduledRow (scheduledCount - 1)
  { state with actualRow := actualRow, scheduledRow := scheduledRow }

/-- Re-clamp only process-local selection after canonical evidence changes. -/
def refreshed (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot { state with notice := "" }

private def movePrevious (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      if state.actualRow = 0 then { state with notice := "No previous Actual row on this day." }
      else { state with actualRow := state.actualRow - 1, notice := "" }
  | .scheduled =>
      if state.scheduledRow = 0 then { state with notice := "No previous Scheduled row on this day." }
      else { state with scheduledRow := state.scheduledRow - 1, notice := "" }

private def moveNext (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      let count := (actualRecords snapshot state).length
      if state.actualRow + 1 < count then
        { state with actualRow := state.actualRow + 1, notice := "" }
      else
        { state with notice := "No next Actual row on this day." }
  | .scheduled =>
      let count := (scheduledRecords snapshot state).length
      if state.scheduledRow + 1 < count then
        { state with scheduledRow := state.scheduledRow + 1, notice := "" }
      else
        { state with notice := "No next Scheduled row on this day." }


def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := movePrevious snapshot state }
  | .next => { state := moveNext snapshot state }
  | .focusLeft => { state := { state with pane := .actual, notice := "" } }
  | .focusRight => { state := { state with pane := .scheduled, notice := "" } }
  | .recordNew => { state, command := .recordNew }
  | .correctActual =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Correction is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for correction." } }
          | some _ => { state, command := .correctActual }
  | .correctDate =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Date correction is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for date correction." } }
          | some _ => { state, command := .correctDate }
  | .completeScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Completion is available from the Scheduled pane." } }
      | .scheduled =>
          match selectedScheduled? snapshot state with
          | none =>
              { state := { state with notice := "No current-open Scheduled occurrence is selected for completion." } }
          | some _ => { state, command := .completeScheduled }
  | .cancelScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Cancellation is available from the Scheduled pane." } }
      | .scheduled =>
          match selectedScheduled? snapshot state with
          | none =>
              { state := { state with notice := "No current-open Scheduled occurrence is selected for cancellation." } }
          | some _ => { state, command := .cancelScheduled }
  | .back => { state, command := .back }
  | .other => { state }

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def fit (width : Nat) (text : String) : String :=
  if text.length <= width then
    text ++ repeatChar (width - text.length) ' '
  else
    String.ofList (text.toList.take width)

private def rule (bounds : Bounds) (char : Char) : Widget :=
  plainLine (repeatChar (if bounds.width > 1 then bounds.width - 1 else bounds.width) char)

private def actualSummary (record : ReviewRecord) : String :=
  Loam.ActualReview.summary record

private def scheduledSummary (record : ScheduledRecord) : String :=
  record.scheduledOn ++ "  " ++ Loam.ScheduledReview.summary record

private def actualWindowStart (state : State) : Nat :=
  if state.actualRow > 6 then state.actualRow - 5 else 0

private def scheduledWindowStart (state : State) : Nat :=
  if state.scheduledRow > 6 then state.scheduledRow - 5 else 0

private def paneRow (snapshot : Snapshot) (state : State)
    (leftWidth rightWidth row : Nat) : Widget :=
  let actualIndex := actualWindowStart state + row
  let scheduledIndex := scheduledWindowStart state + row
  let actualPrefix :=
    if actualIndex = state.actualRow && !(actualRecords snapshot state).isEmpty then
      if state.pane == .actual then " > " else " * "
    else "   "
  let scheduledPrefix :=
    if scheduledIndex = state.scheduledRow && !(scheduledRecords snapshot state).isEmpty then
      if state.pane == .scheduled then " > " else " * "
    else "   "
  let actualText :=
    match (actualRecords snapshot state)[actualIndex]? with
    | some record => actualPrefix ++ actualSummary record
    | none => if row = 0 && (actualRecords snapshot state).isEmpty then " (none recorded)" else ""
  let scheduledText :=
    match (scheduledRecords snapshot state)[scheduledIndex]? with
    | some record => scheduledPrefix ++ scheduledSummary record
    | none =>
        if row = 0 && (scheduledRecords snapshot state).isEmpty then
          match scheduledEvidence snapshot state with
          | .unknown => " (Unknown; no completeness horizon claimed)"
          | .due _ _ => " (none due)"
          | _ => " (Scheduled evidence unavailable)"
        else ""
  .row [span (fit leftWidth actualText), span " | ", span (fit rightWidth scheduledText)]

private def actualDetail (snapshot : Snapshot) (state : State) : List Widget :=
  match selectedActual? snapshot state with
  | none =>
      [ plainLine " Selected Actual:"
      , mutedLine "   (no Actual selected)"
      ]
  | some record =>
      [ plainLine " Selected Actual:"
      , plainLine ("   Identity    : " ++ record.event.id.token)
      , plainLine ("   Description : " ++ if record.description.isEmpty then "(no description)" else Loam.ActualReview.displayText record.description)
      , plainLine "   Effects:"
      ] ++
      (record.event.effects.map fun effect =>
        plainLine ("     " ++ fit 28 effect.locus.token ++ " " ++ toString effect.quantity.quanta ++ " " ++ effect.measure.token))

private def scheduledUnavailableDetail (evidence : ScheduledEvidence) : List Widget :=
  match evidence with
  | .unknown =>
      [ plainLine " Selected Scheduled:"
      , mutedLine "   Unknown: absence of an explicit due occurrence is not NotDue."
      ]
  | .unknownCompletionScheduled =>
      [plainLine " Selected Scheduled:", plainLine "   Unavailable: completion evidence references an unknown Scheduled identity."]
  | .unknownRetirementScheduled =>
      [plainLine " Selected Scheduled:", plainLine "   Unavailable: retirement evidence references an unknown Scheduled identity."]
  | .unknownReplacementScheduled =>
      [plainLine " Selected Scheduled:", plainLine "   Unavailable: replacement evidence references an unknown Scheduled identity."]
  | .invalidReplacementGraph =>
      [plainLine " Selected Scheduled:", plainLine "   Unavailable: Scheduled replacement graph is invalid."]
  | .conflictingTerminalEvidence =>
      [plainLine " Selected Scheduled:", plainLine "   Unavailable: Scheduled terminal evidence conflicts."]
  | .due _ _ =>
      [plainLine " Selected Scheduled:", mutedLine "   (no Scheduled selected)"]

private def scheduledDetail (snapshot : Snapshot) (state : State) : List Widget :=
  match selectedScheduled? snapshot state with
  | none => scheduledUnavailableDetail (scheduledEvidence snapshot state)
  | some record =>
      [ plainLine " Selected Scheduled:"
      , plainLine ("   Identity : " ++ record.id.token)
      , plainLine ("   Due      : " ++ record.scheduledOn)
      , plainLine "   Expected effects:"
      ] ++
      (record.movement.changes.map fun change =>
        plainLine ("     " ++ fit 28 change.coordinate.token ++ " " ++ toString change.quantity.quanta ++ " " ++ record.measure.token))

private def detailLines (snapshot : Snapshot) (state : State) : List Widget :=
  match state.pane with
  | .actual => actualDetail snapshot state
  | .scheduled => scheduledDetail snapshot state

private def footer (bounds : Bounds) (state : State) : List Widget :=
  match state.pane with
  | .actual =>
      if bounds.width >= 96 then
        [mutedLine "[j/k] select  [h/l] Actual/Scheduled  [n] new Actual  [c] correct  [d] date  [q] back"]
      else
        [mutedLine "[j/k] select [h/l] pane [n] new [c] correct [d] date [q] back"]
  | .scheduled =>
      if bounds.width >= 96 then
        [mutedLine "[j/k] select  [h/l] Actual/Scheduled  [c/Enter] complete  [x] cancel  [n] new Actual  [q] back"]
      else
        [mutedLine "[j/k] select [h/l] pane [c/Enter] complete [x] cancel [q] back"]

private def fitWithFooter (bounds : Bounds) (body footerRows : List Widget) : List Widget :=
  let available := if bounds.height > 0 then bounds.height - 1 else 0
  let bodyCapacity := available - footerRows.length
  let visibleBody := body.take bodyCapacity
  let padding := bodyCapacity - visibleBody.length
  visibleBody ++ List.replicate padding blankLine ++ footerRows

/--
One-date operational workspace. It composes the shared Actual and Scheduled read
answers and owns only pane/cursor state. Actual Record/Correction/date actions and
Scheduled completion/cancellation are local interaction intents; publication
authority stays in shared publishers.
-/
def view (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := clampState snapshot rawState
  let writable := if bounds.width > 1 then bounds.width - 1 else bounds.width
  let leftWidth := if writable > 3 then (writable - 3) / 2 else 0
  let rightWidth := if writable > leftWidth + 3 then writable - leftWidth - 3 else 0
  let actualCount := (actualRecords snapshot state).length
  let scheduledCount := (scheduledRecords snapshot state).length
  let leftHeader := fit leftWidth
    (if state.pane == .actual then " Actual [active] (" ++ toString actualCount ++ ")"
     else " Actual (" ++ toString actualCount ++ ")")
  let rightHeader := fit rightWidth
    (if state.pane == .scheduled then " Scheduled [active] (" ++ toString scheduledCount ++ ")"
     else " Scheduled (" ++ toString scheduledCount ++ ")")
  let body :=
    [ rule bounds '='
    , plainLine " Household Day Workspace"
    , plainLine (" Focus: " ++ state.focusDate ++ "  |  Known through: " ++ snapshot.actual.today)
    , rule bounds '='
    , .row [span leftHeader, span " | ", span rightHeader]
    ] ++
    (List.range 8).map (paneRow snapshot state leftWidth rightWidth) ++
    [rule bounds '-'] ++ detailLines snapshot state ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (fitWithFooter bounds body (footer bounds state))

end Loam.Tui.SelectedDay
